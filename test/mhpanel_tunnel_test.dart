import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/proxy/mhpanel_tunnel.dart';

Future<int> _unusedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  test(
    'tries the next configured server when the first is unreachable',
    () async {
      final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final localPort = await _unusedPort();
      final acceptedClient = Completer<void>();
      final tunnel = MhpanelTunnel(
        serverHost: '127.0.0.2, 127.0.0.1',
        serverDaemonPort: upstream.port,
        serverPorts: [localPort],
        fallbackLocalPort: 0,
        fakeSni: '',
        enableFakePacket: false,
        onLog: (_) {},
        onStats: (_, _) {},
        onConnectionCountChanged: (_) {},
      );
      final upstreamSubscription = upstream.listen((socket) {
        if (!acceptedClient.isCompleted) acceptedClient.complete();
      });

      try {
        await tunnel.start();
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          localPort,
        );
        client.add([1]);
        await acceptedClient.future.timeout(const Duration(seconds: 5));
        client.destroy();
      } finally {
        await upstreamSubscription.cancel();
        await tunnel.stop();
        await upstream.close();
      }
    },
  );

  test('adds a converted profile port while the proxy is running', () async {
    final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final initialPort = await _unusedPort();
    final convertedPort = await _unusedPort();
    final acceptedClient = Completer<void>();
    final tunnel = MhpanelTunnel(
      serverHost: InternetAddress.loopbackIPv4.address,
      serverDaemonPort: upstream.port,
      serverPorts: [initialPort],
      fallbackLocalPort: 0,
      fakeSni: '',
      enableFakePacket: false,
      onLog: (_) {},
      onStats: (_, _) {},
      onConnectionCountChanged: (change) {
        if (change == 1 && !acceptedClient.isCompleted) {
          acceptedClient.complete();
        }
      },
    );

    try {
      await tunnel.start();
      await tunnel.addLocalPort(convertedPort);

      final client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        convertedPort,
      );
      await acceptedClient.future.timeout(const Duration(seconds: 2));
      client.destroy();
    } finally {
      await tunnel.stop();
      await upstream.close();
    }
  });
}
