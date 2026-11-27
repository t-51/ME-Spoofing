import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

/// Communicates with the native Android ProxyForegroundService.
///
/// When [showConnected] is called, the native Foreground Service is started.
/// This keeps the entire app process (and therefore the Dart proxy) alive
/// even when the user swipes the app away from recent apps.
class SystemNotificationService {
  static final SystemNotificationService instance =
      SystemNotificationService._internal();

  SystemNotificationService._internal() {
    _initChannel();
  }

  static const MethodChannel _channel = MethodChannel(
    'com.kigaping.mespoofing/notification',
  );

  bool _isInitialized = false;

  /// Called when user taps "قطع اتصال" in the notification
  Function()? onDisconnectRequested;

  /// Called when user taps "اتصال" in the notification (not used currently)
  Function()? onConnectRequested;

  void _initChannel() {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAction') {
        final action = call.arguments as String?;
        if (action == 'disconnect') {
          onDisconnectRequested?.call();
        } else if (action == 'connect') {
          onConnectRequested?.call();
        }
      }
    });
  }

  String _formatContent({
    required String downloadSpeed,
    required String totalDownloaded,
    required String uploadSpeed,
    required String totalUploaded,
    required int activeConnections,
  }) {
    final loc = AppLocalizations.current;
    return '⬇ ${loc.notifDownload}: $downloadSpeed  (${loc.notifTotal}: $totalDownloaded)\n'
        '⬆ ${loc.notifUpload}: $uploadSpeed  (${loc.notifTotal}: $totalUploaded)\n'
        '⚡ ${loc.notifActiveConns}: $activeConnections';
  }

  /// Start the foreground service and show connected notification.
  /// This is what keeps the proxy alive in background!
  Future<void> showConnected({
    required String downloadSpeed,
    required String totalDownloaded,
    required String uploadSpeed,
    required String totalUploaded,
    required int activeConnections,
  }) async {
    if (!Platform.isAndroid) return;
    final loc = AppLocalizations.current;
    final content = _formatContent(
      downloadSpeed: downloadSpeed,
      totalDownloaded: totalDownloaded,
      uploadSpeed: uploadSpeed,
      totalUploaded: totalUploaded,
      activeConnections: activeConnections,
    );
    await _channel.invokeMethod('startService', {
      'title': loc.notifConnectedTitle,
      'content': content,
    });
  }

  /// Update the notification content (stats) while service is running.
  Future<void> updateStats({
    required String downloadSpeed,
    required String totalDownloaded,
    required String uploadSpeed,
    required String totalUploaded,
    required int activeConnections,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final loc = AppLocalizations.current;
      final content = _formatContent(
        downloadSpeed: downloadSpeed,
        totalDownloaded: totalDownloaded,
        uploadSpeed: uploadSpeed,
        totalUploaded: totalUploaded,
        activeConnections: activeConnections,
      );
      await _channel.invokeMethod('updateNotification', {
        'title': loc.notifConnectedTitle,
        'content': content,
        'isConnected': true,
      });
    } catch (error) {
      debugPrint('Failed to update proxy notification: $error');
    }
  }

  /// Stop the foreground service (called when proxy disconnects).
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelNotification');
  }

  Future<void> showExpired() async {
    if (!Platform.isAndroid) return;
    final loc = AppLocalizations.current;
    await _channel.invokeMethod('expireService', {
      'title': loc.notifExpiredTitle,
      'content': loc.notifExpiredBody,
    });
  }

  Future<void> showTimeWarning({required Duration remaining}) async {
    if (!Platform.isAndroid) return;
    final loc = AppLocalizations.current;
    await _channel.invokeMethod('showTimeWarning', {
      'title': loc.notifWarningTitle,
      'content': loc.notifWarningBody.replaceAll(
        '{mins}',
        remaining.inMinutes.toString(),
      ),
    });
  }
}
