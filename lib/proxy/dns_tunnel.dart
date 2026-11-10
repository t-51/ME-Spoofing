import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

typedef LogCallback = void Function(String message);
typedef StatsCallback = void Function(int bytesUploaded, int bytesDownloaded);

/// DNS Tunnel Transport protocols supported by MHPanel specification.
enum DnsTunnelProtocol {
  vayDns('vaydns', 'VayDNS (V-DNS)', 5353, 'v.vpn.kigaping.com',
      '4438c41e91bf44b10a9e1a67bbade78f99137a875efc189ba54a6c95ecc2650a'),
  dnstt('dnstt', 'DNSTT SlowDNS', 5300, 't.vpn.kigaping.com',
      'b3290012dd13fe7df78551fdfbccfdfce5d3c594522fef40bf8284e4313b3a31'),
  masterDns('masterdns', 'MasterDNS Chunked', 5356, 't.kigaping.com',
      'b3290012dd13fe7df78551fdfbccfdfce5d3c594522fef40bf8284e4313b3a31'),
  slipstream('slipstream', 'Slipstream QUIC', 5354, 's.vpn.kigaping.com', ''),
  noizDns('noizdns', 'Anti-DPI NoizDNS', 5355, 'v.vpn.kigaping.com', '');

  final String id;
  final String displayName;
  final int defaultPort;
  final String defaultSubdomain;
  final String defaultPublicKey;

  const DnsTunnelProtocol(
    this.id,
    this.displayName,
    this.defaultPort,
    this.defaultSubdomain,
    this.defaultPublicKey,
  );

  static DnsTunnelProtocol fromId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return DnsTunnelProtocol.vayDns;
  }
}

/// Parsed endpoint representation for DNS resolvers (supports numeric IP and domain).
class DnsResolverEndpoint {
  final String raw;
  final String host;
  final int port;
  final String type; // 'udp', 'tcp', 'doh', 'dot'
  final String url; // For DoH

  const DnsResolverEndpoint({
    required this.raw,
    required this.host,
    required this.port,
    required this.type,
    required this.url,
  });

  String get display => type == 'doh' ? url : '$host:$port';
}

/// Pre-configured DNS Resolvers supporting multi-transport (UDP, TCP, DoH, DoT).
class DnsResolverOption {
  final String name;
  final String endpoint;
  final String type; // 'udp', 'tcp', 'doh', 'dot'
  final String description;

  const DnsResolverOption({
    required this.name,
    required this.endpoint,
    required this.type,
    required this.description,
  });

  static const List<DnsResolverOption> presets = [
    DnsResolverOption(
      name: 'Google & Cloudflare (UDP 53)',
      endpoint: '8.8.8.8:53, 1.1.1.1:53',
      type: 'udp',
      description: 'Google & Cloudflare Anycast (UDP 53)',
    ),
    DnsResolverOption(
      name: 'Google & Cloudflare (TCP 53)',
      endpoint: '8.8.8.8:53, 1.1.1.1:53',
      type: 'tcp',
      description: 'Google & Cloudflare Anycast (TCP 53)',
    ),
    DnsResolverOption(
      name: 'Cloudflare DoH (HTTPS 443)',
      endpoint: 'https://cloudflare-dns.com/dns-query, https://1.1.1.1/dns-query',
      type: 'doh',
      description: 'Cloudflare Encrypted DoH',
    ),
    DnsResolverOption(
      name: 'Google DoH (HTTPS 443)',
      endpoint: 'https://dns.google/dns-query, https://8.8.8.8/dns-query',
      type: 'doh',
      description: 'Google Anycast DoH',
    ),
    DnsResolverOption(
      name: 'Cloudflare & Google DoT (TLS 853)',
      endpoint: '1.1.1.1:853, 8.8.8.8:853',
      type: 'dot',
      description: 'Cloudflare & Google Encrypted DoT',
    ),
    DnsResolverOption(
      name: 'Quad9 Secure DoT (TLS 853)',
      endpoint: '9.9.9.9:853, 149.112.112.112:853',
      type: 'dot',
      description: 'Quad9 Security Filtering DoT',
    ),
    DnsResolverOption(
      name: 'Shecan & Electro (Iran Anti-Sanction)',
      endpoint: '78.157.42.100:53, 10.202.10.202:53',
      type: 'udp',
      description: 'Shecan & Electro Anti-Sanction (Iran Low Latency)',
    ),
  ];
}

