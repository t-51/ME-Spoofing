import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'socks5_proxy.dart';
import 'mhpanel_tunnel.dart';
import '../services/system_notification_service.dart';

enum TransportMode {
  directSni('direct_sni', 'حالت ۱: مستقیم با ضد فیلتر SNI (پورت ۱۵۴۴۳)'),
  cloudflareClean('cloudflare_clean', 'حالت ۲: کلودفلر آی‌پی تمیز + فرگمنت (پورت ۴۴۳)');

  final String id;
  final String displayName;
  const TransportMode(this.id, this.displayName);

  static TransportMode fromId(String id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return TransportMode.directSni;
  }
}

class ProxyManager extends ChangeNotifier {
  static const initialFreeTime = Duration(minutes: 30);
  static const freeRenewalTime = Duration(minutes: 30);
  static const rewardedTime = Duration(hours: 4);
  static const timeWarningThreshold = Duration(minutes: 5);

  static final ProxyManager instance = ProxyManager._internal();
  ProxyManager._internal() {
    _startWallClockTicker();
    SystemNotificationService.instance.onDisconnectRequested = () {
      stop();
    };
    SystemNotificationService.instance.onConnectRequested = () {
      start();
    };
  }

  MhpanelTunnel? _mhpanelTunnel;
  Socks5Proxy? _socksProxy;

  TransportMode _transportMode = TransportMode.directSni;

  bool _isRunning = false;
  bool _proxyRequested = false;
  int _activeConnections = 0;
  int _totalBytesUploaded = 0;
  int _totalBytesDownloaded = 0;
  double _uploadSpeed = 0.0; // KB/s
  double _downloadSpeed = 0.0; // KB/s

  // Decoupled log notifier to prevent UI freezes
  final ValueNotifier<List<String>> logNotifier = ValueNotifier<List<String>>(
    [],
  );
  final List<String> _logs = [];
  Timer? _logBatchTimer;
  bool _logBatchPending = false;

  // Persisted time allowance: free seconds (paused on disconnect) + wall-clock reward timestamp.
  int _rewardExpirationTimestampMs = 0;
  int _freeSecondsRemaining = 1800;
  int _lastTimeWarningExpirationTimestampMs = 0;
  bool _hasShown5MinWarning = false;
  int _lastCommunityDialogTimestampMs = 0;
  Timer? _wallClockTimer;
  bool _expirationHandling = false;

  int get lastCommunityDialogTimestampMs => _lastCommunityDialogTimestampMs;

  bool get shouldShowCommunityDialogOnLaunch {
    if (_lastCommunityDialogTimestampMs <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - _lastCommunityDialogTimestampMs) >=
        const Duration(hours: 12).inMilliseconds;
  }

  void markCommunityDialogShown() {
    _lastCommunityDialogTimestampMs = DateTime.now().millisecondsSinceEpoch;
    saveSettingsToDisk();
  }

  // --- MHPanel Dedicated Settings ---
  List<String> _mhServerHosts = ["212.227.143.16"];
  int _mhDaemonPort = 15443;
  int _mhLocalPort = 40443;
  String _mhFakeSni = "speedtest.net";
  int _mhFragmentDelayMs = 3;
  bool _mhEnableFakePacket = true;
  List<int> _mhServerPorts = [20456, 20451, 20454, 20455];

  // --- Mode 2: Cloudflare Clean IP Settings ---
  String _cfCleanIp = "188.114.98.0";
  int _cfCleanPort = 443;
  String _cfServerSni = "ws.kigaping.com";
  int _cfFragmentDelayMs = 5;
  int _cfFragmentSize = 2;

  // Configurable Legacy / Auxiliary Settings
  String _host = "127.0.0.1";
  int _socksPort = 10810;
  int _httpPort = 10809;
  int _tunnelPort = 40443;
  String _proxyMode = "mhpanel";

  // DPI Bypass settings
  bool _enableSplitting = true;
  int _splitSize = 2;
  int _splitDelayMs = 100;
  String _fakeSni = "speedtest.net";
  String _cdnIp = "212.227.143.16";
  int _cdnPort = 443;
  bool _enableFakePacket = true;
  int _fakeTtl = 4;
  bool _enableSniSpoofing = true;

