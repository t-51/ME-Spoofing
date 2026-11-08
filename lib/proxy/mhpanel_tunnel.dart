import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

typedef LogCallback = void Function(String message);
typedef StatsCallback = void Function(int bytesUploaded, int bytesDownloaded);

/// High-performance Native Dart implementation of MHPanel SNI-Spoofing tunnel.
/// Features Just-In-Time connection to prevent socket leaks from port probes,
/// direct IPv4 routing, and clean socket lifecycle management.
/// Transport mode for MHPanel tunnel
enum MhpanelTransportMode {
  directSni,
  cloudflareClean,
}

class MhpanelTunnel {
  final MhpanelTransportMode transportMode;
  final String serverHost;
  final List<String> serverHosts;
  final int serverDaemonPort;
  final List<int> serverPorts;
  final int fallbackLocalPort;
  final String fakeSni;
  final int fragmentDelayMs;
  final bool enableFakePacket;

  // Mode 2: Cloudflare Clean IP settings
  final String cfCleanIp;
  final int cfCleanPort;
  final String cfServerSni;

  final LogCallback onLog;
  final StatsCallback onStats;
  final void Function(int activeChange) onConnectionCountChanged;

  final List<ServerSocket> _serverSockets = [];
  final Set<int> _boundLocalPorts = {};
  final Set<Socket> _activeSockets = {};
  final Queue<Completer<void>> _waitingConnects = Queue<Completer<void>>();
  bool _isStopping = false;

  // Pre-resolved IP address to prevent Android netd DNS delays
  final List<InternetAddress> _serverIpAddresses = [];
  int _preferredServerIndex = 0;

  static const int _maxConcurrentConnects = 24;
  static const int _maxQueuedConnects = 256;
  static const int _maxActiveConnections = 320;
  int _activeConnectingCount = 0;
  int _rejectedConnectionCount = 0;

  MhpanelTunnel({
    this.transportMode = MhpanelTransportMode.directSni,
    required this.serverHost,
    List<String>? serverHosts,
    required this.serverDaemonPort,
    required this.serverPorts,
    this.fallbackLocalPort = 40443,
    required this.fakeSni,
    this.fragmentDelayMs = 3,
    this.enableFakePacket = true,
    this.cfCleanIp = "188.114.98.0",
    this.cfCleanPort = 443,
    this.cfServerSni = "ws.kigaping.com",
    required this.onLog,
    required this.onStats,
    required this.onConnectionCountChanged,
  }) : serverHosts = serverHosts ?? serverHost.split(',');

