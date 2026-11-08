import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  static bool get useTestAds => kDebugMode;

  static const String prodBannerId = 'ca-app-pub-5362186330936185/6123963673';
  static const String prodInterstitialId =
      'ca-app-pub-5362186330936185/9101867842';
  static const String prodRewardedId = 'ca-app-pub-5362186330936185/4795579293';

  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  String get bannerAdUnitId => useTestAds ? testBannerId : prodBannerId;
  String get interstitialAdUnitId =>
      useTestAds ? testInterstitialId : prodInterstitialId;
  String get rewardedAdUnitId => useTestAds ? testRewardedId : prodRewardedId;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;
  bool _isInitialized = false;
  bool _hasShownLaunchAd = false;
  Future<void>? _initialization;
  Timer? _initializationRetryTimer;
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;
  int _interstitialRetryAttempt = 0;
  int _rewardedRetryAttempt = 0;
  final List<VoidCallback> _interstitialLoadCallbacks = [];

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() {
    if (!_isMobile || _isInitialized) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: ['D4D0B954615747F772A671B289BC1903'],
          ),
        );
      }
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _initializationRetryTimer?.cancel();
      loadInterstitialAd();
      loadRewardedAd();
    } catch (error) {
      debugPrint('AdMob init error: $error');
      _initialization = null;
      _scheduleInitializationRetry();
    }
  }

  void _scheduleInitializationRetry() {
    _initializationRetryTimer ??= Timer(const Duration(seconds: 15), () {
      _initializationRetryTimer = null;
      unawaited(initialize());
    });
  }

  Duration _retryDelay(int attempt) {
    final seconds = 5 * (1 << attempt.clamp(0, 4).toInt());
    return Duration(seconds: seconds > 60 ? 60 : seconds);
  }

  void retryFailedAds() {
    if (!_isMobile) return;
    if (!_isInitialized) {
      unawaited(initialize());
      return;
    }
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
    loadInterstitialAd();
    loadRewardedAd();
  }

  void loadInterstitialAd({VoidCallback? onLoaded}) {
    if (!_isMobile) return;
    if (onLoaded != null) _interstitialLoadCallbacks.add(onLoaded);
    if (_interstitialAd != null) {
      _notifyInterstitialLoaded();
      return;
    }
    if (!_isInitialized) {
      unawaited(initialize());
      return;
    }
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialRetryAttempt = 0;
          _interstitialRetryTimer?.cancel();
          _interstitialRetryTimer = null;
          _notifyInterstitialLoaded();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
          _scheduleInterstitialRetry();
        },
      ),
    );
  }

  void _notifyInterstitialLoaded() {
    final callbacks = List<VoidCallback>.of(_interstitialLoadCallbacks);
    _interstitialLoadCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void _scheduleInterstitialRetry() {
    _interstitialRetryTimer ??= Timer(
      _retryDelay(_interstitialRetryAttempt++),
      () {
        _interstitialRetryTimer = null;
        loadInterstitialAd();
      },
    );
  }

  void showAppLaunchInterstitial({bool Function()? canShow}) {
    if (_hasShownLaunchAd) return;
    if (_interstitialAd != null) {
      if (canShow != null && !canShow()) return;
      _hasShownLaunchAd = true;
      showInterstitialAd();
      return;
    }
    loadInterstitialAd(
      onLoaded: () {
        if (!_hasShownLaunchAd && (canShow == null || canShow())) {
          _hasShownLaunchAd = true;
          showInterstitialAd();
        }
      },
    );
  }

  void showInterstitialAd({VoidCallback? onDismissed}) {
    final ad = _interstitialAd;
    if (ad == null) {
      loadInterstitialAd();
      onDismissed?.call();
      return;
    }

    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        loadInterstitialAd();
        onDismissed?.call();
      },
    );
    ad.show();
  }

  void loadRewardedAd() {
    if (!_isMobile) return;
    if (_rewardedAd != null || _isRewardedLoading) return;
    if (!_isInitialized) {
      unawaited(initialize());
      return;
    }
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedRetryAttempt = 0;
          _rewardedRetryTimer?.cancel();
          _rewardedRetryTimer = null;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed to load: $error');
          _rewardedAd = null;
          _isRewardedLoading = false;
          _scheduleRewardedRetry();
        },
      ),
    );
  }

  void _scheduleRewardedRetry() {
    _rewardedRetryTimer ??= Timer(_retryDelay(_rewardedRetryAttempt++), () {
      _rewardedRetryTimer = null;
      loadRewardedAd();
    });
  }

  void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    VoidCallback? onFailed,
    VoidCallback? onDismissed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      onFailed?.call();
      return;
    }

    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: $error');
        ad.dispose();
        loadRewardedAd();
        onFailed?.call();
      },
    );
    ad.show(onUserEarnedReward: onUserEarnedReward);
  }
}
