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

/// Pre-configured DNS Resolvers with Iran fallback hierarchy per specification.
class DnsResolverOption {
  final String name;
  final String endpoint;
  final String type; // 'doh' or 'udp'
  final String description;

  const DnsResolverOption({
    required this.name,
    required this.endpoint,
    required this.type,
    required this.description,
  });

  static const List<DnsResolverOption> presets = [
    DnsResolverOption(
      name: 'Cloudflare DoH',
      endpoint: 'https://cloudflare-dns.com/dns-query',
      type: 'doh',
      description: 'Cloudflare DoH (Encrypted)',
    ),
    DnsResolverOption(
      name: 'Google DoH',
      endpoint: 'https://dns.google/dns-query',
      type: 'doh',
      description: 'Google DoH (Anycast)',
    ),
    DnsResolverOption(
      name: 'Google Public DNS',
      endpoint: '8.8.8.8:53',
      type: 'udp',
      description: 'Google Public DNS (UDP 53)',
    ),
    DnsResolverOption(
      name: 'Cloudflare DNS',
      endpoint: '1.1.1.1:53',
      type: 'udp',
      description: 'Cloudflare DNS (UDP 53)',
    ),
    DnsResolverOption(
      name: 'Shecan (Anti-Sanction)',
      endpoint: '78.157.42.100:53',
      type: 'udp',
      description: 'Shecan Anti-Sanction (Iran Low Latency)',
    ),
    DnsResolverOption(
      name: 'Quad9 Secure',
      endpoint: '9.9.9.9:53',
      type: 'udp',
      description: 'Quad9 Secure (UDP 53)',
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
/// Operates 100% in userspace via 127.0.0.1 TCP sockets WITHOUT needing
/// Android VpnService or VPN profiles, complying strictly with Google Play policies.
class DnsTunnel {
  final DnsTunnelProtocol protocol;
  final String subdomain;
  final String publicKeyHex;
  final String resolverEndpoint;
  final String resolverType; // 'doh' or 'udp'
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
    ..connectionTimeout = const Duration(seconds: 6);

  RawDatagramSocket? _udpSocket;
  final Random _rnd = Random.secure();

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
  });

  Future<void> start() async {
    _isStopping = false;

    onLog(
      '🌐 Starting DNS Tunnel (${protocol.displayName}) ➔ Subdomain: $subdomain',
    );
    onLog('📡 Resolver: $resolverEndpoint ($resolverType)');

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
        onLog('🚀 DNS Tunnel fallback listening on 127.0.0.1:$fallbackLocalPort');

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
    }

    // Downstream polling loop: queries the resolver periodically to receive server bytes
    pollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (isClosed || _isStopping) return;
      try {
        final serverBytes = await _exchangeDns(sessionId, 0, Uint8List(0));
        if (serverBytes.isNotEmpty && !isClosed) {
          clientSocket.add(serverBytes);
          await clientSocket.flush();
          onStats(0, serverBytes.length);
        }
      } catch (_) {}
    });

    clientSocket.listen(
      (data) async {
        if (isClosed) return;
        try {
          // Chunk larger payloads into DNS query limits (~120 bytes max per query)
          int offset = 0;
          while (offset < data.length && !isClosed) {
            final end = min(offset + 110, data.length);
            final chunk = data.sublist(offset, end);
            offset = end;

            final serverBytes = await _exchangeDns(
              sessionId,
              clientSeq++,
              chunk,
            );
            onStats(chunk.length, 0);

            if (serverBytes.isNotEmpty && !isClosed) {
              clientSocket.add(serverBytes);
              await clientSocket.flush();
              onStats(0, serverBytes.length);
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

  /// Encapsulates data into a DNS query, sends via DoH or UDP, and extracts response data.
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

    Uint8List? responsePacket;
    if (resolverType == 'doh') {
      responsePacket = await _sendDohQuery(queryPacket);
    } else {
      responsePacket = await _sendUdpQuery(queryId, queryPacket);
    }

    if (responsePacket == null || responsePacket.isEmpty) {
      return Uint8List(0);
    }

    return _parseDnsResponsePayload(responsePacket);
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

  Future<Uint8List?> _sendDohQuery(Uint8List packet) async {
    try {
      final uri = Uri.parse(resolverEndpoint);
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

  Future<Uint8List?> _sendUdpQuery(int queryId, Uint8List packet) async {
    if (_udpSocket == null) return null;

    try {
      final parts = resolverEndpoint.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 53 : 53;

      final targetAddr = InternetAddress(ip);
      final completer = Completer<Uint8List>();
      _pendingQueries[queryId] = completer;

      _udpSocket!.send(packet, targetAddr, port);

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
      // Skip Name (label or compression pointer)
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