/// Standard Base32 encoder/decoder (RFC 4648) for DNS tunneling.
class Base32 {
  static const String _chars = 'abcdefghijklmnopqrstuvwxyz234567';

  static String encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    final buffer = StringBuffer();
    int current = 0;
    int bits = 0;

    for (final b in bytes) {
      current = (current << 8) | (b & 0xFF);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_chars[(current >> bits) & 0x1F]);
      }
    }

    if (bits > 0) {
      buffer.write(_chars[(current << (5 - bits)) & 0x1F]);
    }

    return buffer.toString();
  }

  static Uint8List decode(String str) {
    final clean = str.toLowerCase().replaceAll(RegExp(r'[^a-z2-7]'), '');
    if (clean.isEmpty) return Uint8List(0);

    final out = <int>[];
    int current = 0;
    int bits = 0;

    for (int i = 0; i < clean.length; i++) {
      final val = _chars.indexOf(clean[i]);
      if (val < 0) continue;
      current = (current << 5) | val;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((current >> bits) & 0xFF);
      }
    }

    return Uint8List.fromList(out);
  }
}

/// High-performance Userspace DNS Tunnel Relay.
/// Conforms to MHPanel Multi-Transport Spec v2.0 (Mode 3).
/// Supports 4 Transports: UDP (53), TCP (53), DoH (443), DoT (853).
/// Supports multiple concurrent/fallback numeric IPs and domain resolvers.
class DnsTunnel {
  final DnsTunnelProtocol protocol;
  final String subdomain;
  final String publicKeyHex;
  final String resolverEndpoint;
  final String resolverType; // 'udp', 'tcp', 'doh', 'dot'
  final List<int> localPorts;
  final int fallbackLocalPort;

  final LogCallback onLog;
  final StatsCallback onStats;
  final void Function(int activeChange) onConnectionCountChanged;

  final List<ServerSocket> _serverSockets = [];
  final Set<int> _boundLocalPorts = {};
  final Set<Socket> _activeSockets = {};
  bool _isStopping = false;

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  RawDatagramSocket? _udpSocket;
  final Random _rnd = Random.secure();

  // Multi-resolver list parsed from resolverEndpoint
  late final List<DnsResolverEndpoint> _resolvers;
  int _activeResolverIndex = 0;

  // Live telemetry metrics
  int? lastLatencyMs;
  int queriesSent = 0;
  int queriesReceived = 0;
  String? get activeResolverDisplay =>
      _resolvers.isNotEmpty ? _resolvers[_activeResolverIndex].display : null;

  // DNS query pending response completers: queryId -> Completer<Uint8List>
  final Map<int, Completer<Uint8List>> _pendingQueries = {};

  DnsTunnel({
    required this.protocol,
    required this.subdomain,
    required this.publicKeyHex,
    required this.resolverEndpoint,
    required this.resolverType,
    required this.localPorts,
    this.fallbackLocalPort = 53001,
    required this.onLog,
    required this.onStats,
    required this.onConnectionCountChanged,
  }) {
    _resolvers = parseResolvers(resolverEndpoint, resolverType);
  }

  static List<DnsResolverEndpoint> parseResolvers(
    String input,
    String defaultType,
  ) {
    final list = <DnsResolverEndpoint>[];
    final parts = input.split(RegExp(r'[,;\s]+'));
    final effectiveType = defaultType.toLowerCase();

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      if (part.startsWith('http://') || part.startsWith('https://')) {
        try {
          final uri = Uri.parse(part);
          list.add(DnsResolverEndpoint(
            raw: part,
            host: uri.host,
            port: uri.port > 0 ? uri.port : 443,
            type: 'doh',
            url: part,
          ));
        } catch (_) {}
        continue;
      }

      String host = part;
      int port = effectiveType == 'dot'
          ? 853
          : (effectiveType == 'doh' ? 443 : 53);

      if (part.contains(':')) {
        final hostPort = part.split(':');
        host = hostPort[0].trim();
        final p = int.tryParse(hostPort[1].trim());
        if (p != null && p > 0 && p <= 65535) port = p;
      }

      String url = '';
      if (effectiveType == 'doh') {
        url = 'https://$host:$port/dns-query';
      }

      list.add(DnsResolverEndpoint(
        raw: part,
        host: host,
        port: port,
        type: effectiveType,
        url: url,
      ));
    }