  // Legacy compatibility getters/fields
  final String _trojanPassword = "humanity";
  final String _trojanServerSni = "speedtest.net";
  final String _trojanTransport = "tcp";
  final String _trojanPath = "/";
  final String _trojanHost = "speedtest.net";
  final String _psiphonRegion = "Best Performance";
  final String _psiphonProtocol = "OSSH";
  final int _psiphonPort = 1082;
  final String _warpKey = "";
  final String _warpEndpointIp = "162.159.192.1";
  final int _warpPort = 2408;

  Timer? _statsTimer;
  int _lastBytesUploaded = 0;
  int _lastBytesDownloaded = 0;

  String _formatBytes(int bytes) {
    double kb = bytes / 1024.0;
    if (kb >= 1024.0) {
      double mb = kb / 1024.0;
      if (mb >= 1024.0) {
        return "${(mb / 1024.0).toStringAsFixed(2)} GB";
      }
      return "${mb.toStringAsFixed(2)} MB";
    }
    return "${kb.toStringAsFixed(1)} KB";
  }

  void _startWallClockTicker() {
    _wallClockTimer?.cancel();
    _wallClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning) {
        if (rewardRemainingSeconds <= 0) {
          if (_freeSecondsRemaining > 0) {
            _freeSecondsRemaining--;
          }
        }
        final left = remainingSeconds;
        if (left <= 0) {
          unawaited(_renewExpiredAllowance(disconnectProxy: true));
        } else if (left <= timeWarningThreshold.inSeconds) {
          if (!_hasShown5MinWarning) {
            _hasShown5MinWarning = true;
            _notifyTimeEnding();
          }
        } else {
          _hasShown5MinWarning = false;
        }
      }
      notifyListeners();
    });
  }

  void _notifyTimeEnding() {
    unawaited(() async {
      try {
        await SystemNotificationService.instance.showTimeWarning(
          remaining: timeWarningThreshold,
        );
      } catch (error) {
        log("❌ نمایش اعلان نزدیک‌شدن به پایان زمان ناموفق بود: $error");
      }
    }());
  }

  Future<void> _renewExpiredAllowance({bool disconnectProxy = false}) async {
    if (_expirationHandling) return;
    _expirationHandling = true;
    try {
      if (disconnectProxy && (_isRunning || _proxyRequested)) {
        try {
          await stop(expired: true);
        } catch (error) {
          log("❌ قطع اتصال خودکار پس از پایان زمان ناموفق بود: $error");
        }
      }
      _proxyRequested = false;
      _freeSecondsRemaining = freeRenewalTime.inSeconds;
      _lastTimeWarningExpirationTimestampMs = 0;
      _hasShown5MinWarning = false;
      log("⏳ زمان رایگان تمدید شد؛ برای اتصال دوباره دکمهٔ اتصال را بزنید.");
      notifyListeners();
      await saveSettingsToDisk(throwOnError: true);
    } catch (error) {
      log("❌ ذخیرهٔ تمدید خودکار زمان ناموفق بود: $error");
    } finally {
      _expirationHandling = false;
    }
  }

  Future<void> _checkTimerExpiration() async {
    if (remainingSeconds <= 0) {
      await _renewExpiredAllowance(disconnectProxy: true);
    }
  }

  @visibleForTesting
  void cancelTimersForTesting() {
    _wallClockTimer?.cancel();
    _wallClockTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    _logBatchTimer?.cancel();
    _logBatchTimer = null;
  }

  @visibleForTesting
  void setExpirationTimestampForTesting(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (timestampMs <= 0 || timestampMs <= now) {
      _rewardExpirationTimestampMs = 0;
      _freeSecondsRemaining = 0;
    } else {
      _freeSecondsRemaining = (timestampMs - now) ~/ 1000;
    }
  }

  @visibleForTesting
  Future<void> checkTimerExpirationForTesting() => _checkTimerExpiration();

  int get rewardRemainingSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _rewardExpirationTimestampMs > now
        ? ((_rewardExpirationTimestampMs - now) ~/ 1000)
        : 0;
  }

  int get freeSecondsRemaining => _freeSecondsRemaining;

  int get remainingSeconds {
    return rewardRemainingSeconds + _freeSecondsRemaining;
  }

  String get remainingTimeFormatted {
    final totalSec = remainingSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void addRewardTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_rewardExpirationTimestampMs < now) {
      _rewardExpirationTimestampMs = now + rewardedTime.inMilliseconds;
    } else {
      _rewardExpirationTimestampMs += rewardedTime.inMilliseconds;
    }
    _hasShown5MinWarning = false;
    log(
      "🎁 چهار ساعت پاداش تبلیغاتی افزوده شد؛ زمان باقی‌مانده: $remainingTimeFormatted",
    );
    notifyListeners();
    saveSettingsToDisk();
  }

  // Getters
  bool get isRunning => _isRunning;
  bool get shouldReconnect => _proxyRequested;
  int get activeConnections => _activeConnections;
  int get totalBytesUploaded => _totalBytesUploaded;
  int get totalBytesDownloaded => _totalBytesDownloaded;
  double get uploadSpeed => _uploadSpeed;
  double get downloadSpeed => _downloadSpeed;
  List<String> get logs => List.unmodifiable(_logs);

  // Transport Mode
  TransportMode get transportMode => _transportMode;
  void setTransportMode(TransportMode mode) {
    if (_transportMode != mode) {
      _transportMode = mode;
      notifyListeners();
      saveSettingsToDisk();
    }
  }

  // Cloudflare Clean IP (Mode 2)
  String get cfCleanIp => _cfCleanIp;
  int get cfCleanPort => _cfCleanPort;
  String get cfServerSni => _cfServerSni;
  int get cfFragmentDelayMs => _cfFragmentDelayMs;
  int get cfFragmentSize => _cfFragmentSize;

  void updateCloudflareCleanConfig({
    String? cleanIp,
    int? cleanPort,
    String? serverSni,
    int? fragmentDelayMs,
    int? fragmentSize,
  }) {
    if (cleanIp != null) _cfCleanIp = cleanIp.trim();
    if (cleanPort != null) _cfCleanPort = cleanPort;
    if (serverSni != null) _cfServerSni = serverSni.trim();
    if (fragmentDelayMs != null) _cfFragmentDelayMs = fragmentDelayMs;
    if (fragmentSize != null) _cfFragmentSize = fragmentSize;
    notifyListeners();
    saveSettingsToDisk();
  }

  // MHPanel Getters
  String get mhServerHost => _mhServerHosts.first;
  List<String> get mhServerHosts => List.unmodifiable(_mhServerHosts);
  String get mhServerHostsString => _mhServerHosts.join(', ');
  int get mhDaemonPort => _mhDaemonPort;
  int get mhTargetPort =>
      _mhServerPorts.isNotEmpty ? _mhServerPorts.first : _mhLocalPort;
  int get mhLocalPort => _mhLocalPort;
  String get mhFakeSni => _mhFakeSni;
  int get mhFragmentDelayMs => _mhFragmentDelayMs;
  bool get mhEnableFakePacket => _mhEnableFakePacket;
  List<int> get mhServerPorts => List.unmodifiable(_mhServerPorts);
  String get mhServerPortsString => _mhServerPorts.join(', ');

  String get primaryHostDomain {
    if (_cfServerSni.isNotEmpty && _cfServerSni != 'ws.kigaping.com') {
      return _cfServerSni;
    }
    for (final host in _mhServerHosts) {
      final trimmed = host.trim();
      if (trimmed.isNotEmpty &&
          !RegExp(r'^[0-9.]+$').hasMatch(trimmed) &&
          trimmed != '127.0.0.1') {
        return trimmed;
      }
    }
    return _cfServerSni.isNotEmpty ? _cfServerSni : 'ws.kigaping.com';
  }

  void applyConfigDetails({int? port, String? hostDomain}) {
    bool changed = false;
    if (port != null &&
        port > 0 &&
        port <= 65535 &&
        !_mhServerPorts.contains(port)) {
      _mhServerPorts.add(port);
      _addLiveListener(port);
      changed = true;
    }
    if (hostDomain != null && hostDomain.trim().isNotEmpty) {
      final trimmed = hostDomain.trim();
      if (!RegExp(r'^[0-9.]+$').hasMatch(trimmed) && trimmed != '127.0.0.1') {
        _cfServerSni = trimmed;
        if (!_mhServerHosts.contains(trimmed)) {
          _mhServerHosts.add(trimmed);
        }
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      saveSettingsToDisk();
    }
  }

  String get host => _host;
  int get socksPort => _socksPort;
  int get httpPort => _httpPort;
  int get tunnelPort => _tunnelPort;
  String get proxyMode => _proxyMode;

  bool get enableSplitting => _enableSplitting;
  int get splitSize => _splitSize;
  int get splitDelayMs => _splitDelayMs;
  String get fakeSni => _fakeSni;
  String get cdnIp => _cdnIp;
  int get cdnPort => _cdnPort;
  bool get enableFakePacket => _enableFakePacket;
  int get fakeTtl => _fakeTtl;
  bool get enableSniSpoofing => _enableSniSpoofing;

  String get trojanPassword => _trojanPassword;
  String get trojanServerSni => _trojanServerSni;
  String get trojanTransport => _trojanTransport;
  String get trojanPath => _trojanPath;
  String get trojanHost => _trojanHost;
  String get psiphonRegion => _psiphonRegion;
  String get psiphonProtocol => _psiphonProtocol;
  int get psiphonPort => _psiphonPort;
  String get warpKey => _warpKey;
  String get warpEndpointIp => _warpEndpointIp;
  int get warpPort => _warpPort;

  int get port => _mhLocalPort;

  // Update MHPanel configuration
  void updateMhpanelConfig({
    String? serverHost,
    List<String>? serverHosts,
    int? daemonPort,
    int? targetPort,
    int? localPort,
    String? fakeSni,
    int? fragmentDelayMs,
    bool? enableFakePacket,
    List<int>? serverPorts,
  }) {
    final newlyAddedPorts = serverPorts
        ?.where((port) => !_mhServerPorts.contains(port))
        .toList();
    if (serverHosts != null || serverHost != null) {
      final hosts = _parseServerHosts(serverHosts?.join(',') ?? serverHost!);
      if (hosts.isEmpty) {
        throw const FormatException('At least one server address is required.');
      }
      _mhServerHosts = hosts;
    }
    if (daemonPort != null) _mhDaemonPort = daemonPort;
    if (localPort != null) _mhLocalPort = localPort;
    if (fakeSni != null) _mhFakeSni = fakeSni.trim();
    if (fragmentDelayMs != null) _mhFragmentDelayMs = fragmentDelayMs;
    if (enableFakePacket != null) _mhEnableFakePacket = enableFakePacket;
    if (serverPorts != null) _mhServerPorts = serverPorts;
    if (targetPort != null && !_mhServerPorts.contains(targetPort)) {
      _mhServerPorts.insert(0, targetPort);
    }

    notifyListeners();
    saveSettingsToDisk();
    if (_isRunning && newlyAddedPorts != null) {
      for (final port in newlyAddedPorts) {
        _addLiveListener(port);
      }
    }
  }

  static List<String> _parseServerHosts(String input) {
    final hosts = <String>[];
    for (final part in input.split(',')) {
      final host = part.trim();
      if (host.isNotEmpty && !hosts.contains(host)) hosts.add(host);
    }
    return hosts;
  }

  void setServerPorts(List<int> ports) {
    _mhServerPorts = ports.where((p) => p > 0 && p <= 65535).toList();
    notifyListeners();
    saveSettingsToDisk();
  }

  void setServerPortsFromString(String portsStr) {
    final parts = portsStr.split(RegExp(r'[,;\s]+'));
    final ports = <int>[];
    for (final p in parts) {
      final parsed = int.tryParse(p.trim());
      if (parsed != null && parsed > 0 && parsed <= 65535) {
        if (!ports.contains(parsed)) ports.add(parsed);
      }
    }
    _mhServerPorts = ports;
    notifyListeners();
    saveSettingsToDisk();
  }

  void addServerPort(int port) {
    if (port > 0 && port <= 65535 && !_mhServerPorts.contains(port)) {
      _mhServerPorts.add(port);
      notifyListeners();
      saveSettingsToDisk();
      _addLiveListener(port);
    }
  }

  void _addLiveListener(int port) {
    final tunnel = _mhpanelTunnel;
    if (!_isRunning || tunnel == null) return;
    unawaited(() async {
      try {
        await tunnel.addLocalPort(port);
      } catch (error) {
        log("❌ Could not add local listener for port $port: $error");
      }
    }());
  }

  void removeServerPort(int port) {
    _mhServerPorts.remove(port);
    notifyListeners();
    saveSettingsToDisk();
  }

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = "[$timestamp] $message";
    debugPrint(logLine);

    _logs.add(logLine);
    if (_logs.length > 200) {
      _logs.removeRange(0, 50);
    }

    // Throttle UI notification to avoid UI freezes
    if (!_logBatchPending) {
      _logBatchPending = true;
      _logBatchTimer = Timer(const Duration(milliseconds: 350), () {
        _logBatchPending = false;
        logNotifier.value = List.of(_logs);
      });
    }
  }

  void clearLogs() {
    _logs.clear();
    logNotifier.value = [];
  }

  Future<void> start() async {
    if (_isRunning) return;

    _totalBytesUploaded = 0;
    _totalBytesDownloaded = 0;
    _uploadSpeed = 0.0;
    _downloadSpeed = 0.0;
    _lastBytesUploaded = 0;
    _lastBytesDownloaded = 0;
    _activeConnections = 0;

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    log("🚀 Starting MHPanel SNI-Spoofing Engine");
    log("🌐 Server Hosts: $mhServerHostsString:$_mhDaemonPort");
    log("🛡️ Decoy SNI: $_mhFakeSni");
    log("⚡ Fragment Delay: ${_mhFragmentDelayMs}ms");
    log("🔌 Configured Ports: ${_mhServerPorts.join(', ')}");
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    if (remainingSeconds <= 0) {
      await _renewExpiredAllowance();
    }

    if (remainingSeconds <= 0) {
      _proxyRequested = false;
      await saveSettingsToDisk(throwOnError: true);
      log("⚠️ زمان اتصال به پایان رسیده است. برای تمدید تبلیغ مشاهده کنید.");
      try {
        await SystemNotificationService.instance.showExpired();
      } catch (error) {
        log("❌ نمایش اعلان پایان زمان ناموفق بود: $error");
      }
      throw Exception(
        "زمان اتصال به پایان رسیده است. لطفاً با تماشای ویدیو تبلیغاتی زمان دریافت کنید.",
      );
    }

    _proxyRequested = true;
    try {
      await saveSettingsToDisk(throwOnError: true);
    } catch (error) {
      _proxyRequested = false;
      rethrow;
    }

    final ports = _mhServerPorts.isNotEmpty ? _mhServerPorts : [_mhLocalPort];

    _mhpanelTunnel = MhpanelTunnel(
      transportMode: _transportMode == TransportMode.cloudflareClean
          ? MhpanelTransportMode.cloudflareClean
          : MhpanelTransportMode.directSni,
      serverHost: _transportMode == TransportMode.cloudflareClean
          ? _cfCleanIp
          : mhServerHost,
      serverHosts: _transportMode == TransportMode.cloudflareClean
          ? [_cfCleanIp]
          : _mhServerHosts,
      serverDaemonPort: _transportMode == TransportMode.cloudflareClean
          ? _cfCleanPort
          : _mhDaemonPort,
      serverPorts: ports,
      fallbackLocalPort: _mhLocalPort,
      fakeSni: _transportMode == TransportMode.cloudflareClean
          ? _cfServerSni
          : _mhFakeSni,
      fragmentDelayMs: _transportMode == TransportMode.cloudflareClean
          ? _cfFragmentDelayMs
          : _mhFragmentDelayMs,
      enableFakePacket: _transportMode == TransportMode.cloudflareClean
          ? false
          : _mhEnableFakePacket,
      cfCleanIp: _cfCleanIp,
      cfCleanPort: _cfCleanPort,
      cfServerSni: _cfServerSni,
      onLog: (msg) => log(msg),
      onStats: (uploaded, downloaded) {
        _totalBytesUploaded += uploaded;
        _totalBytesDownloaded += downloaded;
      },
      onConnectionCountChanged: (change) {
        _activeConnections += change;
        if (_activeConnections < 0) _activeConnections = 0;
      },
    );

    try {
      if (Platform.isAndroid) {
        await SystemNotificationService.instance.showConnected(
          downloadSpeed: "${_downloadSpeed.toStringAsFixed(1)} KB/s",
          totalDownloaded: _formatBytes(_totalBytesDownloaded),
          uploadSpeed: "${_uploadSpeed.toStringAsFixed(1)} KB/s",
          totalUploaded: _formatBytes(_totalBytesUploaded),
          activeConnections: _activeConnections,
        );
      }
      await _mhpanelTunnel!.start();
      _isRunning = true;

      _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentUploaded = _totalBytesUploaded;
        final currentDownloaded = _totalBytesDownloaded;

        _uploadSpeed = (currentUploaded - _lastBytesUploaded) / 1024.0;
        _downloadSpeed = (currentDownloaded - _lastBytesDownloaded) / 1024.0;

        _lastBytesUploaded = currentUploaded;
        _lastBytesDownloaded = currentDownloaded;

        SystemNotificationService.instance.updateStats(
          downloadSpeed: "${_downloadSpeed.toStringAsFixed(1)} KB/s",
          totalDownloaded: _formatBytes(_totalBytesDownloaded),
          uploadSpeed: "${_uploadSpeed.toStringAsFixed(1)} KB/s",
          totalUploaded: _formatBytes(_totalBytesUploaded),
          activeConnections: _activeConnections,
        );

        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      log("❌ Failed to start MHPanel proxy: $e");
      _isRunning = false;
      _proxyRequested = false;
      await saveSettingsToDisk();
      try {
        await SystemNotificationService.instance.cancel();
      } catch (cleanupError) {
        log(
          "❌ Failed to stop proxy foreground service after startup error: $cleanupError",
        );
      }
      final failedTunnel = _mhpanelTunnel;
      _mhpanelTunnel = null;
      if (failedTunnel != null) {
        try {
          await failedTunnel.stop();
        } catch (cleanupError) {
          log(
            "❌ Failed to clean up MHPanel proxy after startup error: $cleanupError",
          );
        }
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop({bool expired = false}) async {
    if (!_isRunning && !_proxyRequested) return;

    _proxyRequested = false;
    await saveSettingsToDisk();

    _statsTimer?.cancel();
    _statsTimer = null;
    _logBatchTimer?.cancel();
    _logBatchPending = false;

    if (_mhpanelTunnel != null) {
      await _mhpanelTunnel!.stop();
      _mhpanelTunnel = null;
    }

    if (_socksProxy != null) {
      await _socksProxy!.stop();
      _socksProxy = null;
    }
    _isRunning = false;
    _activeConnections = 0;
    _uploadSpeed = 0.0;
    _downloadSpeed = 0.0;
    notifyListeners();

    try {
      if (expired) {
        await SystemNotificationService.instance.showExpired();
      } else {
        await SystemNotificationService.instance.cancel();
      }
    } catch (error) {
      log("❌ Failed to update proxy notification after disconnect: $error");
    }
  }

  static const _channel = MethodChannel(
    'com.kigaping.mespoofing/settings_path',
  );

  Future<String?> _getStoragePath() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Directory.current.path;
    }
    try {
      final String? path = await _channel.invokeMethod<String>('getFilesDir');
      return path;
    } catch (e) {
      if (Platform.isAndroid) rethrow;
      return null;
    }
  }

  Future<void> saveSettingsToDisk({bool throwOnError = false}) async {
    try {
      final path = await _getStoragePath();
      if (path == null) return;

      final file = File('$path/settings.json');
      final Map<String, dynamic> data = {
        'expirationTimestampMs':
            DateTime.now().millisecondsSinceEpoch + remainingSeconds * 1000,
        'rewardExpirationTimestampMs': _rewardExpirationTimestampMs,
        'freeSecondsRemaining': _freeSecondsRemaining,
        'lastTimeWarningExpirationTimestampMs':
            _lastTimeWarningExpirationTimestampMs,
        'lastCommunityDialogTimestampMs': _lastCommunityDialogTimestampMs,
        'proxyRequested': _proxyRequested,
        'transportMode': _transportMode.id,
        'cfCleanIp': _cfCleanIp,
        'cfCleanPort': _cfCleanPort,
        'cfServerSni': _cfServerSni,
        'cfFragmentDelayMs': _cfFragmentDelayMs,
        'cfFragmentSize': _cfFragmentSize,
        'mhServerHost': mhServerHost,
        'mhServerHosts': _mhServerHosts,
        'mhDaemonPort': _mhDaemonPort,
        'mhLocalPort': _mhLocalPort,
        'mhFakeSni': _mhFakeSni,
        'mhFragmentDelayMs': _mhFragmentDelayMs,
        'mhEnableFakePacket': _mhEnableFakePacket,
        'mhServerPorts': _mhServerPorts,
        'host': _host,
        'socksPort': _socksPort,
        'httpPort': _httpPort,
        'tunnelPort': _tunnelPort,
        'proxyMode': _proxyMode,
        'enableSplitting': _enableSplitting,
        'splitSize': _splitSize,
        'splitDelayMs': _splitDelayMs,
        'fakeSni': _fakeSni,
        'cdnIp': _cdnIp,
        'cdnPort': _cdnPort,
        'enableFakePacket': _enableFakePacket,
        'fakeTtl': _fakeTtl,
        'enableSniSpoofing': _enableSniSpoofing,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      log("Error saving settings to disk: $e");
      if (throwOnError) rethrow;
    }
  }

  Future<void> loadSettingsFromDisk() async {
    final path = await _getStoragePath();
    if (path == null) return;

    final file = File('$path/settings.json');
    if (!await file.exists()) {
      // First install: initialize with 30 minutes of free time.
      _freeSecondsRemaining = initialFreeTime.inSeconds;
      _rewardExpirationTimestampMs = 0;
      await saveSettingsToDisk();
      return;
    }

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (data['rewardExpirationTimestampMs'] is int) {
        _rewardExpirationTimestampMs =
            data['rewardExpirationTimestampMs'] as int;
      }
      if (data['freeSecondsRemaining'] is int) {
        _freeSecondsRemaining = data['freeSecondsRemaining'] as int;
      } else if (data['expirationTimestampMs'] != null) {
        final exp = data['expirationTimestampMs'] as int;
        final diff = exp - DateTime.now().millisecondsSinceEpoch;
        _freeSecondsRemaining = diff > 0 ? (diff ~/ 1000) : 0;
      } else if (data['remainingSeconds'] != null) {
        _freeSecondsRemaining = data['remainingSeconds'] as int;
      } else {
        _freeSecondsRemaining = initialFreeTime.inSeconds;
      }

      if (data['lastTimeWarningExpirationTimestampMs'] is int) {
        _lastTimeWarningExpirationTimestampMs =
            data['lastTimeWarningExpirationTimestampMs'] as int;
      }
      if (data['lastCommunityDialogTimestampMs'] is int) {
        _lastCommunityDialogTimestampMs =
            data['lastCommunityDialogTimestampMs'] as int;
      }

      if (_freeSecondsRemaining <= 0 && rewardRemainingSeconds <= 0) {
        _freeSecondsRemaining = freeRenewalTime.inSeconds;
      }
      if (data['transportMode'] is String) {
        _transportMode = TransportMode.fromId(data['transportMode'] as String);
      }
      if (data['cfCleanIp'] is String) _cfCleanIp = data['cfCleanIp'];
      if (data['cfCleanPort'] is int) _cfCleanPort = data['cfCleanPort'];
      if (data['cfServerSni'] is String) _cfServerSni = data['cfServerSni'];
      if (data['cfFragmentDelayMs'] is int) {
        _cfFragmentDelayMs = data['cfFragmentDelayMs'];
      }
      if (data['cfFragmentSize'] is int) {
        _cfFragmentSize = data['cfFragmentSize'];
      }

      final savedHosts = data['mhServerHosts'];
      if (savedHosts is List) {
        _mhServerHosts = _parseServerHosts(
          savedHosts.whereType<String>().join(','),
        );
      } else if (data['mhServerHost'] is String) {
        _mhServerHosts = _parseServerHosts(data['mhServerHost'] as String);
      }
      if (_mhServerHosts.isEmpty) _mhServerHosts = ["212.227.143.16"];
      _proxyRequested = data['proxyRequested'] == true;
      if (data['mhDaemonPort'] != null) _mhDaemonPort = data['mhDaemonPort'];
      if (data['mhLocalPort'] != null) _mhLocalPort = data['mhLocalPort'];
      if (data['mhFakeSni'] != null) _mhFakeSni = data['mhFakeSni'];
      if (data['mhFragmentDelayMs'] != null) {
        _mhFragmentDelayMs = data['mhFragmentDelayMs'];
      }
      if (data['mhEnableFakePacket'] != null) {
        _mhEnableFakePacket = data['mhEnableFakePacket'];
      }
      if (data['mhServerPorts'] != null) {
        final list = data['mhServerPorts'] as List;
        _mhServerPorts = list.map((e) => e as int).toList();
      }

      if (data['host'] != null) _host = data['host'];
      if (data['socksPort'] != null) _socksPort = data['socksPort'];
      if (data['httpPort'] != null) _httpPort = data['httpPort'];
      if (data['tunnelPort'] != null) _tunnelPort = data['tunnelPort'];
      if (data['proxyMode'] != null) _proxyMode = data['proxyMode'];
      if (data['enableSplitting'] != null) {
        _enableSplitting = data['enableSplitting'];
      }
      if (data['splitSize'] != null) _splitSize = data['splitSize'];
      if (data['splitDelayMs'] != null) _splitDelayMs = data['splitDelayMs'];
      if (data['fakeSni'] != null) _fakeSni = data['fakeSni'];
      if (data['cdnIp'] != null) _cdnIp = data['cdnIp'];
      if (data['cdnPort'] != null) _cdnPort = data['cdnPort'];
      if (data['enableFakePacket'] != null) {
        _enableFakePacket = data['enableFakePacket'];
      }
      if (data['fakeTtl'] != null) _fakeTtl = data['fakeTtl'];
      if (data['enableSniSpoofing'] != null) {
        _enableSniSpoofing = data['enableSniSpoofing'];
      }
      final savedExp = data['expirationTimestampMs'] as int?;
      if (savedExp != null && savedExp < DateTime.now().millisecondsSinceEpoch) {
        _proxyRequested = false;
        await _renewExpiredAllowance();
      }
      notifyListeners();
    } catch (e) {
      log("Error loading settings from disk: $e");
    }
  }

  void updateConfig({
    String? host,
    int? socksPort,
    int? httpPort,
    int? tunnelPort,
    String? proxyMode,
    bool? enableSplitting,
    int? splitSize,
    int? splitDelayMs,
    String? fakeSni,
    String? cdnIp,
    int? cdnPort,
    bool? enableFakePacket,
    int? fakeTtl,
    bool? enableSniSpoofing,
    String? trojanPassword,
    String? trojanServerSni,
    String? trojanTransport,
    String? trojanPath,
    String? trojanHost,
    String? psiphonRegion,
    String? psiphonProtocol,
    int? psiphonPort,
    String? warpKey,
    String? warpEndpointIp,
    int? warpPort,
  }) {
    if (host != null) _host = host;
    if (socksPort != null) _socksPort = socksPort;
    if (httpPort != null) _httpPort = httpPort;
    if (tunnelPort != null) _tunnelPort = tunnelPort;
    if (proxyMode != null) _proxyMode = proxyMode;
    if (enableSplitting != null) _enableSplitting = enableSplitting;
    if (splitSize != null) _splitSize = splitSize;
    if (splitDelayMs != null) _splitDelayMs = splitDelayMs;
    if (fakeSni != null) _fakeSni = fakeSni;
    if (cdnIp != null) _cdnIp = cdnIp;
    if (cdnPort != null) _cdnPort = cdnPort;
    if (enableFakePacket != null) _enableFakePacket = enableFakePacket;
    if (fakeTtl != null) _fakeTtl = fakeTtl;
    if (enableSniSpoofing != null) _enableSniSpoofing = enableSniSpoofing;

    notifyListeners();
    saveSettingsToDisk();
  }
}
