import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/proxy/dns_tunnel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DnsTunnel Tests', () {
    test('parses multiple resolvers with numeric IPs, domains, and custom ports', () {
      const input = '8.8.8.8:53, 1.1.1.1:53, https://dns.google/dns-query, 9.9.9.9:853';
      final list = DnsTunnel.parseResolvers(input, 'udp');

      expect(list.length, 4);

      // 1. Numeric IP with port 53 (udp)
      expect(list[0].host, '8.8.8.8');
      expect(list[0].port, 53);
      expect(list[0].type, 'udp');

      // 2. Numeric IP with port 53 (udp)
      expect(list[1].host, '1.1.1.1');
      expect(list[1].port, 53);
      expect(list[1].type, 'udp');

      // 3. DoH URL
      expect(list[2].type, 'doh');
      expect(list[2].url, 'https://dns.google/dns-query');

      // 4. DoT endpoint on port 853
      expect(list[3].host, '9.9.9.9');
      expect(list[3].port, 853);
    });

    test('supports all 4 transport types: udp, tcp, doh, dot', () {
      final udpEndpoints = DnsTunnel.parseResolvers('8.8.8.8', 'udp');
      expect(udpEndpoints[0].type, 'udp');
      expect(udpEndpoints[0].port, 53);

      final tcpEndpoints = DnsTunnel.parseResolvers('1.1.1.1', 'tcp');
      expect(tcpEndpoints[0].type, 'tcp');
      expect(tcpEndpoints[0].port, 53);

      final dohEndpoints = DnsTunnel.parseResolvers('cloudflare-dns.com', 'doh');
      expect(dohEndpoints[0].type, 'doh');
      expect(dohEndpoints[0].url, contains('cloudflare-dns.com'));

      final dotEndpoints = DnsTunnel.parseResolvers('1.1.1.1', 'dot');
      expect(dotEndpoints[0].type, 'dot');
      expect(dotEndpoints[0].port, 853);
    });

    test('Base32 encode and decode works correctly for DNS tunnel framing', () {
      final original = [1, 2, 3, 4, 5, 250, 255];
      final encoded = Base32.encode(original);
      final decoded = Base32.decode(encoded);

      expect(decoded, equals(original));
    });

    test('DnsTunnelProtocol fromId resolves correctly', () {
      expect(DnsTunnelProtocol.fromId('vaydns'), DnsTunnelProtocol.vayDns);
      expect(DnsTunnelProtocol.fromId('dnstt'), DnsTunnelProtocol.dnstt);
      expect(DnsTunnelProtocol.fromId('masterdns'), DnsTunnelProtocol.masterDns);
      expect(DnsTunnelProtocol.fromId('unknown'), DnsTunnelProtocol.vayDns);
    });
  });
}