    if (list.isEmpty) {
      list.add(const DnsResolverEndpoint(
        raw: '8.8.8.8:53',
        host: '8.8.8.8',
        port: 53,
        type: 'udp',
        url: '',
      ));
    }

    return list;
  }

  Future<void> start() async {
    _isStopping = false;

    onLog(
      '🌐 Starting DNS Tunnel (${protocol.displayName}) ➔ Subdomain: $subdomain',
    );
    onLog(
      '📡 Resolvers [${resolverType.toUpperCase()}]: ${_resolvers.map((r) => r.display).join(", ")}',
    );

    if (resolverType == 'udp') {
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        _udpSocket!.listen(_handleUdpMessage, onError: (err) {
          if (!_isStopping) onLog('⚠️ DNS UDP Socket error: $err');
        });
      } catch (e) {
        onLog('⚠️ Failed to bind local UDP socket for DNS tunnel: $e');
      }
    }

    final distinctPorts = <int>{};
    for (final p in localPorts) {
      if (p > 0 && p <= 65535) distinctPorts.add(p);
    }
    if (distinctPorts.isEmpty) {
      distinctPorts.add(fallbackLocalPort);
    }

    for (final port in distinctPorts) {
      try {
        final serverSocket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        _serverSockets.add(serverSocket);
        _boundLocalPorts.add(port);
        onLog('🚀 DNS Tunnel listening on 127.0.0.1:$port');

        serverSocket.listen(
          (clientSocket) => _handleClientConnection(clientSocket, port),
          onError: (err) {
            if (!_isStopping) onLog('Port $port error: $err');
          },
        );
      } catch (e) {
        onLog('⚠️ Could not bind 127.0.0.1:$port: $e');
      }
    }

    if (!_boundLocalPorts.contains(fallbackLocalPort)) {
      try {
        final fallbackSocket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          fallbackLocalPort,
        );
        _serverSockets.add(fallbackSocket);
        _boundLocalPorts.add(fallbackLocalPort);
        onLog(
          '🚀 DNS Tunnel fallback listening on 127.0.0.1:$fallbackLocalPort',
        );

        fallbackSocket.listen(
          (clientSocket) =>
              _handleClientConnection(clientSocket, fallbackLocalPort),
          onError: (err) {
            if (!_isStopping) onLog('Port $fallbackLocalPort error: $err');
          },
        );
      } catch (_) {}
    }

    if (_serverSockets.isEmpty) {
      throw Exception('Could not bind any local listening ports for DNS Tunnel.');
    }

    // Run startup probe to test resolvers and measure latency
    unawaited(_probeResolvers());
  }

  Future<void> _probeResolvers() async {
    onLog('🔍 Testing connection to DNS resolver(s)...');
    final sw = Stopwatch()..start();
    final queryId = _rnd.nextInt(0xFFFF);
    // Probe the authoritative subdomain Apex TXT record (configured by MHPanel DNS dispatcher)
    final probeDomain = subdomain;
    final queryPacket = _buildDnsQuery(queryId, probeDomain, 16); // TXT query

    final res = await _sendWithFallback(queryId, queryPacket);
    sw.stop();

    if (res != null && res.length >= 12) {
      lastLatencyMs = sw.elapsedMilliseconds;
      final rcode = res[3] & 0x0F;
      final ancount = (res[6] << 8) | res[7];

      if (rcode == 0 && ancount > 0) {
        final banner = _extractTxtString(res);
        final bannerDisplay = banner.isNotEmpty ? ' ($banner)' : '';
        onLog(
          '⚡ [DNS Tunnel] Handshake successful! DNS Tunnel Server answered in ${lastLatencyMs}ms$bannerDisplay [Status: CONNECTED & FLOWING]',
        );
      } else if (rcode == 3) {
        onLog(
          '⚠️ [DNS Tunnel] Resolver reachable (${lastLatencyMs}ms) but returned NXDOMAIN for $probeDomain. (Subdomain does not exist or NS delegation is missing in DNS!).',
        );
      } else if (rcode == 2) {
        onLog(
          '⚠️ [DNS Tunnel] Resolver reachable (${lastLatencyMs}ms) but returned SERVFAIL for $probeDomain. (Authoritative DNS tunnel server is offline or unreachable).',
        );
      } else {
        onLog(
          '⚡ [DNS Tunnel] Resolver reachable (${lastLatencyMs}ms). Waiting for client tunnel queries (RCODE: $rcode, Answers: $ancount).',
        );
      }
    } else {
      lastLatencyMs = null;
      onLog(
        '⚠️ [DNS Tunnel] Resolver probe timeout. Please verify your resolver addresses (${_resolvers.map((r) => r.display).join(", ")}) or network access.',
      );
    }
  }

  static String _extractTxtString(Uint8List packet) {
    if (packet.length < 12) return '';
    final ancount = (packet[6] << 8) | packet[7];
    if (ancount <= 0) return '';

    int idx = 12;
    // Skip Question Section
    while (idx < packet.length) {
      final len = packet[idx++];
      if (len == 0) break;
      if ((len & 0xC0) == 0xC0) {
        idx++;
        break;
      }
      idx += len;
    }
    idx += 4; // Skip QTYPE & QCLASS

    for (int a = 0; a < ancount && idx < packet.length; a++) {
      if (packet[idx] >= 0xC0) {
        idx += 2;
      } else {
        while (idx < packet.length && packet[idx] != 0) {
          idx += 1 + packet[idx];
        }
        idx++;
      }
      if (idx + 10 > packet.length) break;
      final type = (packet[idx] << 8) | packet[idx + 1];
      idx += 8;
      final rdLength = (packet[idx] << 8) | packet[idx + 1];
      idx += 2;
      if (idx + rdLength > packet.length) break;

      if (type == 16) {
        final txtBuffer = StringBuffer();
        int rPos = 0;
        while (rPos < rdLength && idx + rPos < packet.length) {
          final tLen = packet[idx + rPos++];
          if (rPos + tLen <= rdLength) {
            txtBuffer.write(
              utf8.decode(
                packet.sublist(idx + rPos, idx + rPos + tLen),
                allowMalformed: true,
              ),
            );
            rPos += tLen;
          }
        }
        final s = txtBuffer.toString().trim();
        if (s.isNotEmpty) return s;
      }
      idx += rdLength;
    }
    return '';
  }

  void _handleUdpMessage(RawSocketEvent event) {
    if (event == RawSocketEvent.read && _udpSocket != null) {
      final dg = _udpSocket!.receive();
      if (dg != null && dg.data.length >= 12) {
        final qid = (dg.data[0] << 8) | dg.data[1];
        final completer = _pendingQueries.remove(qid);
        if (completer != null && !completer.isCompleted) {
          completer.complete(dg.data);
        }
      }
    }
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

    _udpSocket?.close();
    _udpSocket = null;
    _httpClient.close(force: true);

    for (final c in _pendingQueries.values) {
      if (!c.isCompleted) c.complete(Uint8List(0));
    }
    _pendingQueries.clear();

    onLog('🛑 DNS Tunnel stopped.');
  }

  void _handleClientConnection(Socket clientSocket, int port) {
    if (_isStopping) {
      clientSocket.destroy();
      return;
    }

    try {
      clientSocket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    _activeSockets.add(clientSocket);
    onConnectionCountChanged(1);

    final sessionId = _rnd.nextInt(0xFFFFFF);
    int clientSeq = 1;
    bool isClosed = false;
    Timer? pollTimer;
    int totalClientBytesSent = 0;
    int totalClientBytesReceived = 0;

    onLog(
      '📱 [DNS Tunnel] Client connected on 127.0.0.1:$port (Session #$sessionId)',
    );

    void closeSession() {
      if (isClosed) return;
      isClosed = true;
      pollTimer?.cancel();
      try {
        clientSocket.destroy();
      } catch (_) {}
      if (_activeSockets.remove(clientSocket)) {
        onConnectionCountChanged(-1);
      }
      onLog(
        '🔌 [DNS Tunnel] Client session #$sessionId ended (Sent: ${totalClientBytesSent}B, Received: ${totalClientBytesReceived}B)',
      );
    }

    // Downstream polling loop: queries the resolver periodically to receive server bytes
    pollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (isClosed || _isStopping) return;
      try {
        final serverBytes = await _exchangeDns(sessionId, 0, Uint8List(0));
        if (serverBytes.isNotEmpty && !isClosed) {
          clientSocket.add(serverBytes);
          await clientSocket.flush();
          totalClientBytesReceived += serverBytes.length;
          onStats(0, serverBytes.length);
          onLog(
            '📥 [DNS Tunnel] Downstream received ${serverBytes.length}B from tunnel ➔ Delivered to client',
          );
        }
      } catch (_) {}
    });

    clientSocket.listen(
      (data) async {
        if (isClosed) return;
        try {
          int offset = 0;
          while (offset < data.length && !isClosed) {
            final end = min(offset + 110, data.length);
            final chunk = data.sublist(offset, end);
            offset = end;

            onLog(
              '📤 [DNS Tunnel] Forwarding ${chunk.length}B ➔ $subdomain via ${_resolvers[_activeResolverIndex].display} ($resolverType)',
            );

            final serverBytes = await _exchangeDns(
              sessionId,
              clientSeq++,
              chunk,
            );
            totalClientBytesSent += chunk.length;
            onStats(chunk.length, 0);

            if (serverBytes.isNotEmpty && !isClosed) {
              clientSocket.add(serverBytes);
              await clientSocket.flush();
              totalClientBytesReceived += serverBytes.length;
              onStats(0, serverBytes.length);
              onLog(
                '📥 [DNS Tunnel] Reply received ${serverBytes.length}B ➔ Delivered to client',
              );
            } else if (!isClosed) {
              onLog(
                '⚠️ [DNS Tunnel] No server response for ${chunk.length}B via $subdomain. (Check subdomain NS records and DNS tunnel daemon).',
              );
            }
          }
        } catch (e) {
          closeSession();
        }
      },
      onDone: closeSession,
      onError: (_) => closeSession(),
    );
  }

  /// Encapsulates data into a DNS query, sends via active transport with multi-resolver fallback.
  Future<Uint8List> _exchangeDns(
    int sessionId,
    int seq,
    List<int> payload,
  ) async {
    if (_isStopping) return Uint8List(0);

    // Frame: [seq: 2B] [sess: 3B] [payload]
    final frame = Uint8List(5 + payload.length);
    frame[0] = (seq >> 8) & 0xFF;
    frame[1] = seq & 0xFF;
    frame[2] = (sessionId >> 16) & 0xFF;
    frame[3] = (sessionId >> 8) & 0xFF;
    frame[4] = sessionId & 0xFF;
    if (payload.isNotEmpty) {
      frame.setRange(5, frame.length, payload);
    }

    final b32 = Base32.encode(frame);

    // Split base32 into DNS labels (max 60 chars each)
    final labels = <String>[];
    for (int i = 0; i < b32.length; i += 60) {
      final end = min(i + 60, b32.length);
      labels.add(b32.substring(i, end));
    }
    if (labels.isEmpty) labels.add('p');

    final fullDomain = '${labels.join('.')}.$subdomain';
    final queryId = _rnd.nextInt(0xFFFF);
    final queryPacket = _buildDnsQuery(queryId, fullDomain, 16); // TXT query

    final responsePacket = await _sendWithFallback(queryId, queryPacket);

    if (responsePacket == null || responsePacket.isEmpty) {
      return Uint8List(0);
    }

    return _parseDnsResponsePayload(responsePacket);
  }

  /// Sends query to active resolver; falls back to other resolvers on failure.
  Future<Uint8List?> _sendWithFallback(int queryId, Uint8List packet) async {
    if (_resolvers.isEmpty) return null;

    final startIndex = _activeResolverIndex;
    for (int attempt = 0; attempt < _resolvers.length; attempt++) {
      final currentIndex = (startIndex + attempt) % _resolvers.length;
      final endpoint = _resolvers[currentIndex];
      queriesSent++;

      Uint8List? response;
      final sw = Stopwatch()..start();

      switch (endpoint.type) {
        case 'tcp':
          response = await _sendTcpQuery(endpoint, packet);
          break;
        case 'dot':
          response = await _sendDotQuery(endpoint, packet);
          break;
        case 'doh':
          response = await _sendDohQuery(endpoint, packet);
          break;
        case 'udp':
        default:
          response = await _sendUdpQuery(endpoint, queryId, packet);
          break;
      }
      sw.stop();

      if (response != null && response.isNotEmpty) {
        queriesReceived++;
        lastLatencyMs = sw.elapsedMilliseconds;
        _activeResolverIndex = currentIndex;
        return response;
      }

      if (_resolvers.length > 1 && attempt < _resolvers.length - 1) {
        final nextIndex = (startIndex + attempt + 1) % _resolvers.length;
        onLog(
          '⚠️ Resolver ${endpoint.display} timed out, failing over to ${_resolvers[nextIndex].display}...',
        );
      }
    }

    return null;
  }

  Uint8List _buildDnsQuery(int id, String domain, int qtype) {
    final bytes = BytesBuilder();
    // Header
    bytes.add([
      (id >> 8) & 0xFF, id & 0xFF, // ID
      0x01, 0x00, // Flags: Standard query, Recursion Desired
      0x00, 0x01, // QDCOUNT: 1
      0x00, 0x00, // ANCOUNT: 0
      0x00, 0x00, // NSCOUNT: 0
      0x00, 0x00, // ARCOUNT: 0
    ]);

    // QNAME
    for (final label in domain.split('.')) {
      if (label.isEmpty) continue;
      final encoded = utf8.encode(label);
      bytes.addByte(encoded.length);
      bytes.add(encoded);
    }
    bytes.addByte(0x00); // Terminating zero label

    // QTYPE & QCLASS
    bytes.add([
      (qtype >> 8) & 0xFF, qtype & 0xFF, // QTYPE
      0x00, 0x01, // QCLASS: IN
    ]);

    return bytes.toBytes();
  }

  /// Sends DNS query over standard UDP socket (Port 53).
  Future<Uint8List?> _sendUdpQuery(
    DnsResolverEndpoint endpoint,
    int queryId,
    Uint8List packet,
  ) async {
    if (_udpSocket == null) {
      try {
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _udpSocket!.listen(_handleUdpMessage, onError: (err) {
          if (!_isStopping) onLog('⚠️ DNS UDP Socket error: $err');
        });
      } catch (e) {
        onLog('⚠️ Failed to initialize UDP socket: $e');
        return null;
      }
    }

    try {
      InternetAddress? targetAddr = InternetAddress.tryParse(endpoint.host);
      if (targetAddr == null) {
        final addrs = await InternetAddress.lookup(endpoint.host);
        if (addrs.isEmpty) return null;
        targetAddr = addrs.first;
      }
      final completer = Completer<Uint8List>();
      _pendingQueries[queryId] = completer;

      _udpSocket!.send(packet, targetAddr, endpoint.port);

      return await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _pendingQueries.remove(queryId);
          return Uint8List(0);
        },
      );
    } catch (_) {
      _pendingQueries.remove(queryId);
      return null;
    }
  }

  /// Sends DNS query over TCP with 2-byte big endian length prefix (RFC 7766).
  Future<Uint8List?> _sendTcpQuery(
    DnsResolverEndpoint endpoint,
    Uint8List packet,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: const Duration(seconds: 3),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      final length = packet.length;
      final sendBuffer = BytesBuilder()
        ..addByte((length >> 8) & 0xFF)
        ..addByte(length & 0xFF)
        ..add(packet);

      socket.add(sendBuffer.toBytes());
      await socket.flush();

      final completer = Completer<Uint8List?>();
      final receivedData = BytesBuilder();
      int expectedLength = -1;

      final subscription = socket.listen(
        (data) {
          receivedData.add(data);
          final currentBytes = receivedData.toBytes();
          if (expectedLength == -1 && currentBytes.length >= 2) {
            expectedLength = (currentBytes[0] << 8) | currentBytes[1];
          }
          if (expectedLength != -1 &&
              currentBytes.length >= expectedLength + 2) {
            if (!completer.isCompleted) {
              completer.complete(
                Uint8List.fromList(
                  currentBytes.sublist(2, expectedLength + 2),
                ),
              );
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) {
            final currentBytes = receivedData.toBytes();
            if (expectedLength != -1 &&
                currentBytes.length >= expectedLength + 2) {
              completer.complete(
                Uint8List.fromList(
                  currentBytes.sublist(2, expectedLength + 2),
                ),
              );
            } else {
              completer.complete(null);
            }
          }
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      await subscription.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Sends DNS query over DoT (DNS over TLS, Port 853) with length prefix (RFC 7858).
  Future<Uint8List?> _sendDotQuery(
    DnsResolverEndpoint endpoint,
    Uint8List packet,
  ) async {
    SecureSocket? socket;
    try {
      final port = endpoint.port > 0 ? endpoint.port : 853;
      socket = await SecureSocket.connect(
        endpoint.host,
        port,
        onBadCertificate: (cert) => true, // Allows raw IPs or self-signed certs
        timeout: const Duration(seconds: 4),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      final length = packet.length;
      final sendBuffer = BytesBuilder()
        ..addByte((length >> 8) & 0xFF)
        ..addByte(length & 0xFF)
        ..add(packet);

      socket.add(sendBuffer.toBytes());
      await socket.flush();

      final completer = Completer<Uint8List?>();
      final receivedData = BytesBuilder();
      int expectedLength = -1;

      final subscription = socket.listen(
        (data) {
          receivedData.add(data);
          final currentBytes = receivedData.toBytes();
          if (expectedLength == -1 && currentBytes.length >= 2) {
            expectedLength = (currentBytes[0] << 8) | currentBytes[1];
          }
          if (expectedLength != -1 &&
              currentBytes.length >= expectedLength + 2) {
            if (!completer.isCompleted) {
              completer.complete(
                Uint8List.fromList(
                  currentBytes.sublist(2, expectedLength + 2),
                ),
              );
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      await subscription.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Sends DNS query over DoH (DNS over HTTPS, Port 443).
  Future<Uint8List?> _sendDohQuery(
    DnsResolverEndpoint endpoint,
    Uint8List packet,
  ) async {
    try {
      String urlStr = endpoint.url;
      if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
        urlStr = 'https://$urlStr';
      }
      if (!urlStr.contains('/dns-query') && !urlStr.contains('?')) {
        urlStr = '$urlStr/dns-query';
      }
      final uri = Uri.parse(urlStr);
      final request = await _httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/dns-message');
      request.headers.set('Accept', 'application/dns-message');
      request.add(packet);

      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode == 200) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
        }
        return builder.toBytes();
      }
    } catch (_) {}
    return null;
  }

  Uint8List _parseDnsResponsePayload(Uint8List packet) {
    if (packet.length < 12) return Uint8List(0);

    // Read ANCOUNT
    final ancount = (packet[6] << 8) | packet[7];
    if (ancount <= 0) return Uint8List(0);

    int idx = 12;
    // Skip Question Section
    while (idx < packet.length) {
      final len = packet[idx++];
      if (len == 0) break;
      if ((len & 0xC0) == 0xC0) {
        idx++; // 2-byte pointer
        break;
      }
      idx += len;
    }
    idx += 4; // Skip QTYPE and QCLASS

    // Parse Answers
    final outBytes = BytesBuilder();
    for (int a = 0; a < ancount && idx < packet.length; a++) {
      if (packet[idx] >= 0xC0) {
        idx += 2;
      } else {
        while (idx < packet.length && packet[idx] != 0) {
          idx += 1 + packet[idx];
        }
        idx++;
      }

      if (idx + 10 > packet.length) break;
      final type = (packet[idx] << 8) | packet[idx + 1];
      idx += 8; // Skip TYPE(2), CLASS(2), TTL(4)
      final rdLength = (packet[idx] << 8) | packet[idx + 1];
      idx += 2;

      if (idx + rdLength > packet.length) break;

      if (type == 16) {
        // TXT Record
        int rPos = 0;
        final txtBuffer = StringBuffer();
        while (rPos < rdLength && idx + rPos < packet.length) {
          final tLen = packet[idx + rPos++];
          if (rPos + tLen <= rdLength) {
            txtBuffer.write(
              utf8.decode(
                packet.sublist(idx + rPos, idx + rPos + tLen),
                allowMalformed: true,
              ),
            );
            rPos += tLen;
          }
        }
        final decoded = Base32.decode(txtBuffer.toString());
        if (decoded.isNotEmpty) outBytes.add(decoded);
      } else if (type == 10) {
        // NULL Record: raw binary payload
        outBytes.add(packet.sublist(idx, idx + rdLength));
      }

      idx += rdLength;
    }

    return outBytes.toBytes();
  }
}
