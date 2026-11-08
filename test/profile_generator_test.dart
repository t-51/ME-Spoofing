import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/services/profile_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileGenerator Tests', () {
    const trojanUri =
        'trojan://Sb_fhatutsq@127.0.0.1:40443?security=tls&sni=ws.kigaping.com&insecure=0&allowInsecure=0&type=ws&host=ws.kigaping.com&path=%2Ftrojan-ws#Trojan-CleanIP-Cloudflare';

    test('parses Trojan WebSocket TLS configuration correctly', () {
      final config = ProfileGenerator.parse(trojanUri);

      expect(config.protocol, 'trojan');
      expect(config.userOrPassword, 'Sb_fhatutsq');
      expect(config.port, 40443);
      expect(config.sni, 'ws.kigaping.com');
      expect(config.hostHeader, 'ws.kigaping.com');
      expect(config.path, '/trojan-ws');
      expect(config.transport, 'ws');
      expect(config.security, 'tls');
    });

    test('generates valid Sing-box profile with direct bypass routing', () {
      final config = ProfileGenerator.parse(trojanUri);
      final jsonStr = ProfileGenerator.generateSingBoxProfile(config);

      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      expect(parsed['outbounds'], isA<List>());
      expect(parsed['route'], isA<Map>());

      final route = parsed['route'] as Map<String, dynamic>;
      final rules = route['rules'] as List<dynamic>;

      // Confirm there is an outbound direct rule containing clean IPs
      final ipRule = rules.firstWhere(
        (r) => r['outbound'] == 'direct' && r['ip_cidr'] != null,
      ) as Map<String, dynamic>;
      final ipList = ipRule['ip_cidr'] as List<dynamic>;

      expect(ipList, contains('188.114.98.0/32'));
      expect(ipList, contains('127.0.0.1/32'));

      // Confirm there is an outbound direct rule containing the server SNI
      final domainRule = rules.firstWhere(
        (r) => r['outbound'] == 'direct' && r['domain'] != null,
      ) as Map<String, dynamic>;
      final domainList = domainRule['domain'] as List<dynamic>;

      expect(domainList, contains('ws.kigaping.com'));
    });

    test('generates valid Xray / v2rayNG custom config with direct routing', () {
      final config = ProfileGenerator.parse(trojanUri);
      final jsonStr = ProfileGenerator.generateV2rayCustomConfig(config);

      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      expect(parsed['outbounds'], isA<List>());
      expect(parsed['routing'], isA<Map>());

      final routing = parsed['routing'] as Map<String, dynamic>;
      final rules = routing['rules'] as List<dynamic>;

      final directRule = rules.firstWhere(
        (r) => r['outboundTag'] == 'direct',
      ) as Map<String, dynamic>;

      final ipList = directRule['ip'] as List<dynamic>;
      expect(ipList, contains('188.114.98.0/32'));

      final domainList = directRule['domain'] as List<dynamic>;
      expect(domainList, contains('domain:ws.kigaping.com'));
    });

    test('generates standard URI pointing to 127.0.0.1', () {
      const original =
          'trojan://pass@ws.kigaping.com:443?security=tls&sni=ws.kigaping.com';
      final config = ProfileGenerator.parse(original);
      final standardUri = ProfileGenerator.generateStandardUri(config);

      expect(standardUri, contains('127.0.0.1'));
      expect(standardUri, contains('sni=ws.kigaping.com'));
    });
  });
}
