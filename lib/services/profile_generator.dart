import 'dart:convert';
import '../proxy/proxy_manager.dart';

class ParsedProxyConfig {
  final String protocol; // 'trojan', 'vless', 'vmess', 'ss', or 'unknown'
  final String userOrPassword;
  final String originalHost;
  final int port;
  final String sni;
  final String hostHeader;
  final String path;
  final String transport; // 'ws', 'tcp', 'grpc', etc.
  final String security; // 'tls', 'none'
  final String remark;
  final String raw;

  const ParsedProxyConfig({
    required this.protocol,
    required this.userOrPassword,
    required this.originalHost,
    required this.port,
    required this.sni,
    required this.hostHeader,
    required this.path,
    required this.transport,
    required this.security,
    required this.remark,
    required this.raw,
  });

  bool get isValid => port > 0 && port <= 65535;
}

class ProfileGenerator {
  static const List<String> defaultCleanIps = [
    '188.114.98.0',
    '104.18.119.142',
    '104.25.165.92',
    '162.159.192.1',
    '104.16.132.229',
    '212.227.143.16',
  ];

  static List<String> getBypassIps() {
    final ips = <String>{'127.0.0.1', ...defaultCleanIps};
    final manager = ProxyManager.instance;
    if (manager.cfCleanIp.isNotEmpty) ips.add(manager.cfCleanIp);
    for (final host in manager.mhServerHosts) {
      if (RegExp(r'^[0-9.]+$').hasMatch(host.trim())) {
        ips.add(host.trim());
      }
    }
    return ips.toList();
  }

  static List<String> getBypassDomains({ParsedProxyConfig? config}) {
    final domains = <String>{};
    final manager = ProxyManager.instance;

    if (manager.cfServerSni.isNotEmpty) domains.add(manager.cfServerSni.trim());
    if (manager.fakeSni.isNotEmpty && manager.fakeSni != 'Custom ...') {
      domains.add(manager.fakeSni.trim());
    }

    for (final host in manager.mhServerHosts) {
      final trimmed = host.trim();
      if (trimmed.isNotEmpty && !RegExp(r'^[0-9.]+$').hasMatch(trimmed)) {
        domains.add(trimmed);
      }
    }

    if (config != null) {
      if (config.sni.isNotEmpty) domains.add(config.sni);
      if (config.hostHeader.isNotEmpty) domains.add(config.hostHeader);
      if (config.originalHost.isNotEmpty &&
          !RegExp(r'^[0-9.]+$').hasMatch(config.originalHost) &&
          config.originalHost != '127.0.0.1') {
        domains.add(config.originalHost);
      }
    }

    return domains.toList();
  }

  static ParsedProxyConfig parse(String input) {
    final trimmed = input.trim();

    if (trimmed.startsWith('vmess://')) {
      try {
        final b64 = trimmed.substring(8);
        final normalized = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
        final decoded = utf8.decode(base64Decode(normalized));
        final Map<String, dynamic> json = jsonDecode(decoded);

        final port = int.tryParse(json['port']?.toString() ?? '') ?? 443;
        final host = json['add']?.toString() ?? '';
        final id = json['id']?.toString() ?? '';
        final net = json['net']?.toString() ?? 'ws';
        final path = json['path']?.toString() ?? '';
        final hostHeader = json['host']?.toString() ?? '';
        final sni = json['sni']?.toString() ?? hostHeader;
        final tls = json['tls']?.toString() ?? '';
        final ps = json['ps']?.toString() ?? 'VMess-ME';

        return ParsedProxyConfig(
          protocol: 'vmess',
          userOrPassword: id,
          originalHost: host,
          port: port,
          sni: sni,
          hostHeader: hostHeader,
          path: path,
          transport: net,
          security: (tls == 'tls' || tls == '1') ? 'tls' : 'none',
          remark: ps,
          raw: trimmed,
        );
      } catch (_) {}
    }

    if (trimmed.startsWith('trojan://') ||
        trimmed.startsWith('vless://') ||
        trimmed.startsWith('ss://')) {
      try {
        final uri = Uri.parse(trimmed);
        final proto = uri.scheme.toLowerCase();
        final port = uri.hasPort ? uri.port : 443;
        final host = uri.host;
        final user = uri.userInfo;
        final q = uri.queryParameters;

        final sni = q['sni'] ?? q['peer'] ?? '';
        final hostHeader = q['host'] ?? sni;
        final path = q['path'] ?? '/';
        final transport = q['type'] ?? 'ws';
        final security = q['security'] ?? 'tls';
        final remark = uri.fragment.isNotEmpty
            ? Uri.decodeComponent(uri.fragment)
            : 'ME-Proxy-$proto';

        return ParsedProxyConfig(
          protocol: proto,
          userOrPassword: user,
          originalHost: host,
          port: port,
          sni: sni,
          hostHeader: hostHeader,
          path: path,
          transport: transport,
          security: security,
          remark: remark,
          raw: trimmed,
        );
      } catch (_) {}
    }

    // Fallback: search for host:port pattern
    final regex = RegExp(r'(@|://)([^/:@?#]+):(\d+)');
    final match = regex.firstMatch(trimmed);
    final port = match != null ? (int.tryParse(match.group(3) ?? '') ?? 40443) : 40443;
    final host = match?.group(2) ?? '127.0.0.1';

    return ParsedProxyConfig(
      protocol: 'trojan',
      userOrPassword: '',
      originalHost: host,
      port: port,
      sni: ProxyManager.instance.cfServerSni,
      hostHeader: ProxyManager.instance.cfServerSni,
      path: '/trojan-ws',
      transport: 'ws',
      security: 'tls',
      remark: 'ME-Spoofing-Trojan',
      raw: trimmed,
    );
  }

  /// Extracts the active server host domain (from config or ProxyManager).
  static String getPrimaryHostDomain({ParsedProxyConfig? config}) {
    if (config != null) {
      if (config.sni.isNotEmpty) return config.sni;
      if (config.hostHeader.isNotEmpty) return config.hostHeader;
      if (config.originalHost.isNotEmpty &&
          !RegExp(r'^[0-9.]+$').hasMatch(config.originalHost) &&
          config.originalHost != '127.0.0.1') {
        return config.originalHost;
      }
    }
    return ProxyManager.instance.primaryHostDomain;
  }

  /// Generates a unified comma-separated list of all Direct/Bypass rules (domain:Host + Clean IPs).
  static String getAllDirectRulesString({ParsedProxyConfig? config}) {
    final domains = getBypassDomains(config: config);
    final ips = getBypassIps();
    final parts = <String>[];
    for (final d in domains) {
      parts.add('domain:$d');
    }
    parts.addAll(ips);
    return parts.join(', ');
  }

  /// Generates the standard single-line URI with host pointed to 127.0.0.1.
  static String generateStandardUri(ParsedProxyConfig config, {int? customPort}) {
    final targetPort =
        (customPort != null && customPort > 0) ? customPort : config.port;

    if (config.protocol == 'vmess') {
      try {
        final b64 = config.raw.substring(8);
        final normalized = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
        final decoded = utf8.decode(base64Decode(normalized));
        final Map<String, dynamic> json = jsonDecode(decoded);
        json['add'] = '127.0.0.1';
        if (targetPort > 0) json['port'] = targetPort;
        return "vmess://${base64Encode(utf8.encode(jsonEncode(json)))}";
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(config.raw);
      return uri.replace(
        host: '127.0.0.1',
        port: targetPort > 0 ? targetPort : uri.port,
      ).toString();
    } catch (_) {
      return config.raw;
    }
  }
}

