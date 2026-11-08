import 'dart:async';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'proxy/proxy_manager.dart';
import 'screens/home_screen.dart';
import 'services/locale_controller.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeController.instance.loadFromDisk();
  await LocaleController.instance.loadFromDisk();

  final proxyManager = ProxyManager.instance;
  await proxyManager.loadSettingsFromDisk();

  runApp(const MyApp());

  if (proxyManager.shouldReconnect) {
    unawaited(() async {
      try {
        await proxyManager.start();
      } catch (error) {
        proxyManager.log('بازیابی اتصال پس‌زمینه ناموفق بود: $error');
      }
    }());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LocaleController.instance,
      ]),
      builder: (context, _) {
        final themeMode = ThemeController.instance.themeMode;
        final selectedLocale = LocaleController.instance.locale;

        return MaterialApp(
          title: 'ME Spoofing',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          locale: selectedLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (selectedLocale != null) return selectedLocale;
            if (deviceLocale != null) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == deviceLocale.languageCode) {
                  return supported;
                }
              }
            }
            return const Locale('fa');
          },
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF7F8FA),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2855D9),
              secondary: Color(0xFF9B51E0),
              surface: Colors.white,
              error: Colors.redAccent,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontFamily: 'sans-serif'),
              bodyMedium: TextStyle(fontFamily: 'sans-serif'),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D1117),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2855D9),
              secondary: Color(0xFF9B51E0),
              surface: Color(0xFF131820),
              error: Colors.redAccent,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontFamily: 'sans-serif'),
              bodyMedium: TextStyle(fontFamily: 'sans-serif'),
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
