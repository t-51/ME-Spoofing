import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/main.dart';
import 'package:snispoof/proxy/proxy_manager.dart';

void main() {
  testWidgets('ME Spoofing app load smoke test', (WidgetTester tester) async {
    // Use a realistic mobile viewport: 360x800 logical pixels.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    try {
      await tester.pumpWidget(const MyApp());
      expect(find.text('ME Spoofing'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ProxyManager.instance.cancelTimersForTesting();
    }
  });
}
