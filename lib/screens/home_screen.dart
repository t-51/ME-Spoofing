import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../services/ad_manager.dart';
import '../services/update_service.dart';
import '../theme_controller.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/community_dialog.dart';
import '../widgets/routing_assistant_dialog.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ProxyManager _manager = ProxyManager.instance;

  bool _adsInitialized = false;
  bool _communityDialogScheduled = false;
  bool _hasEnteredBackground = false;

  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    WidgetsBinding.instance.addObserver(this);
    ThemeController.instance.applySystemUI();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _initializeAds();
        _scheduleCommunityDialog(onDismissed: _scheduleLaunchAd);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _hasEnteredBackground = true;
      _communityDialogScheduled = false;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    ThemeController.instance.applySystemUI();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (!_adsInitialized) {
      _adsInitialized = true;
      unawaited(AdManager.instance.initialize());
    } else {
      AdManager.instance.retryFailedAds();
    }
    if (_hasEnteredBackground) {
      _hasEnteredBackground = false;
      _scheduleCommunityDialog(onDismissed: _scheduleLaunchAd);
    }
  }

  void _scheduleCommunityDialog({VoidCallback? onDismissed}) {
    if (_communityDialogScheduled) return;
    if (!_manager.shouldShowCommunityDialogOnLaunch) {
      onDismissed?.call();
      return;
    }
    _communityDialogScheduled = true;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _communityDialogScheduled = false;
        return;
      }
      _manager.markCommunityDialogShown();
      showCommunityDialog(context, onDismissed: onDismissed);
    });
  }

  void _initializeAds() {
    if (!_adsInitialized) {
      _adsInitialized = true;
      unawaited(AdManager.instance.initialize());
    }
  }

  void _scheduleLaunchAd() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        AdManager.instance.showAppLaunchInterstitial(
          canShow: () =>
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed,
        );
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatSpeed(double speedKb) {
    if (speedKb >= 1024.0) {
      return "${(speedKb / 1024.0).toStringAsFixed(2)} MB/s";
    }
    return "${speedKb.toStringAsFixed(1)} KB/s";
  }

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

  void _watchRewardedAd() {
    final isDark = ThemeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131820) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF2855D9)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "در حال آماده‌سازی و پخش ویدیوی تبلیغاتی...",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    AdManager.instance.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        _manager.addRewardTime();
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF131820) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFF2855D9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "پاداش دریافت شد!",
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                "۴ ساعت به زمان اعتبار اتصال شما افزوده شد!",
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF8B949E)
                      : const Color(0xFF4B5563),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2855D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("عالی"),
                ),
              ],
            ),
          );
        }
      },
      onFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "ویدیو تبلیغاتی هنوز در دسترس نیست یا اینترنت متصل نیست. لطفاً مجدداً امتحان کنید.",
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      },
    );
  }



  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF131820) : Colors.white,
        padding: const EdgeInsets.all(9),
        minimumSize: const Size(38, 38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      icon: Icon(
        icon,
        color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937),
        size: 19,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode(context);
        final bgColor = isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF7F8FA);
        final cardColor = isDark ? const Color(0xFF131820) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFE5E7EB);
        final titleColor = isDark ? Colors.white : const Color(0xFF111827);
        final subColor = isDark
            ? const Color(0xFF8B949E)
            : const Color(0xFF6B7280);

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: [
                      _buildHeaderIconButton(
                        icon: Icons.terminal_rounded,
                        tooltip: loc.logs,
                        isDark: isDark,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LogsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: Icons.alt_route_rounded,
                        tooltip: loc.routingAssistant,
                        isDark: isDark,
                        onPressed: () => showRoutingAssistantDialog(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              loc.appName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.appSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: loc.checkUpdate,
                        isDark: isDark,
                        onPressed: () => UpdateService.instance.checkAndShowUpdateDialog(context),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: loc.settings,
                        isDark: isDark,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // --- SCROLLABLE MAIN CONTENT ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // --- TOP BANNER AD ---
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.0),
                          child: AdBannerWidget(),
                        ),
                        const SizedBox(height: 10),

                        // --- MINIMAL RADAR POWER BUTTON ---
                        ListenableBuilder(
                          listenable: _manager,
                          builder: (context, _) {
                            final isRunning = _manager.isRunning;
                            return Column(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (isRunning) {
                                      await _manager.stop();
                                      AdManager.instance.showInterstitialAd();
                                    } else {
                                      try {
                                        await _manager.start();
                                        AdManager.instance.retryFailedAds();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "خطا در راه‌اندازی: $e",
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: AnimatedBuilder(
                                      animation: _ringController,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: _RadarPowerPainter(
                                            isRunning: isRunning,
                                            progress: _ringController.value,
                                            isDark: isDark,
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: Center(
                                        child: Container(
                                          width: 82,
                                          height: 82,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cardColor,
                                            border: isDark
                                                ? Border.all(color: borderColor)
                                                : null,
                                            boxShadow: [
                                              BoxShadow(
                                                color: isRunning
                                                    ? const Color(
                                                        0xFF2855D9,
                                                      ).withOpacity(0.22)
                                                    : Colors.black.withOpacity(
                                                        isDark ? 0.3 : 0.06,
                                                      ),
                                                blurRadius: 24,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.power_settings_new_rounded,
                                            size: 32,
                                            color: isRunning
                                                ? titleColor
                                                : subColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isRunning ? loc.active : loc.disconnected,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                    color: isRunning ? titleColor : subColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRunning
                                      ? (_manager.transportMode ==
                                              TransportMode.dnsTunnel
                                          ? "${_manager.dnsProtocolDisplay} (127.0.0.1:${_manager.dnsLocalPort})"
                                          : loc.listeningProtecting)
                                      : loc.tapToStart,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // --- BOTTOM BANNER AD ---
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.0),
                          child: AdBannerWidget(),
                        ),
                        const SizedBox(height: 10),

                        // --- CONNECTION TIMER CARD ---
                        ListenableBuilder(
                          listenable: _manager,
                          builder: (context, _) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: isDark
                                    ? Border.all(color: borderColor)
                                    : null,
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            0.035,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    loc.timeRemaining,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: subColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _manager.remainingTimeFormatted,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 1.5,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    loc.timeNotice,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: subColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2855D9),
                                      foregroundColor: Colors.white,
                                      elevation: isDark ? 0 : 4,
                                      shadowColor: const Color(
                                        0xFF2855D9,
                                      ).withOpacity(0.4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 26,
                                        vertical: 11,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: _watchRewardedAd,
                                    child: Text(
                                      loc.getReward,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // --- NETWORK STATS BAR ---
                        ListenableBuilder(
                          listenable: _manager,
                          builder: (context, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: isDark
                                    ? Border.all(color: borderColor)
                                    : null,
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatColumn(
                                        label: loc.download,
                                        value: _formatSpeed(
                                          _manager.downloadSpeed,
                                        ),
                                        sub: _formatBytes(
                                          _manager.totalBytesDownloaded,
                                        ),
                                        titleColor: titleColor,
                                        subColor: subColor,
                                      ),
                                    ),
                                    VerticalDivider(
                                      color: borderColor,
                                      thickness: 1,
                                      width: 1,
                                    ),
                                    Expanded(
                                      child: _buildStatColumn(
                                        label: loc.upload,
                                        value: _formatSpeed(
                                          _manager.uploadSpeed,
                                        ),
                                        sub: _formatBytes(
                                          _manager.totalBytesUploaded,
                                        ),
                                        titleColor: titleColor,
                                        subColor: subColor,
                                      ),
                                    ),
                                    VerticalDivider(
                                      color: borderColor,
                                      thickness: 1,
                                      width: 1,
                                    ),
                                    Expanded(
                                      child: _buildStatColumn(
                                        label: loc.connections,
                                        value: "${_manager.activeConnections}",
                                        sub: _manager.isRunning
                                            ? loc.connActive
                                            : loc.connReady,
                                        titleColor: titleColor,
                                        subColor: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // --- LIVE DNS TUNNEL STATUS CARD ---
                        ListenableBuilder(
                          listenable: _manager,
                          builder: (context, _) {
                            if (!_manager.isRunning ||
                                _manager.transportMode !=
                                    TransportMode.dnsTunnel) {
                              return const SizedBox.shrink();
                            }
                            final isConnected =
                                _manager.dnsTunnelLatencyMs != null;
                            final activeColor = isConnected
                                ? const Color(0xFF10B981)
                                : Colors.amber;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: activeColor.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: activeColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.dns_rounded,
                                          color: activeColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _manager.dnsProtocolDisplay,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: titleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Resolver: ${_manager.dnsTunnelActiveResolver ?? _manager.dnsResolver}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: subColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: activeColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flash_on_rounded,
                                              size: 12,
                                              color: activeColor,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              isConnected
                                                  ? "${_manager.dnsTunnelLatencyMs} ms"
                                                  : "Probing...",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: activeColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "127.0.0.1:${_manager.dnsLocalPort}",
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: subColor,
                                        ),
                                      ),
                                      Text(
                                        "Queries: 📤 ${_manager.dnsTunnelQueriesSent}  •  📥 ${_manager.dnsTunnelQueriesReceived}",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // --- ROUTING ASSISTANT QUICK CARD ---
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => showRoutingAssistantDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF21262D)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2855D9).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.alt_route_rounded,
                                    color: Color(0xFF2855D9),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.routingAssistant,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        loc.routingAssistantDesc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF2855D9),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required String sub,
    required Color titleColor,
    required Color subColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: subColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10, color: subColor)),
      ],
    );
  }
}

class _RadarPowerPainter extends CustomPainter {
  final bool isRunning;
  final double progress;
  final bool isDark;

  _RadarPowerPainter({
    required this.isRunning,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 8;

    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, outerRadius, trackPaint);

    if (isRunning) {
      final startAngle = (progress * 2 * math.pi) - (math.pi / 4);
      const sweepAngle = math.pi * 1.15;

      final glowPaint = Paint()
        ..color = const Color(0xFF2855D9).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      final arcPaint = Paint()
        ..color = const Color(0xFF2855D9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    final dashBaseColor = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF9CA3AF);

    _drawDashedCircle(
      canvas,
      center,
      outerRadius - 16,
      dashCount: 44,
      color: dashBaseColor.withOpacity(0.55),
    );
    _drawDashedCircle(
      canvas,
      center,
      outerRadius - 30,
      dashCount: 36,
      color: dashBaseColor.withOpacity(0.4),
    );
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius, {
    required int dashCount,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final step = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPowerPainter oldDelegate) {
    return oldDelegate.isRunning != isRunning ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
