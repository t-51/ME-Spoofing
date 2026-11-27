import 'dart:convert';
import 'dart:io';
import '../proxy/proxy_manager.dart';
import 'profile_generator.dart';

class SubscriptionImportResult {
  final int configCount;
  final List<int> ports;
  final List<String> domains;
  final List<String> ips;

  const SubscriptionImportResult({
    required this.configCount,
    required this.ports,
    required this.domains,
    required this.ips,
  });

  bool get hasAnyData =>
      ports.isNotEmpty || domains.isNotEmpty || ips.isNotEmpty;
}

class SubscriptionService {
  static final RegExp _ipv4Regex = RegExp(
    r'^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$',
  );

  static bool isIpAddress(String value) {
    final trimmed = value.trim();
    if (_ipv4Regex.hasMatch(trimmed)) return true;
    // Basic IPv6 check
    if (trimmed.contains(':') && !trimmed.contains(' ')) {
      try {
        Uri.parseIPv6Address(trimmed.replaceAll('[', '').replaceAll(']', ''));
        return true;
      } catch (_) {}
    }
    return false;
  }

  static bool _isValidHost(String host) {
    final h = host.trim();
    if (h.isEmpty ||
        h == '127.0.0.1' ||
        h == 'localhost' ||
        h == '0.0.0.0' ||
        h == '::1') {
      return false;
    }
    return true;
  }

  /// Fetches a subscription URL (or parses raw text/base64) and extracts all
  /// unique ports, domains, and IPs, then saves them into [ProxyManager].
  static Future<SubscriptionImportResult> fetchAndApply(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw Exception('Subscription URL or content is empty.');
    }

    String rawPayload = trimmed;
    final bool isUrl =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');

    if (isUrl) {
      rawPayload = await _httpGet(trimmed);
    }

    final result = parsePayload(rawPayload);

    if (isUrl && !result.hasAnyData) {
      // Fallback: try MHPanel ?format=b64 or /json endpoint if HTML was returned
      final uri = Uri.parse(trimmed);
      final b64Uri = uri.replace(
        queryParameters: {...uri.queryParameters, 'format': 'b64'},
      );
      try {
        final b64Body = await _httpGet(b64Uri.toString());
        final b64Res = parsePayload(b64Body);
        if (b64Res.hasAnyData) {
          await ProxyManager.instance.applySubscriptionImport(
            url: trimmed,
            domains: b64Res.domains,
            ips: b64Res.ips,
            ports: b64Res.ports,
          );
          return b64Res;
        }
      } catch (_) {}
    }

    await ProxyManager.instance.applySubscriptionImport(
      url: isUrl ? trimmed : ProxyManager.instance.subscriptionUrl,
      domains: result.domains,
      ips: result.ips,
      ports: result.ports,
    );

    return result;
  }

  static Future<String> _httpGet(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    // Allow self-signed panel certificates when fetching directly from panel IP
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'v2rayNG/1.8.23');
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  static SubscriptionImportResult parsePayload(String payload) {
    final ports = <int>{};
    final domains = <String>{};
    final ips = <String>{};
    int configCount = 0;

    void addHost(String rawHost) {
      final h = rawHost.trim().replaceAll('[', '').replaceAll(']', '');
      if (!_isValidHost(h)) return;
      if (isIpAddress(h)) {
        ips.add(h);
      } else if (h.contains('.')) {
        domains.add(h);
      }
    }

    void addPort(int? port) {
      if (port != null && port > 0 && port <= 65535) {
        ports.add(port);
      }
    }

    String text = payload.trim();

    // 1. Try JSON (Sing-box, Xray, or MHPanel /sub/<token>/json)
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          // MHPanel /sub/<token>/json server block
          if (decoded['server'] is Map) {
            final srv = decoded['server'] as Map;
            if (srv['ip'] is String) addHost(srv['ip'] as String);
            if (srv['domain'] is String) addHost(srv['domain'] as String);
          }
          // Sing-box / Xray outbounds
          if (decoded['outbounds'] is List) {
            for (final ob in decoded['outbounds'] as List) {
              if (ob is! Map) continue;
              final type = ob['type']?.toString() ?? ob['protocol']?.toString() ?? '';
              if (['direct', 'block', 'dns', 'selector', 'urltest', 'freedom', 'blackhole'].contains(type)) {
                continue;
              }
              configCount++;
              if (ob['server'] is String) addHost(ob['server'] as String);
              if (ob['server_port'] is int) addPort(ob['server_port'] as int);
              if (ob['tls'] is Map && ob['tls']['server_name'] is String) {
                addHost(ob['tls']['server_name'] as String);
              }
              if (ob['transport'] is Map &&
                  ob['transport']['headers'] is Map &&
                  ob['transport']['headers']['Host'] is String) {
                addHost(ob['transport']['headers']['Host'] as String);
              }
              // Xray vnext / servers
              final settings = ob['settings'];
              if (settings is Map) {
                if (settings['vnext'] is List) {
                  for (final v in settings['vnext'] as List) {
                    if (v is Map) {
                      if (v['address'] is String) addHost(v['address'] as String);
                      if (v['port'] is int) addPort(v['port'] as int);
                    }
                  }
                }
                if (settings['servers'] is List) {
                  for (final s in settings['servers'] as List) {
                    if (s is Map) {
                      if (s['address'] is String) addHost(s['address'] as String);
                      if (s['port'] is int) addPort(s['port'] as int);
                    }
                  }
                }
              }
              final stream = ob['streamSettings'];
              if (stream is Map) {
                if (stream['tlsSettings'] is Map &&
                    stream['tlsSettings']['serverName'] is String) {
                  addHost(stream['tlsSettings']['serverName'] as String);
                }
                if (stream['realitySettings'] is Map &&
                    stream['realitySettings']['serverName'] is String) {
                  addHost(stream['realitySettings']['serverName'] as String);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Try Base64 decode if no URI scheme is directly visible
    if (!text.contains('://')) {
      try {
        final cleaned = text.replaceAll(RegExp(r'\s+'), '');
        final normalized = cleaned.padRight((cleaned.length + 3) ~/ 4 * 4, '=');
        final decoded = utf8.decode(base64Decode(normalized), allowMalformed: true);
        if (decoded.contains('://')) {
          text = decoded;
        }
      } catch (_) {}
    }

    // 3. Parse line-by-line URIs (vless://, vmess://, trojan://, ss://, hy2://, hysteria2://, tuic://)
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || !line.contains('://')) continue;
      if (line.startsWith('http://') || line.startsWith('https://')) continue;

      final parsed = ProfileGenerator.parse(line);
      if (parsed.isValid) {
        configCount++;
        addPort(parsed.port);
        addHost(parsed.originalHost);
        addHost(parsed.sni);
        addHost(parsed.hostHeader);
      }
    }

    final sortedPorts = ports.toList()..sort();
    return SubscriptionImportResult(
      configCount: configCount,
      ports: sortedPorts,
      domains: domains.toList(),
      ips: ips.toList(),
    );
  }
}