  void _applySocketOptions(Socket socket) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    final enabled = Uint8List(4)..[0] = 1;
    try {
      // TCP_NODELAY: IPPROTO_TCP(6), TCP_NODELAY(1)
      socket.setRawOption(RawSocketOption(6, 1, enabled));
    } catch (_) {}
    try {
      // SO_KEEPALIVE: SOL_SOCKET(1), SO_KEEPALIVE(9)
      socket.setRawOption(RawSocketOption(1, 9, enabled));
    } catch (_) {}
  }

  static Uint8List buildSignalingHeader(int targetPort, int fakePayloadLength) {
    return Uint8List.fromList([
      0x53, 0x4E, 0x49, 0x50, // Magic "SNIP"
      (targetPort >> 8) & 0xFF, targetPort & 0xFF,
      (fakePayloadLength >> 8) & 0xFF, fakePayloadLength & 0xFF,
    ]);
  }

  static Uint8List buildFakeClientHello(String fakeSni) {
    final sniBytes = utf8.encode(fakeSni);
    final serverName = [
      0x00,
      (sniBytes.length >> 8) & 0xFF,
      sniBytes.length & 0xFF,
      ...sniBytes,
    ];
    final sniExtLen = serverName.length + 2;
    final sniExt = [
      0x00,
      0x00,
      (sniExtLen >> 8) & 0xFF,
      sniExtLen & 0xFF,
      (serverName.length >> 8) & 0xFF,
      serverName.length & 0xFF,
      ...serverName,
    ];

    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final sessionId = List<int>.generate(32, (_) => random.nextInt(256));

    final handshakeBody = [
      0x03,
      0x03,
      ...randomBytes,
      sessionId.length & 0xFF,
      ...sessionId,
      0x00,
      0x02,
      0x13,
      0x01,
      0x01,
      0x00,
      (sniExt.length >> 8) & 0xFF,
      sniExt.length & 0xFF,
      ...sniExt,
    ];

    final hsLen = handshakeBody.length;
    final handshake = [
      0x01,
      (hsLen >> 16) & 0xFF,
      (hsLen >> 8) & 0xFF,
      hsLen & 0xFF,
      ...handshakeBody,
    ];

    final recLen = handshake.length;
    return Uint8List.fromList([
      0x16,
      0x03,
      0x01,
      (recLen >> 8) & 0xFF,
      recLen & 0xFF,
      ...handshake,
    ]);
  }

  static int findSniOffset(Uint8List data) {
    if (data.length < 5 || data[0] != 0x16) return -1;
    int pos = 43;
    if (pos >= data.length) return -1;
    final sessIdLen = data[pos];
    pos += 1 + sessIdLen;
    if (pos + 2 > data.length) return -1;
    final cipherLen = (data[pos] << 8) | data[pos + 1];
    pos += 2 + cipherLen;
    if (pos + 1 > data.length) return -1;
    final compLen = data[pos];
    pos += 1 + compLen;
    if (pos + 2 > data.length) return -1;
    final extTotalLen = (data[pos] << 8) | data[pos + 1];
    pos += 2;
    final extEnd = pos + extTotalLen;

    while (pos + 4 <= extEnd && pos + 4 <= data.length) {
      final extType = (data[pos] << 8) | data[pos + 1];
      final extLen = (data[pos + 2] << 8) | data[pos + 3];
      pos += 4;
      if (extType == 0) {
        if (pos + 5 <= data.length && data[pos + 2] == 0) {
          return pos + 5;
        }
      }
      pos += extLen;
    }
    return -1;
  }

  static bool isTlsClientHello(Uint8List data) {
    return data.length > 5 &&
        data[0] == 0x16 &&
        data[1] == 0x03 &&
        data[2] <= 0x03 &&
        data[5] == 0x01;
  }

  /// Clean, resilient connection to MHPanel server without socket duplication.
  /// Uses shorter timeouts to fail fast under DPI and free up concurrency slots.
  Future<Socket> _connectToAddress(InternetAddress address, int port) async {
    try {
      return await Socket.connect(
        address,
        port,
        timeout: const Duration(milliseconds: 6000),
      );
    } catch (_) {
      // Retry in case initial SYN packet was dropped by cellular DPI
      return await Socket.connect(
        address,
        port,
        timeout: const Duration(milliseconds: 7000),
      );
    }
  }

  Future<Socket> _connectToServer() async {
    final targetUpstreamPort =
        transportMode == MhpanelTransportMode.cloudflareClean
            ? cfCleanPort
            : serverDaemonPort;
    final errors = <String>[];
    for (var offset = 0; offset < _serverIpAddresses.length; offset++) {
      final index =
          (_preferredServerIndex + offset) % _serverIpAddresses.length;
      final address = _serverIpAddresses[index];
      try {
        final socket = await _connectToAddress(address, targetUpstreamPort);
        _preferredServerIndex = index;
        if (offset > 0) {
          onLog("🔁 Connected through backup server ${address.address}.");
        }
        return socket;
      } catch (error) {
        errors.add("${address.address}: $error");
      }
    }
    throw SocketException(
      'Could not connect to any configured server: ${errors.join('; ')}',
    );
  }

  Future<bool> _acquireConnectSlot() async {
    if (_isStopping) return false;
    if (_activeConnectingCount < _maxConcurrentConnects) {
      _activeConnectingCount++;
      return true;
    }
    if (_waitingConnects.length >= _maxQueuedConnects) return false;

    final waiter = Completer<void>();
    _waitingConnects.addLast(waiter);
    await waiter.future;
    return true;
  }

  void _releaseConnectSlot() {
    while (_waitingConnects.isNotEmpty) {
      final waiter = _waitingConnects.removeFirst();
      if (!waiter.isCompleted) {
        waiter.complete();
        return;
      }
    }
    if (_activeConnectingCount > 0) _activeConnectingCount--;
  }

  Future<void> start() async {
    _isStopping = false;
    _serverSockets.clear();
    _boundLocalPorts.clear();

    _serverIpAddresses.clear();
    final hostsToResolve = transportMode == MhpanelTransportMode.cloudflareClean
        ? [cfCleanIp, "188.114.98.0", "104.18.119.142", "162.159.192.1"]
        : serverHosts;
    for (final configuredHost in hostsToResolve) {
      final host = configuredHost.trim();
      if (host.isEmpty) continue;
      final parsed = InternetAddress.tryParse(host);
      if (parsed != null) {
        if (!_serverIpAddresses.any((a) => a.address == parsed.address)) {
          _serverIpAddresses.add(parsed);
        }
        continue;
      }
      try {
        final addresses = await InternetAddress.lookup(host);
        for (final address in addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !_serverIpAddresses.any((a) => a.address == address.address)) {
            _serverIpAddresses.add(address);
          }
        }
      } catch (e) {
        onLog("⚠️ Could not resolve server address $host: $e");
      }
    }
    if (_serverIpAddresses.isEmpty) {
      throw const SocketException(
        'No configured server address could be resolved.',
      );
    }
    _preferredServerIndex = 0;
    if (transportMode == MhpanelTransportMode.cloudflareClean) {
      onLog(
        "⚡ Mode 2: Cloudflare Clean IP Upstream: ${_serverIpAddresses.map((a) => a.address).join(', ')}:$cfCleanPort",
      );
    } else {
      onLog(
        "🌐 Mode 1: Resolved upstream servers: ${_serverIpAddresses.map((address) => address.address).join(', ')}:$serverDaemonPort",
      );
    }

    final distinctPorts = <int>{};
    for (final p in serverPorts) {
      if (p > 0 && p <= 65535) distinctPorts.add(p);
    }
    if (distinctPorts.isEmpty) {
      distinctPorts.add(fallbackLocalPort);
    }

    for (final port in distinctPorts) {
      try {
        final serverSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
        _serverSockets.add(serverSocket);
        _boundLocalPorts.add(port);
        onLog("🚀 Listening on 0.0.0.0:$port (and 127.0.0.1:$port) ➔ Server Upstream: $port");

        serverSocket.listen(
          (clientSocket) => _handleConnection(clientSocket, port),
          onError: (err) {
            if (!_isStopping) onLog("Port $port error: $err");
          },
        );
      } catch (e) {
        onLog("⚠️ Could not bind 0.0.0.0:$port: $e");
      }
    }

    final primaryPort = distinctPorts.first;
    if (fallbackLocalPort > 0 && !distinctPorts.contains(fallbackLocalPort)) {
      try {
        final fallbackSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          fallbackLocalPort,
          shared: true,
        );
        _serverSockets.add(fallbackSocket);
        _boundLocalPorts.add(fallbackLocalPort);
        onLog(
          "🚀 Listening on 0.0.0.0:$fallbackLocalPort (and 127.0.0.1:$fallbackLocalPort) ➔ Server Upstream: $primaryPort",
        );

        fallbackSocket.listen(
          (clientSocket) => _handleConnection(clientSocket, primaryPort),
          onError: (err) {
            if (!_isStopping) onLog("Port $fallbackLocalPort error: $err");
          },
        );
      } catch (e) {
        onLog("⚠️ Could not bind 0.0.0.0:$fallbackLocalPort: $e");
      }
    }

    if (_serverSockets.isEmpty) {
      throw Exception("Could not bind any local listening ports.");
    }
  }

  Future<void> addLocalPort(int port) async {
    if (_isStopping || _boundLocalPorts.contains(port)) return;
    if (port <= 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'Must be between 1 and 65535.');
    }

    final serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    if (_isStopping) {
      await serverSocket.close();
      return;
    }
    _serverSockets.add(serverSocket);
    _boundLocalPorts.add(port);
    serverSocket.listen(
      (clientSocket) => _handleConnection(clientSocket, port),
      onError: (error) {
        if (!_isStopping) onLog("Port $port error: $error");
      },
    );
    onLog("🚀 Added local listener 127.0.0.1:$port while proxy is running.");
  }

  Future<void> stop() async {
    _isStopping = true;
    for (final ss in _serverSockets) {
      try {
        await ss.close();
      } catch (_) {}
    }
    _serverSockets.clear();
    _boundLocalPorts.clear();

    final sockets = List<Socket>.from(_activeSockets);
    for (final s in sockets) {
      try {
        s.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();
    onLog("🛑 MHPanel Proxy stopped.");
  }

  void _handleConnection(Socket clientSocket, int targetPort) {
    if (_isStopping) {
      clientSocket.destroy();
      return;
    }
    if (_activeSockets.length >= _maxActiveConnections) {
      _rejectedConnectionCount++;
      if (_rejectedConnectionCount == 1 || _rejectedConnectionCount % 25 == 0) {
        onLog(
          "⚠️ Connection limit reached; rejected $_rejectedConnectionCount client connections.",
        );
      }
      clientSocket.destroy();
      return;
    }

    _applySocketOptions(clientSocket);
    _activeSockets.add(clientSocket);
    onConnectionCountChanged(1);

    Socket? remoteSocket;
    StreamSubscription<Uint8List>? clientSub;
    StreamSubscription<Uint8List>? remoteSub;
    bool isConnected = false;
    bool isConnecting = false;
    bool isClosed = false;
    bool ownsConnectSlot = false;
    bool initialHandshakeDone = false;
    final List<int> incomingBuffer = [];

    final clientDesc =
        "${clientSocket.remoteAddress.address}:${clientSocket.remotePort}";

    void closeAll() {
      if (isClosed) return;
      isClosed = true;

      clientSub?.cancel();
      clientSub = null;
      remoteSub?.cancel();
      remoteSub = null;

      try {
        clientSocket.destroy();
      } catch (_) {}
      try {
        remoteSocket?.destroy();
      } catch (_) {}
      remoteSocket = null;

      if (_activeSockets.remove(clientSocket)) {
        onConnectionCountChanged(-1);
      }
    }

    // Sends the local client's real payload with SNI fragmentation
    Future<void> forwardRealPayload(Uint8List payload) async {
      if (remoteSocket == null || isClosed) return;

      if (!initialHandshakeDone && isTlsClientHello(payload)) {
        initialHandshakeDone = true;

        if (fragmentDelayMs > 0) {
          final sniOffset = findSniOffset(payload);
          if (sniOffset > 0 && sniOffset + 2 < payload.length) {
            final splitPoint = sniOffset + 2;
            final chunk1 = payload.sublist(0, splitPoint);
            final chunk2 = payload.sublist(splitPoint);

            try {
              remoteSocket!.add(chunk1);
              await remoteSocket!.flush();
              onStats(chunk1.length, 0);

              await Future.delayed(Duration(milliseconds: fragmentDelayMs));

              remoteSocket!.add(chunk2);
              await remoteSocket!.flush();
              onStats(chunk2.length, 0);

              onLog(
                "⚡ Fragmented ClientHello (Split @ $splitPoint, Upstream: $targetPort)",
              );
              return;
            } catch (e) {
              closeAll();
              return;
            }
          }
        }
      }

      try {
        remoteSocket!.add(payload);
        await remoteSocket!.flush();
        onStats(payload.length, 0);
      } catch (_) {
        closeAll();
      }
    }

    clientSub = clientSocket.listen(
      (data) async {
        if (isClosed) return;

        if (isConnected) {
          clientSub?.pause();
          unawaited(
            forwardRealPayload(data).whenComplete(() {
              if (!isClosed) clientSub?.resume();
            }),
          );
          return;
        }

        // Just-in-Time: only connect to upstream when client actually sends data!
        // This completely prevents socket leaks from empty latency/ping probes.
        incomingBuffer.addAll(data);
        if (isConnecting) return;

        isConnecting = true;
        clientSub?.pause();

        final hasConnectSlot = await _acquireConnectSlot();
        if (!hasConnectSlot) {
          isConnecting = false;
          closeAll();
          return;
        }
        ownsConnectSlot = true;

        try {
          if (_isStopping || isClosed) {
            _releaseConnectSlot();
            ownsConnectSlot = false;
            closeAll();
            return;
          }
          remoteSocket = await _connectToServer();
          _releaseConnectSlot();
          ownsConnectSlot = false;
          if (isClosed) {
            remoteSocket?.destroy();
            return;
          }

          _applySocketOptions(remoteSocket!);

          if (transportMode == MhpanelTransportMode.directSni) {
            // Build Fake ClientHello (Decoy)
            Uint8List fakeHello = Uint8List(0);
            if (enableFakePacket && fakeSni.isNotEmpty) {
              fakeHello = buildFakeClientHello(fakeSni);
            }

            // Build 8-byte Signaling Header
            final header = buildSignalingHeader(targetPort, fakeHello.length);

            // Atomic write: Header + Decoy ClientHello in a single TCP packet
            final initialPacket = Uint8List(header.length + fakeHello.length);
            initialPacket.setRange(0, header.length, header);
            if (fakeHello.isNotEmpty) {
              initialPacket.setRange(
                header.length,
                initialPacket.length,
                fakeHello,
              );
            }

            remoteSocket!.add(initialPacket);
            if (fakeHello.isNotEmpty) {
              onStats(fakeHello.length, 0);
              onLog(
                "🛡️ Injected Decoy (${fakeHello.length}B -> $fakeSni) -> Upstream: $targetPort",
              );
            }
            await remoteSocket!.flush();
          } else {
            onLog(
              "⚡ Mode 2: Clean IP connected -> Upstream: $targetPort (Cloudflare Anycast)",
            );
          }

          isConnected = true;
          isConnecting = false;

          remoteSub = remoteSocket!.listen(
            (remoteData) {
              remoteSub?.pause();
              unawaited(() async {
                try {
                  clientSocket.add(remoteData);
                  await clientSocket.flush();
                  onStats(0, remoteData.length);
                } catch (_) {
                  closeAll();
                } finally {
                  if (!isClosed) remoteSub?.resume();
                }
              }());
            },
            onDone: () => closeAll(),
            onError: (_) => closeAll(),
          );

          // Forward initial ClientHello
          if (incomingBuffer.isNotEmpty) {
            final initialData = Uint8List.fromList(incomingBuffer);
            incomingBuffer.clear();
            await forwardRealPayload(initialData);
          }
          if (!isClosed) clientSub?.resume();
        } catch (e) {
          isConnecting = false;
          if (ownsConnectSlot) {
            _releaseConnectSlot();
            ownsConnectSlot = false;
          }
          if (!isClosed) {
            onLog(
              "[$clientDesc] Connection to MHPanel on port $serverDaemonPort failed: $e",
            );
            closeAll();
          }
        }
      },
      onDone: () => closeAll(),
      onError: (_) => closeAll(),
    );
  }
}
