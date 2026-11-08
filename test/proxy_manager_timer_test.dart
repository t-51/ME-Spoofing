import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/proxy/proxy_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expired free time renews for 30 minutes and is persisted', () async {
    final manager = ProxyManager.instance;
    final originalDirectory = Directory.current;
    final tempDirectory = await Directory.systemTemp.createTemp(
      'snispoof-timer-test-',
    );

    manager.cancelTimersForTesting();
    Directory.current = tempDirectory.path;
    try {
      manager.setExpirationTimestampForTesting(
        DateTime.now().millisecondsSinceEpoch - 1000,
      );

      final renewalStartedAt = DateTime.now().millisecondsSinceEpoch;
      await manager.checkTimerExpirationForTesting();

      expect(manager.remainingSeconds, inInclusiveRange(1798, 1800));
      final settings =
          jsonDecode(await File('settings.json').readAsString())
              as Map<String, dynamic>;
      final persistedExpiration = settings['expirationTimestampMs'] as int;
      expect(
        persistedExpiration,
        greaterThanOrEqualTo(
          renewalStartedAt + ProxyManager.freeRenewalTime.inMilliseconds,
        ),
      );
      expect(manager.shouldReconnect, isFalse);
    } finally {
      manager.cancelTimersForTesting();
      manager.setExpirationTimestampForTesting(0);
      Directory.current = originalDirectory.path;
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'expiry disconnects the proxy and requires a manual reconnect',
    () async {
      final manager = ProxyManager.instance;
      final originalDirectory = Directory.current;
      final tempDirectory = await Directory.systemTemp.createTemp(
        'snispoof-expiry-test-',
      );
      final portProbe = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final localPort = portProbe.port;
      await portProbe.close();

      manager.cancelTimersForTesting();
      Directory.current = tempDirectory.path;
      try {
        manager.setExpirationTimestampForTesting(
          DateTime.now().millisecondsSinceEpoch + 60000,
        );
        manager.updateMhpanelConfig(
          serverHosts: [InternetAddress.loopbackIPv4.address],
          daemonPort: 1,
          localPort: 0,
          serverPorts: [localPort],
        );
        await manager.start();
        expect(manager.isRunning, isTrue);
        expect(manager.shouldReconnect, isTrue);

        manager.setExpirationTimestampForTesting(
          DateTime.now().millisecondsSinceEpoch - 1000,
        );
        await manager.checkTimerExpirationForTesting();

        expect(manager.isRunning, isFalse);
        expect(manager.shouldReconnect, isFalse);
        expect(manager.remainingSeconds, inInclusiveRange(1798, 1800));

        await manager.start();
        expect(manager.isRunning, isTrue);
      } finally {
        if (manager.isRunning || manager.shouldReconnect) {
          await manager.stop();
        }
        manager.cancelTimersForTesting();
        manager.setExpirationTimestampForTesting(0);
        Directory.current = originalDirectory.path;
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  test('expired saved connection is not restored on app startup', () async {
    final manager = ProxyManager.instance;
    final originalDirectory = Directory.current;
    final tempDirectory = await Directory.systemTemp.createTemp(
      'snispoof-startup-expiry-test-',
    );

    manager.cancelTimersForTesting();
    Directory.current = tempDirectory.path;
    try {
      await File('settings.json').writeAsString(
        jsonEncode({
          'expirationTimestampMs': DateTime.now().millisecondsSinceEpoch - 1000,
          'proxyRequested': true,
        }),
      );

      await manager.loadSettingsFromDisk();

      expect(manager.shouldReconnect, isFalse);
      expect(manager.remainingSeconds, inInclusiveRange(1798, 1800));
    } finally {
      manager.cancelTimersForTesting();
      manager.setExpirationTimestampForTesting(0);
      Directory.current = originalDirectory.path;
      await tempDirectory.delete(recursive: true);
    }
  });
}
