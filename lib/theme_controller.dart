import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeController extends ChangeNotifier implements ValueListenable<bool> {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  static const _channel =
      MethodChannel('com.kigaping.mespoofing/settings_path');

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  @override
  bool get value => _themeMode == ThemeMode.dark;

  bool get isDark => _themeMode == ThemeMode.dark;

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      saveToDisk();
    }
  }

  void setDark(bool dark) {
    setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
  }

  void applySystemUI({BuildContext? context}) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  Future<String?> _getStoragePath() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Directory.current.path;
    }
    try {
      final String? path = await _channel.invokeMethod<String>('getFilesDir');
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadFromDisk() async {
    try {
      final path = await _getStoragePath();
      if (path == null) return;
      final file = File('$path/theme_pref.json');
      if (await file.exists()) {
        final text = await file.readAsString();
        final data = jsonDecode(text) as Map<String, dynamic>;
        final modeStr = data['themeMode'] as String?;
        if (modeStr == 'light') {
          _themeMode = ThemeMode.light;
        } else if (modeStr == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> saveToDisk() async {
    try {
      final path = await _getStoragePath();
      if (path == null) return;
      final file = File('$path/theme_pref.json');
      final modeStr = _themeMode == ThemeMode.light
          ? 'light'
          : _themeMode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await file.writeAsString(jsonEncode({'themeMode': modeStr}));
    } catch (_) {}
  }
}
