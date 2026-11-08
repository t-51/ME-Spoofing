import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_manager.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _hasLoadError = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadBanner());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoaded) {
      _retryTimer?.cancel();
      _retryTimer = null;
      unawaited(_loadBanner());
    }
  }

  Future<void> _loadBanner() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isLoading || _isLoaded) return;
    _isLoading = true;

    try {
      await AdManager.instance.initialize();
    } catch (error) {
      _isLoading = false;
      debugPrint('BannerAd initialization failed: $error');
      _scheduleRetry();
      return;
    }
    if (!AdManager.instance.isInitialized) {
      _isLoading = false;
      _scheduleRetry();
      return;
    }
    if (!mounted) {
      _isLoading = false;
      return;
    }

    final banner = BannerAd(
      adUnitId: AdManager.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isLoading = false;
          _retryAttempt = 0;
          _hasLoadError = false;
          _retryTimer?.cancel();
          _retryTimer = null;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _isLoading = false;
          _hasLoadError = true;
          debugPrint('BannerAd failed: $err');
          if (mounted) setState(() {});
          _scheduleRetry();
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  void _scheduleRetry() {
    if (!mounted || _retryTimer != null) return;
    final seconds = 5 * (1 << _retryAttempt.clamp(0, 4).toInt());
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds > 60 ? 60 : seconds), () {
      _retryTimer = null;
      unawaited(_loadBanner());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: AdSize.banner.height.toDouble(),
      child: _isLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : _hasLoadError
          ? const Text(
              "تبلیغ در حال بارگیری مجدد است",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            )
          : const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00F2FE),
                ),
              ),
            ),
    );
  }
}
