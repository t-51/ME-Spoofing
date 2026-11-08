import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'socks5_proxy.dart';

typedef LogCallback = void Function(String message);
typedef StatsCallback = void Function(int bytesUploaded, int bytesDownloaded);

class TcpTunnel {
  final String host;
  final int port;
  final String cdnIp;
  final int cdnPort;
  final String fakeSni;
  final bool enableSplitting;
  final int splitSize;
  final int splitDelayMs;
  final bool enableFakePacket;
  final int fakeTtl;
  final bool enableSniSpoofing;

  final LogCallback onLog;
  final StatsCallback onStats;
  final void Function(int activeChange) onConnectionCountChanged;

  ServerSocket? _serverSocket;
  final Set<Socket> _activeSockets = {};
  bool _isStopping = false;

  TcpTunnel({
    required this.host,
    required this.port,
    required this.cdnIp,
    required this.cdnPort,
    required this.fakeSni,
    required this.enableSplitting,
    required this.splitSize,
    required this.splitDelayMs,
    required this.enableFakePacket,
    required this.fakeTtl,
    required this.enableSniSpoofing,
    required this.onLog,
    required this.onStats,
    required this.onConnectionCountChanged,
  });

  /// Disables Nagle's algorithm so each flush() produces a separate TCP packet.
  /// This is CRITICAL for TCP splitting — without TCP_NODELAY the OS may merge
  /// the two split chunks into one TCP segment, completely defeating DPI bypass.
  ///
  /// Linux constants: IPPROTO_TCP=6, TCP_NODELAY=1, SOL_SOCKET=1, SO_KEEPALIVE=9
  void _applySocketOptions(Socket socket) {
    final enabled = Uint8List(4)..[0] = 1; // little-endian int32 = 1
    try {
      // TCP_NODELAY: level=IPPROTO_TCP(6), option=TCP_NODELAY(1)
      socket.setRawOption(RawSocketOption(6, 1, enabled));
    } catch (_) {}
    try {
      // SO_KEEPALIVE: level=SOL_SOCKET(1), option=SO_KEEPALIVE(9)
      socket.setRawOption(RawSocketOption(1, 9, enabled));
    } catch (_) {}
  }

  void _setSocketTtl(Socket socket, int ttl) {
    try {
      if (Platform.isWindows) {
        socket.setRawOption(RawSocketOption.fromInt(0, 4, ttl));
        socket.setRawOption(RawSocketOption.fromInt(41, 4, ttl));
      } else {
        socket.setRawOption(RawSocketOption.fromInt(0, 2, ttl));
        socket.setRawOption(RawSocketOption.fromInt(41, 16, ttl));
      }
    } catch (_) {}
  }

  Future<void> start() async {
    _isStopping = false;
    try {
      _serverSocket = await ServerSocket.bind(host, port, shared: true);
      onLog("TCP Tunnel listening on $host:$port -> Forwarding to $cdnIp:$cdnPort");
      _serverSocket!.listen(
        _handleConnection,
        onError: (err) {
          if (!_isStopping) onLog("TCP Tunnel server socket error: $err");
        },
      );
    } catch (e) {
      onLog("Failed to start TCP Tunnel: $e");
      rethrow;
    }
  }

  Future<void> stop() async {
    _isStopping = true;
    try {
      await _serverSocket?.close();
      _serverSocket = null;

      final sockets = List<Socket>.from(_activeSockets);
      for (final s in sockets) {
        try {
          s.destroy();
        } catch (_) {}
      }
      _activeSockets.clear();
      onLog("TCP Tunnel stopped");
    } catch (e) {
      onLog("Error stopping TCP Tunnel: $e");
    }
  }

