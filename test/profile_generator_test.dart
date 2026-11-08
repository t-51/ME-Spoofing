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

    test('extracts primary host domain and bypass domains correctly', () {
      final config = ProfileGenerator.parse(trojanUri);
      final hostDomain = ProfileGenerator.getPrimaryHostDomain(config: config);

      expect(hostDomain, 'ws.kigaping.com');

      final domains = ProfileGenerator.getBypassDomains(config: config);
      expect(domains, contains('ws.kigaping.com'));
    });

    test('generates all direct rules string containing Clean IPs and Host Domain', () {
      final config = ProfileGenerator.parse(trojanUri);
      final rules = ProfileGenerator.getAllDirectRulesString(config: config);

      expect(rules, contains('domain:ws.kigaping.com'));
      expect(rules, contains('188.114.98.0'));
      expect(rules, contains('127.0.0.1'));
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
