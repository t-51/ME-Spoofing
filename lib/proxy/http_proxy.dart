import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'socks5_proxy.dart';
import 'sha224.dart';
import 'websocket_socket.dart';

typedef LogCallback = void Function(String message);
typedef StatsCallback = void Function(int bytesUploaded, int bytesDownloaded);

class HttpProxy {
  final String host;
  final int port;
  final String
  proxyMode; // "sni_only", "sni_warp", "sni_psiphon", "sni_warp_in_warp", "gaming_mode", "trojan"
  final bool enableSplitting;
  final int splitSize;
  final int splitDelayMs;
  final String fakeSni;
  final String cdnIp;
  final int cdnPort;
  final bool enableFakePacket;
  final int fakeTtl;
  final bool enableSniSpoofing;

  // Trojan configurations
  final String trojanPassword;
  final String trojanServerSni;
  final String trojanTransport; // "tcp", "ws", "grpc"
  final String trojanPath;
  final String trojanHost;

  final LogCallback onLog;
  final StatsCallback onStats;
  final void Function(int activeChange) onConnectionCountChanged;

  ServerSocket? _serverSocket;
  final Set<Socket> _activeSockets = {};
  bool _isStopping = false;

  HttpProxy({
    required this.host,
    required this.port,
    required this.proxyMode,
    required this.enableSplitting,
    required this.splitSize,
    required this.splitDelayMs,
    required this.fakeSni,
    required this.cdnIp,
    required this.cdnPort,
    required this.enableFakePacket,
    required this.fakeTtl,
    required this.enableSniSpoofing,
    required this.trojanPassword,
    required this.trojanServerSni,
    required this.trojanTransport,
    required this.trojanPath,
    required this.trojanHost,
    required this.onLog,
    required this.onStats,
    required this.onConnectionCountChanged,
  });

