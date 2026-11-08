import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snispoof/main.dart';
import 'package:snispoof/proxy/proxy_manager.dart';
import 'package:snispoof/screens/settings_screen.dart';
import 'package:snispoof/theme_controller.dart';

void main() {
  testWidgets('settings theme selection updates the app and home theme', (
    tester,
  ) async {
    ThemeController.instance.setDark(false);
    try {
      await tester.pumpWidget(const MyApp());
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('تیره'));
      await tester.pump();

      expect(ThemeController.instance.isDark, isTrue);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ThemeController.instance.setDark(false);
      ProxyManager.instance.cancelTimersForTesting();
    }
  });

  testWidgets('settings are grouped into polished, scrollable sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;

    try {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('تنظیمات اتصال'), findsOneWidget);
      expect(find.text('ذخیره و اعمال تنظیمات'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('سرور MHPanel'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('سرور MHPanel'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('پورت‌های پروفایل'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('پورت‌های پروفایل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      ProxyManager.instance.cancelTimersForTesting();
    }
  });
}