  void _handleConnection(Socket clientSocket) {
    if (_isStopping) {
      clientSocket.destroy();
      return;
    }

    // Apply TCP_NODELAY on the incoming client socket too
    _applySocketOptions(clientSocket);

    _activeSockets.add(clientSocket);
    onConnectionCountChanged(1);

    Socket? remoteSocket;
    StreamSubscription<Uint8List>? clientSubscription;
    StreamSubscription<Uint8List>? remoteSubscription;
    bool isConnected = false;
    bool isConnecting = false;
    bool firstPacketSent = false;
    final List<int> incomingBuffer = [];

    String clientAddress = "${clientSocket.remoteAddress.address}:${clientSocket.remotePort}";

    void closeBoth() {
      clientSubscription?.cancel();
      remoteSubscription?.cancel();
      try {
        clientSocket.destroy();
      } catch (_) {}
      try {
        remoteSocket?.destroy();
      } catch (_) {}
      if (_activeSockets.remove(clientSocket)) {
        onConnectionCountChanged(-1);
      }
    }

    void sendClientDataToRemote(Uint8List data) async {
      if (remoteSocket == null) return;

      if (!firstPacketSent && _isTlsClientHello(data)) {
        firstPacketSent = true;

        // 1. Send fake ClientHello with low TTL if enabled
        if (enableFakePacket && fakeSni.isNotEmpty) {
          try {
            final fakeData = spoofClientHello(data, fakeSni);
            onLog("DPI Bypass: Injecting fake ClientHello with TTL = $fakeTtl (SNI: '$fakeSni')");
            _setSocketTtl(remoteSocket!, fakeTtl);
            remoteSocket!.add(fakeData);
            await remoteSocket!.flush();
            onStats(fakeData.length, 0);

            await Future.delayed(const Duration(milliseconds: 15));
            _setSocketTtl(remoteSocket!, 64);
          } catch (e) {
            onLog("DPI Bypass: Failed to send fake packet: $e");
          }
        }

        // 2. Prepare the real payload
        Uint8List realPayload = data;
        if (enableSniSpoofing && fakeSni.isNotEmpty) {
          try {
            realPayload = spoofClientHello(data, fakeSni);
            onLog("TCP Tunnel: Spoofed SNI to '$fakeSni' for connection");
          } catch (e) {
            onLog("TCP Tunnel: Failed to spoof SNI: $e. Using original.");
          }
        }

        // 3. Send with TCP Splitting - TCP_NODELAY ensures each flush() = separate packet
        if (enableSplitting) {
          onLog("TCP Tunnel: Applying TCP Splitting (TCP_NODELAY active)...");
          int actualSplitSize = splitSize;
          if (actualSplitSize >= realPayload.length) {
            actualSplitSize = realPayload.length ~/ 2;
            if (actualSplitSize < 1) actualSplitSize = 1;
          }

          final part1 = realPayload.sublist(0, actualSplitSize);
          final part2 = realPayload.sublist(actualSplitSize);

          try {
            // With TCP_NODELAY set, this flush() forces an immediate TCP segment
            remoteSocket!.add(part1);
            await remoteSocket!.flush();
            onStats(part1.length, 0);

            await Future.delayed(Duration(milliseconds: splitDelayMs));

            remoteSocket!.add(part2);
            await remoteSocket!.flush();
            onStats(part2.length, 0);
          } catch (e) {
            onLog("Failed to send split packets: $e");
            closeBoth();
          }
        } else {
          try {
            remoteSocket!.add(realPayload);
            await remoteSocket!.flush();
            onStats(realPayload.length, 0);
          } catch (_) {
            closeBoth();
          }
        }
      } else {
        try {
          remoteSocket!.add(data);
          onStats(data.length, 0);
        } catch (_) {
          closeBoth();
        }
      }
    }

    clientSubscription = clientSocket.listen(
      (data) async {
        if (isConnected) {
          sendClientDataToRemote(data);
          return;
        }

        incomingBuffer.addAll(data);
        if (isConnecting) return;
        isConnecting = true;
        clientSubscription?.pause();

        final initialData = Uint8List.fromList(incomingBuffer);
        String? parsedSni = extractSni(initialData);
        if (parsedSni != null && parsedSni.isNotEmpty) {
          onLog("TCP Tunnel: Extracted destination SNI from ClientHello: '$parsedSni'");
        }

        final targetHost = cdnIp.isNotEmpty ? cdnIp : (parsedSni ?? "");
        final targetPort = cdnPort > 0 ? cdnPort : 443;

        if (targetHost.isEmpty) {
          onLog("[$clientAddress] TCP Tunnel: Could not determine destination host.");
          closeBoth();
          return;
        }

        try {
          remoteSocket = await Socket.connect(
            targetHost,
            targetPort,
            timeout: const Duration(seconds: 10),
          );

          // *** CRITICAL: Apply TCP_NODELAY on the remote socket ***
          // This ensures each flush() produces a separate TCP segment,
          // which is essential for DPI bypass via packet splitting.
          _applySocketOptions(remoteSocket!);

          isConnected = true;
          isConnecting = false;

          // Log successful connection - this tells the user the CDN IP is working
          onLog("✅ TCP Tunnel: Connected to $targetHost:$targetPort (SNI in packet: ${parsedSni ?? 'unknown'})");

          clientSubscription?.resume();


          remoteSubscription = remoteSocket!.listen(
            (remoteData) {
              try {
                clientSocket.add(remoteData);
                onStats(0, remoteData.length);
              } catch (_) {
                closeBoth();
              }
            },
            onDone: () => closeBoth(),
            onError: (err) => closeBoth(),
          );

          if (incomingBuffer.isNotEmpty) {
            incomingBuffer.clear();
            sendClientDataToRemote(initialData);
          }
        } catch (e) {
          isConnecting = false;
          onLog("[$clientAddress] TCP Tunnel failed to connect to $targetHost:$targetPort: $e");
          closeBoth();
        }
      },
      onDone: () => closeBoth(),
      onError: (err) => closeBoth(),
    );
  }

  bool _isTlsClientHello(Uint8List data) {
    return data.length > 5 &&
        data[0] == 0x16 &&
        data[1] == 0x03 &&
        data[2] <= 0x03 &&
        data[5] == 0x01;
  }
}