  /// Disables Nagle's algorithm so each flush() produces a separate TCP packet.
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
        socket.setRawOption(
          RawSocketOption.fromInt(0, 4, ttl),
        ); // IPPROTO_IP = 0, IP_TTL = 4
        socket.setRawOption(
          RawSocketOption.fromInt(41, 4, ttl),
        ); // IPPROTO_IPV6 = 41, IPV6_UNICAST_HOPS = 4
      } else {
        socket.setRawOption(
          RawSocketOption.fromInt(0, 2, ttl),
        ); // IPPROTO_IP = 0, IP_TTL = 2
        socket.setRawOption(
          RawSocketOption.fromInt(41, 16, ttl),
        ); // IPPROTO_IPV6 = 41, IPV6_UNICAST_HOPS = 16
      }
    } catch (_) {}
  }

  Future<void> start() async {
    _isStopping = false;
    try {
      _serverSocket = await ServerSocket.bind(host, port, shared: true);
      onLog("HTTP Proxy server listening on $host:$port");
      _serverSocket!.listen(
        _handleConnection,
        onError: (err) {
          if (!_isStopping) onLog("HTTP Server socket error: $err");
        },
      );
    } catch (e) {
      onLog("Failed to start HTTP proxy server: $e");
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
      onLog("HTTP Proxy server stopped");
    } catch (e) {
      onLog("Error stopping HTTP proxy server: $e");
    }
  }

  void _handleConnection(Socket clientSocket) {
    if (_isStopping) {
      clientSocket.destroy();
      return;
    }

    _activeSockets.add(clientSocket);
    onConnectionCountChanged(1);

    final List<int> incomingBuffer = [];
    StreamSubscription<Uint8List>? clientSubscription;
    StreamSubscription<Uint8List>? remoteSubscription;
    Socket? remoteSocket;
    bool isConnected = false;
    bool isConnecting = false;
    bool isConnectMethod = false;

    String clientAddress =
        "${clientSocket.remoteAddress.address}:${clientSocket.remotePort}";
    String targetHost = "";
    int targetPort = 80;
    bool firstPacketSent = false;

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

      bool isSniMode =
          proxyMode == "sni_only" ||
          proxyMode == "sni_warp" ||
          proxyMode == "sni_psiphon" ||
          proxyMode == "sni_warp_in_warp";

      if (isSniMode && !firstPacketSent && _isTlsClientHello(data)) {
        firstPacketSent = true;

        // 1. Send fake ClientHello with low TTL if enabled
        if (enableFakePacket && fakeSni.isNotEmpty) {
          try {
            final fakeData = spoofClientHello(data, fakeSni);
            onLog(
              "DPI Bypass: Injecting fake ClientHello with TTL = $fakeTtl (SNI: '$fakeSni')",
            );
            _setSocketTtl(remoteSocket!, fakeTtl);
            remoteSocket!.add(fakeData);
            await remoteSocket!.flush();
            onStats(fakeData.length, 0);

            // Tiny delay to ensure transmission
            await Future.delayed(const Duration(milliseconds: 15));
            _setSocketTtl(remoteSocket!, 64); // Restore default TTL
          } catch (e) {
            onLog("DPI Bypass: Failed to send fake packet: $e");
          }
        }

        // 2. Prepare the real payload
        Uint8List spoofedData = data;
        if (enableSniSpoofing && fakeSni.isNotEmpty) {
          try {
            spoofedData = spoofClientHello(data, fakeSni);
            onLog(
              "DPI Bypass: Spoofed SNI to '$fakeSni' for $targetHost:$targetPort",
            );
          } catch (e) {
            onLog(
              "DPI Bypass: Failed to spoof SNI: $e. Using original ClientHello.",
            );
          }
        }

        // 3. Send the real payload (with optional TCP Splitting)
        if (enableSplitting) {
          onLog("DPI Bypass: Applying TCP Splitting...");
          int actualSplitSize = splitSize;
          if (actualSplitSize >= spoofedData.length) {
            actualSplitSize = spoofedData.length ~/ 2;
            if (actualSplitSize < 1) actualSplitSize = 1;
          }

          final part1 = spoofedData.sublist(0, actualSplitSize);
          final part2 = spoofedData.sublist(actualSplitSize);

          try {
            remoteSocket!.add(part1);
            await remoteSocket!.flush();
            onStats(part1.length, 0);

            await Future.delayed(Duration(milliseconds: splitDelayMs));

            remoteSocket!.add(part2);
            await remoteSocket!.flush();
            onStats(part2.length, 0);
          } catch (e) {
            onLog(
              "Failed to send split packets to $targetHost:$targetPort: $e",
            );
            closeBoth();
          }
        } else {
          try {
            remoteSocket!.add(spoofedData);
            await remoteSocket!.flush();
            onStats(spoofedData.length, 0);
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

        final headerEnd = _findHttpHeaderEnd(incomingBuffer);
        if (headerEnd == -1) {
          if (incomingBuffer.length > 8192) {
            onLog("[$clientAddress] HTTP header too large, closing.");
            closeBoth();
          }
          return;
        }

        isConnecting = true;
        clientSubscription?.pause();
        final requestStr = String.fromCharCodes(
          incomingBuffer.sublist(0, headerEnd),
        );
        final lines = requestStr.split('\r\n');
        if (lines.isEmpty || lines[0].isEmpty) {
          closeBoth();
          return;
        }

        final parts = lines[0].split(' ');
        if (parts.length < 3) {
          closeBoth();
          return;
        }

        final method = parts[0].toUpperCase();
        final uri = parts[1];

        isConnectMethod = method == "CONNECT";

        if (isConnectMethod) {
          final uriParts = uri.split(':');
          targetHost = uriParts[0];
          targetPort = uriParts.length > 1
              ? (int.tryParse(uriParts[1]) ?? 443)
              : 443;
        } else {
          var hostHeader = "";
          for (final line in lines) {
            if (line.toLowerCase().startsWith("host: ")) {
              hostHeader = line.substring(6).trim();
              break;
            }
          }

          if (hostHeader.isNotEmpty) {
            final hostParts = hostHeader.split(':');
            targetHost = hostParts[0];
            targetPort = hostParts.length > 1
                ? (int.tryParse(hostParts[1]) ?? 80)
                : 80;
          } else {
            try {
              final parsedUri = Uri.parse(uri);
              targetHost = parsedUri.host;
              targetPort = parsedUri.port;
            } catch (_) {
              closeBoth();
              return;
            }
          }
        }

        if (targetHost.isEmpty) {
          closeBoth();
          return;
        }

        clientSubscription?.pause();

        try {
          remoteSocket = await _connectToDestination(targetHost, targetPort);
          isConnected = true;
          isConnecting = false;

          if (isConnectMethod) {
            clientSocket.add(
              Uint8List.fromList(
                "HTTP/1.1 200 Connection Established\r\n\r\n".codeUnits,
              ),
            );
            await clientSocket.flush();
            incomingBuffer.removeRange(0, headerEnd);
          } else {
            final remainingData = Uint8List.fromList(incomingBuffer);
            incomingBuffer.clear();
            sendClientDataToRemote(remainingData);
          }

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
        } catch (e) {
          isConnecting = false;
          onLog(
            "[$clientAddress] HTTP Proxy failed to connect to $targetHost:$targetPort: $e",
          );
          if (isConnectMethod) {
            try {
              clientSocket.add(
                Uint8List.fromList(
                  "HTTP/1.1 502 Bad Gateway\r\n\r\n".codeUnits,
                ),
              );
              await clientSocket.flush();
            } catch (_) {}
          }
          closeBoth();
        }
      },
      onDone: () => closeBoth(),
      onError: (err) => closeBoth(),
    );
  }

  int _findHttpHeaderEnd(List<int> buffer) {
    for (int i = 0; i < buffer.length - 3; i++) {
      if (buffer[i] == 0x0D &&
          buffer[i + 1] == 0x0A &&
          buffer[i + 2] == 0x0D &&
          buffer[i + 3] == 0x0A) {
        return i + 4;
      }
    }
    for (int i = 0; i < buffer.length - 1; i++) {
      if (buffer[i] == 0x0A && buffer[i + 1] == 0x0A) {
        return i + 2;
      }
    }
    return -1;
  }

  Future<Socket> _connectToDestination(
    String targetHost,
    int targetPort,
  ) async {
    bool isSniMode =
        proxyMode == "sni_only" ||
        proxyMode == "sni_warp" ||
        proxyMode == "sni_psiphon" ||
        proxyMode == "sni_warp_in_warp";

    if (proxyMode == "gaming_mode") {
      final s = await Socket.connect(
        targetHost,
        targetPort,
        timeout: const Duration(seconds: 10),
      );
      _applySocketOptions(s);
      return s;
    } else if (isSniMode) {
      final remoteIp = cdnIp.isNotEmpty ? cdnIp : targetHost;
      final remotePort = cdnPort > 0 ? cdnPort : targetPort;
      final s = await Socket.connect(
        remoteIp,
        remotePort,
        timeout: const Duration(seconds: 10),
      );
      _applySocketOptions(s);
      return s;
    } else if (proxyMode == "trojan") {
      final remoteIp = cdnIp.isNotEmpty ? cdnIp : trojanServerSni;
      final remotePort = cdnPort > 0 ? cdnPort : 443;

      final tcpSocket = await Socket.connect(
        remoteIp,
        remotePort,
        timeout: const Duration(seconds: 10),
      );
      _applySocketOptions(tcpSocket);
      final secureSocket = await SecureSocket.secure(
        tcpSocket,
        host: trojanServerSni,
        context: SecurityContext.defaultContext,
        onBadCertificate: (cert) => true,
      );

      Socket socket;
      if (trojanTransport == "ws") {
        final pathStr = trojanPath.startsWith("/")
            ? trojanPath
            : "/$trojanPath";
        final hostHeader = trojanHost.isNotEmpty ? trojanHost : trojanServerSni;
        final handshake =
            "GET $pathStr HTTP/1.1\r\n"
            "Host: $hostHeader\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n";
        secureSocket.write(handshake);
        await secureSocket.flush();

        final List<int> responseBuffer = [];
        final completer = Completer<List<int>>();
        late StreamSubscription sub;
        sub = secureSocket.listen(
          (chunk) {
            responseBuffer.addAll(chunk);
            final idx = _findHttpHeaderEnd(responseBuffer);
            if (idx != -1) {
              sub.cancel();
              final trailing = responseBuffer.sublist(idx);
              completer.complete(trailing);
            }
          },
          onError: (e) => completer.completeError(e),
          onDone: () =>
              completer.completeError("Socket closed during WS handshake"),
        );

        final trailingBytes = await completer.future;
        socket = WebSocketSocket(secureSocket, trailingBytes: trailingBytes);
      } else {
        socket = secureSocket;
      }

      final hashedPass = Sha224.hash(trojanPassword);
      final List<int> trojanHeader = [];
      trojanHeader.addAll(hashedPass.codeUnits);
      trojanHeader.addAll([0x0D, 0x0A]);
      trojanHeader.add(0x01);

      final addrBytes = buildTrojanAddressHeader(targetHost, targetPort);
      trojanHeader.addAll(addrBytes);
      trojanHeader.addAll([0x0D, 0x0A]);

      socket.add(trojanHeader);
      await socket.flush();

      return socket;
    }

    return await Socket.connect(
      targetHost,
      targetPort,
      timeout: const Duration(seconds: 10),
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
