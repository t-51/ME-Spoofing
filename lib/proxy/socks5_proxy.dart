import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'sha224.dart';
import 'websocket_socket.dart';

typedef LogCallback = void Function(String message);
typedef StatsCallback = void Function(int bytesUploaded, int bytesDownloaded);

enum ProxyState { handshake, request, connecting, piping, closed }

class Socks5Proxy {
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

  Socks5Proxy({
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
      onLog("SOCKS5 Proxy server listening on $host:$port");
      _serverSocket!.listen(
        _handleConnection,
        onError: (err) {
          if (!_isStopping) onLog("Server socket error: $err");
        },
      );
    } catch (e) {
      onLog("Failed to start proxy server: $e");
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
      onLog("Proxy server stopped");
    } catch (e) {
      onLog("Error stopping proxy server: $e");
    }
  }

  void _handleConnection(Socket clientSocket) {
    if (_isStopping) {
      clientSocket.destroy();
      return;
    }

    _activeSockets.add(clientSocket);
    onConnectionCountChanged(1);

    ProxyState state = ProxyState.handshake;
    final List<int> incomingBuffer = [];
    Socket? remoteSocket;
    StreamSubscription<Uint8List>? clientSubscription;
    StreamSubscription<Uint8List>? remoteSubscription;

    String clientAddress =
        "${clientSocket.remoteAddress.address}:${clientSocket.remotePort}";
    String targetHost = "";
    int targetPort = 0;
    bool firstPacketSent = false;

    void closeBoth() {
      if (state == ProxyState.closed) return;
      state = ProxyState.closed;

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
        if (state == ProxyState.closed) return;
        incomingBuffer.addAll(data);

        // --- 1. SOCKS5 HANDSHAKE ---
        if (state == ProxyState.handshake) {
          if (incomingBuffer.length < 2) return;

          final version = incomingBuffer[0];
          if (version != 0x05) {
            onLog(
              "[$clientAddress] Unsupported SOCKS version ($version), closing connection.",
            );
            closeBoth();
            return;
          }

          final methodCount = incomingBuffer[1];
          if (incomingBuffer.length < 2 + methodCount) {
            return;
          }

          final methods = incomingBuffer.sublist(2, 2 + methodCount);
          incomingBuffer.removeRange(0, 2 + methodCount);

          if (methods.contains(0x00)) {
            clientSocket.add([0x05, 0x00]);
            await clientSocket.flush();
            state = ProxyState.request;
          } else {
            onLog(
              "[$clientAddress] No compatible SOCKS5 authentication method, closing.",
            );
            clientSocket.add([0x05, 0xFF]);
            await clientSocket.flush();
            closeBoth();
            return;
          }
        }

        // --- 2. SOCKS5 REQUEST ---
        if (state == ProxyState.request) {
          if (incomingBuffer.length < 4) return;

          final version = incomingBuffer[0];
          final cmd = incomingBuffer[1];
          final addrType = incomingBuffer[3];

          if (version != 0x05 || cmd != 0x01) {
            onLog(
              "[$clientAddress] Unsupported SOCKS5 command ($cmd) or version ($version)",
            );
            clientSocket.add([0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            await clientSocket.flush();
            closeBoth();
            return;
          }

          int headerLength = 4;
          if (addrType == 0x01) {
            if (incomingBuffer.length < 10) return;
            final ipBytes = incomingBuffer.sublist(4, 8);
            targetHost = ipBytes.join('.');
            targetPort = ByteData.sublistView(
              Uint8List.fromList(incomingBuffer.sublist(8, 10)),
            ).getUint16(0);
            headerLength = 10;
          } else if (addrType == 0x03) {
            if (incomingBuffer.length < 5) return;
            final domainLen = incomingBuffer[4];
            if (incomingBuffer.length < 5 + domainLen + 2) return;
            targetHost = String.fromCharCodes(
              incomingBuffer.sublist(5, 5 + domainLen),
            );
            targetPort = ByteData.sublistView(
              Uint8List.fromList(
                incomingBuffer.sublist(5 + domainLen, 5 + domainLen + 2),
              ),
            ).getUint16(0);
            headerLength = 5 + domainLen + 2;
          } else if (addrType == 0x04) {
            if (incomingBuffer.length < 22) return;
            final ipBytes = incomingBuffer.sublist(4, 20);
            targetHost = ipBytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':');
            targetPort = ByteData.sublistView(
              Uint8List.fromList(incomingBuffer.sublist(20, 22)),
            ).getUint16(0);
            headerLength = 22;
          } else {
            onLog("[$clientAddress] Unknown address type ($addrType)");
            clientSocket.add([0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            await clientSocket.flush();
            closeBoth();
            return;
          }

          incomingBuffer.removeRange(0, headerLength);

          state = ProxyState.connecting;
          clientSubscription?.pause();

          try {
            remoteSocket = await _connectToDestination(targetHost, targetPort);

            clientSocket.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            await clientSocket.flush();

            state = ProxyState.piping;
            clientSubscription?.resume();

            remoteSubscription = remoteSocket!.listen(
              (remoteData) {
                if (state == ProxyState.closed) return;
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
              final initialData = Uint8List.fromList(incomingBuffer);
              incomingBuffer.clear();
              sendClientDataToRemote(initialData);
            }
          } catch (e) {
            onLog(
              "[$clientAddress] SOCKS5 connection to $targetHost:$targetPort failed: $e",
            );
            try {
              clientSocket.add([0x05, 0x04, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
              await clientSocket.flush();
            } catch (_) {}
            closeBoth();
          }
        }
        // --- 3. PIPING ---
        else if (state == ProxyState.piping) {
          final currentData = Uint8List.fromList(incomingBuffer);
          incomingBuffer.clear();
          sendClientDataToRemote(currentData);
        }
      },
      onDone: () => closeBoth(),
      onError: (err) => closeBoth(),
    );
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

      // Format Trojan request header:
      // hex(SHA224(password)) + \r\n + CMD(1) + ATYP(1) + ADDR + PORT(2) + \r\n
      final hashedPass = Sha224.hash(trojanPassword);
      final List<int> trojanHeader = [];
      trojanHeader.addAll(hashedPass.codeUnits);
      trojanHeader.addAll([0x0D, 0x0A]); // CRLF
      trojanHeader.add(0x01); // CMD: CONNECT

      final addrBytes = buildTrojanAddressHeader(targetHost, targetPort);
      trojanHeader.addAll(addrBytes);
      trojanHeader.addAll([0x0D, 0x0A]); // CRLF

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

  bool _isTlsClientHello(Uint8List data) {
    return data.length > 5 &&
        data[0] == 0x16 &&
        data[1] == 0x03 &&
        data[2] <= 0x03 &&
        data[5] == 0x01;
  }
}

/// Spoofs the SNI extension in a TLS ClientHello packet.
Uint8List spoofClientHello(Uint8List data, String fakeSni) {
  if (data.length < 47) return data;
  if (data[0] != 0x16) return data;
  if (data[5] != 0x01) return data;

  int pos = 43;
  if (pos >= data.length) return data;
  int sidLen = data[pos];
  pos += 1 + sidLen;

  if (pos + 2 > data.length) return data;
  int cipherSuitesLen = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
  pos += 2 + cipherSuitesLen;

  if (pos + 1 > data.length) return data;
  int compMethodsLen = data[pos];
  pos += 1 + compMethodsLen;

  if (pos + 2 > data.length) return data;
  int extensionsLen = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
  int extensionsStart = pos + 2;
  int extensionsEnd = extensionsStart + extensionsLen;
  if (extensionsEnd > data.length) return data;

  pos = extensionsStart;
  int sniExtensionStart = -1;
  int sniExtensionLen = -1;

  while (pos + 4 <= extensionsEnd) {
    int extType = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
    int extLen = ByteData.sublistView(data, pos + 2, pos + 4).getUint16(0);
    if (extType == 0x0000) {
      sniExtensionStart = pos;
      sniExtensionLen = 4 + extLen;
      break;
    }
    pos += 4 + extLen;
  }

  if (sniExtensionStart == -1) {
    return data;
  }

  final List<int> fakeSniBytes = fakeSni.codeUnits;
  final int fakeSniLen = fakeSniBytes.length;

  final int newExtLen = 2 + 1 + 2 + fakeSniLen;
  final ByteData newSniExt = ByteData(4 + newExtLen);
  newSniExt.setUint16(0, 0x0000); // Type
  newSniExt.setUint16(2, newExtLen); // Length
  newSniExt.setUint16(4, 1 + 2 + fakeSniLen); // Server Name List Length
  newSniExt.setUint8(6, 0x00); // Server Name Type: host_name
  newSniExt.setUint16(7, fakeSniLen); // Server Name Length

  final Uint8List newSniBytes = newSniExt.buffer.asUint8List();
  final List<int> completeNewSni = [
    ...newSniBytes.sublist(0, 9),
    ...fakeSniBytes,
  ];

  final List<int> beforeSniExt = data.sublist(
    extensionsStart,
    sniExtensionStart,
  );
  final List<int> afterSniExt = data.sublist(
    sniExtensionStart + sniExtensionLen,
    extensionsEnd,
  );
  final List<int> newExtensions = [
    ...beforeSniExt,
    ...completeNewSni,
    ...afterSniExt,
  ];
  final int newExtensionsLen = newExtensions.length;

  final List<int> handshakeBeforeExtensions = data.sublist(
    5,
    extensionsStart - 2,
  );
  final ByteData newExtLenBytes = ByteData(2)..setUint16(0, newExtensionsLen);
  final List<int> newHandshakePayload = [
    ...handshakeBeforeExtensions,
    ...newExtLenBytes.buffer.asUint8List(),
    ...newExtensions,
  ];

  final int newHandshakeLen = newHandshakePayload.length - 4;
  final ByteData newHandshakeLenBytes = ByteData(4)
    ..setUint32(0, newHandshakeLen);

  newHandshakePayload[1] = newHandshakeLenBytes.getUint8(1);
  newHandshakePayload[2] = newHandshakeLenBytes.getUint8(2);
  newHandshakePayload[3] = newHandshakeLenBytes.getUint8(3);

  final int originalRecordLen = ByteData.sublistView(data, 3, 5).getUint16(0);
  final List<int> trailingData = data.sublist(5 + originalRecordLen);

  final int newRecordLen = newHandshakePayload.length;
  final ByteData newRecordLenBytes = ByteData(2)..setUint16(0, newRecordLen);

  return Uint8List.fromList([
    data[0],
    data[1],
    data[2],
    ...newRecordLenBytes.buffer.asUint8List(),
    ...newHandshakePayload,
    ...trailingData,
  ]);
}

List<int> buildTrojanAddressHeader(String targetHost, int targetPort) {
  final List<int> header = [];
  final ip = InternetAddress.tryParse(targetHost);
  if (ip != null) {
    if (ip.type == InternetAddressType.IPv4) {
      header.add(0x01); // IPv4
      header.addAll(ip.rawAddress);
    } else {
      header.add(0x04); // IPv6
      header.addAll(ip.rawAddress);
    }
  } else {
    header.add(0x03); // Domain Name
    final hostBytes = targetHost.codeUnits;
    header.add(hostBytes.length);
    header.addAll(hostBytes);
  }
  final portBytes = ByteData(2)..setUint16(0, targetPort);
  header.addAll(portBytes.buffer.asUint8List());
  return header;
}

String? extractSni(Uint8List data) {
  try {
    if (data.length < 47) return null;
    if (data[0] != 0x16) return null;
    if (data[5] != 0x01) return null;

    int pos = 43;
    if (pos >= data.length) return null;
    int sidLen = data[pos];
    pos += 1 + sidLen;

    if (pos + 2 > data.length) return null;
    int cipherSuitesLen = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
    pos += 2 + cipherSuitesLen;

    if (pos + 1 > data.length) return null;
    int compMethodsLen = data[pos];
    pos += 1 + compMethodsLen;

    if (pos + 2 > data.length) return null;
    int extensionsLen = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
    int extensionsStart = pos + 2;
    int extensionsEnd = extensionsStart + extensionsLen;
    if (extensionsEnd > data.length) return null;

    pos = extensionsStart;
    while (pos + 4 <= extensionsEnd) {
      int extType = ByteData.sublistView(data, pos, pos + 2).getUint16(0);
      int extLen = ByteData.sublistView(data, pos + 2, pos + 4).getUint16(0);
      if (extType == 0x0000) {
        if (pos + 9 > data.length) return null;
        int nameType = data[pos + 6];
        if (nameType == 0x00) {
          int nameLen = ByteData.sublistView(
            data,
            pos + 7,
            pos + 9,
          ).getUint16(0);
          if (pos + 9 + nameLen <= data.length) {
            return String.fromCharCodes(
              data.sublist(pos + 9, pos + 9 + nameLen),
            );
          }
        }
        break;
      }
      pos += 4 + extLen;
    }
  } catch (_) {}
  return null;
}
