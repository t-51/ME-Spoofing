import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme_controller.dart';

const _githubRepositoryUrl = 'https://github.com/t-51/ME-Spoofing';

void showCommunityDialog(BuildContext context, {VoidCallback? onDismissed}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance,
      builder: (context, isDark, _) {
        final bgColor = isDark ? const Color(0xFF131820) : Colors.white;
        final cardBg = isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF7F8FA);
        final borderColor = isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFE5E7EB);
        final titleColor = isDark ? Colors.white : const Color(0xFF111827);
        final subColor = isDark
            ? const Color(0xFF8B949E)
            : const Color(0xFF6B7280);
        const primaryBlue = Color(0xFF2855D9);

        return AlertDialog(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "اخبار، آموزش و پشتیبانی",
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "برای اطلاع از آخرین تغییرات، آموزش‌ها و اخبار ME Spoofing به کانال تلگرام و گیت‌هاب ما بپیوندید:",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Telegram Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: primaryBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "کانال تلگرام",
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "@kigaping_fa",
                              style: TextStyle(
                                color: primaryBlue,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: subColor,
                        ),
                        tooltip: "کپی آیدی تلگرام",
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text: "https://t.me/kigaping_fa",
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "لینک کانال تلگرام کپی شد: https://t.me/kigaping_fa",
                              ),
                              backgroundColor: primaryBlue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // GitHub Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.code_rounded,
                          color: Color(0xFF22C55E),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "گیت‌هاب پروژه",
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "github.com/t-51/ME-Spoofing",
                              style: TextStyle(
                                color: subColor,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: subColor,
                        ),
                        tooltip: "کپی لینک گیت‌هاب",
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: _githubRepositoryUrl),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "لینک مخزن گیت‌هاب کپی شد: $_githubRepositoryUrl",
                              ),
                              backgroundColor: primaryBlue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "اگر برنامه برایتان مفید بوده، با دادن Star در گیت‌هاب از پروژه حمایت کنید ⭐",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: subColor, height: 1.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: titleColor,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 17,
                    color: primaryBlue,
                  ),
                  label: const Text(
                    "ورود به کانال تلگرام",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _openCommunityLink(
                    context,
                    Uri.parse('https://t.me/kigaping_fa'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text(
                    "حمایت با Star در GitHub",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _openCommunityLink(
                    context,
                    Uri.parse(_githubRepositoryUrl),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "بستن",
                style: TextStyle(color: subColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ),
  ).then((_) => onDismissed?.call());
}

Future<void> _openCommunityLink(BuildContext context, Uri uri) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("بازکردن لینک ممکن نشد.")));
    }
  } on PlatformException catch (error) {
    debugPrint('Failed to open community link $uri:$error');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("بازکردن لینک ممکن نشد.")));
    }
  }
}
