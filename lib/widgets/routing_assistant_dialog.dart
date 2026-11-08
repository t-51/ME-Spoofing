import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../theme_controller.dart';

class RoutingAssistantDialog extends StatelessWidget {
  const RoutingAssistantDialog({super.key});

  static const String appPackageName = 'com.kigaping.mespoofing';

  static final List<String> defaultDirectIps = [
    '188.114.98.0',
    '104.18.119.142',
    '104.25.165.92',
    '162.159.192.1',
    '104.16.132.229',
    '212.227.143.16',
  ];

  List<String> _getAllDirectIps() {
    final ips = <String>{...defaultDirectIps};
    final manager = ProxyManager.instance;
    if (manager.cfCleanIp.isNotEmpty) ips.add(manager.cfCleanIp);
    for (final host in manager.mhServerHosts) {
      if (RegExp(r'^[0-9.]+$').hasMatch(host)) {
        ips.add(host);
      }
    }
    return ips.toList();
  }

  String _generateJsonRule() {
    final ips = _getAllDirectIps().map((ip) => '$ip/32').toList();
    final manager = ProxyManager.instance;
    final domains = <String>{
      'domain:${manager.cfServerSni}',
      'domain:${manager.fakeSni}',
    }.toList();

    final rule = {
      'type': 'field',
      'outboundTag': 'direct',
      'ip': ips,
      'domain': domains,
    };
    return const JsonEncoder.withIndent('  ').convert(rule);
  }

  Future<void> _openApp(BuildContext context, String packageUri, String appName) async {
    try {
      final uri = Uri.parse(packageUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$appName روی دستگاه یافت نشد.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$appName روی دستگاه یافت نشد.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode(context);
    final loc = AppLocalizations.of(context);

    final cardBg = isDark ? const Color(0xFF131820) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final boxBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6);
    const primaryBlue = Color(0xFF2855D9);

    final allIps = _getAllDirectIps();
    final ipsCsv = allIps.join(', ');
    final jsonRule = _generateJsonRule();

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.alt_route_rounded, color: primaryBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.routingAssistant,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'برای کارکرد صحیح v2rayNG یا Happ در کنار این برنامه، باید IPهای تمیز یا پکیج برنامه به صورت Direct (مستقیم) تنظیم شوند تا ترافیک در لوپ VPN نیفتد.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // روش ۱: کپی IPها برای Custom Rules در v2rayNG
              Text(
                'روش ۱: کپی لیست IPها برای روتینگ مستقیم (Direct)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ipsCsv,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(loc.copyDirectIps),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: primaryBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: ipsCsv));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('لیست IPهای مستقیم در کلیپ‌بورد کپی شد!'),
                              backgroundColor: primaryBlue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // روش ۲: کپی رول کامل JSON
              Text(
                'روش ۲: روتینگ کامل JSON (مخصوص Sing-box و v2rayNG)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.code_rounded, size: 16),
                        label: Text(loc.copyJsonRule),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: primaryBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonRule));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('قانون روتینگ JSON در کلیپ‌بورد کپی شد!'),
                              backgroundColor: primaryBlue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // روش ۳: بای‌پس در پروکسی برنامه‌ها (ساده‌ترین روش)
              Text(
                'روش ۳: مستثنی کردن در «پروکسی بر اساس برنامه»',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'در تنظیمات v2rayNG > پروکسی بر اساس برنامه (Per-app proxy)، تیک ME Spoofing را بردارید تا خارج از VPN کار کند.',
                style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: Text(loc.copyPackageName),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: appPackageName));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('نام پکیج com.kigaping.mespoofing کپی شد!'),
                        backgroundColor: primaryBlue,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 12),

              // دکمه‌های باز کردن خودکار برنامه‌ها
              Text(
                'باز کردن مستقیم کلاینت‌ها:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(loc.openV2rayng),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openApp(
                        context,
                        'package:com.v2ray.ang',
                        'v2rayNG',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(loc.openHapp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openApp(
                        context,
                        'package:com.happ.app',
                        'Happ',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.close),
        ),
      ],
    );
  }
}

void showRoutingAssistantDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const RoutingAssistantDialog(),
  );
}

