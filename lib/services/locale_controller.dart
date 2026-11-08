import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

class LocaleController extends ValueNotifier<AppLanguage> {
  LocaleController._() : super(AppLanguage.fa);

  static final LocaleController instance = LocaleController._();

  static const _channel = MethodChannel('com.kigaping.mespoofing/settings_path');

  Locale? get locale => value.locale;
  bool get isRtl => value == AppLanguage.system
      ? (Platform.localeName.startsWith('fa') || Platform.localeName.startsWith('ar'))
      : value.isRtl;

  void setLanguage(AppLanguage language) {
    if (value == language) return;
    value = language;
    saveToDisk();
    notifyListeners();
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

  Future<void> saveToDisk() async {
    try {
      final path = await _getStoragePath();
      if (path == null) return;
      final file = File('$path/locale_pref.json');
      await file.writeAsString(jsonEncode({'language': value.code}));
    } catch (_) {}
  }

  Future<void> loadFromDisk() async {
    try {
      final path = await _getStoragePath();
      if (path == null) return;
      final file = File('$path/locale_pref.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data['language'] is String) {
          value = AppLanguage.fromCode(data['language'] as String);
        }
      }
    } catch (_) {}
  }
}
