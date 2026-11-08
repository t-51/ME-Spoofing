import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../services/profile_generator.dart';
import '../theme_controller.dart';

void showConfigConverterDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ConfigConverterSheet(),
  );
}

class _ConfigConverterSheet extends StatefulWidget {
  const _ConfigConverterSheet();

  @override
  State<_ConfigConverterSheet> createState() => _ConfigConverterSheetState();
}

class _ConfigConverterSheetState extends State<_ConfigConverterSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  ParsedProxyConfig? _parsedConfig;
  String _statusMessage = "";
  int _selectedTargetTab = 0; // 0: Happ / Sing-box, 1: v2rayNG, 2: Standard URI

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _convertConfig() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _statusMessage = "لطفاً ابتدا لینک کانفیگ را وارد کنید.";
        _parsedConfig = null;
      });
      return;
    }

    final parsed = ProfileGenerator.parse(text);
    if (parsed.port > 0) {
      ProxyManager.instance.addServerPort(parsed.port);
    }

    setState(() {
      _parsedConfig = parsed;
      _statusMessage =
          "کانفیگ شناسایی شد! پورت ${parsed.port} روی 127.0.0.1 فعال و رول‌های روتینگ آماده شدند.";
    });
  }

  Future<void> _launchExternalApp(String scheme, String packageName, String appName) async {
    try {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final pkgUri = Uri.parse('android-app://$packageName');
      if (await canLaunchUrl(pkgUri)) {
        await launchUrl(pkgUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$appName باز نشد؛ لطفاً آن را به صورت دستی باز کنید.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAndOpenHapp() {
    if (_parsedConfig == null) _convertConfig();
    if (_parsedConfig == null) return;

    final jsonProfile = ProfileGenerator.generateSingBoxProfile(_parsedConfig!);
    Clipboard.setData(ClipboardData(text: jsonProfile));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "پروفایل Happ با روتینگ سرخود کپی شد! در برنامه Happ دکمه + و سپس New profile from clipboard را بزنید.",
        ),
        backgroundColor: Color(0xFF2855D9),
        duration: Duration(seconds: 4),
      ),
    );

    _launchExternalApp('happ://', 'com.github.happ.android', 'Happ');
  }

  void _copyAndOpenV2rayng() {
    if (_parsedConfig == null) _convertConfig();
    if (_parsedConfig == null) return;

    final jsonConfig = ProfileGenerator.generateV2rayCustomConfig(_parsedConfig!);
    Clipboard.setData(ClipboardData(text: jsonConfig));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "کانفیگ v2rayNG با روتینگ سرخود کپی شد! در v2rayNG دکمه + و سپس Import custom config from clipboard را بزنید.",
        ),
        backgroundColor: Color(0xFF2855D9),
        duration: Duration(seconds: 4),
      ),
    );

    _launchExternalApp('v2rayng://', 'com.v2ray.ang', 'v2rayNG');
  }

  void _copyStandardUri() {
    if (_parsedConfig == null) _convertConfig();
    if (_parsedConfig == null) return;

    final uri = ProfileGenerator.generateStandardUri(_parsedConfig!);
    Clipboard.setData(ClipboardData(text: uri));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("لینک استاندارد 127.0.0.1 در کلیپ‌بورد کپی شد."),
        backgroundColor: Color(0xFF2855D9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final loc = AppLocalizations.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance,
      builder: (context, isDark, _) {
        final sheetBg = isDark ? const Color(0xFF131820) : Colors.white;
        final fieldBg =
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);
        final borderColor =
            isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
        final titleColor = isDark ? Colors.white : const Color(0xFF111827);
        final subColor =
            isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
        const primaryBlue = Color(0xFF2855D9);

        String activeOutputPreview = "";
        if (_parsedConfig != null) {
          if (_selectedTargetTab == 0) {
            activeOutputPreview =
                ProfileGenerator.generateSingBoxProfile(_parsedConfig!);
          } else if (_selectedTargetTab == 1) {
            activeOutputPreview =
                ProfileGenerator.generateV2rayCustomConfig(_parsedConfig!);
          } else {
            activeOutputPreview =
                ProfileGenerator.generateStandardUri(_parsedConfig!);
          }
        }

        return Directionality(
          textDirection: loc.textDirection,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_fix_high_rounded,
                          color: primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "تولید خودکار پروفایل با روتینگ سرخود",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "ادغام آی‌پی‌ها و دامنه‌های بای‌پس درون کانفیگ برای Happ و v2rayNG",
                              style: TextStyle(fontSize: 11.5, color: subColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: subColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Input TextField ---
                  TextField(
                    controller: _inputCtrl,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: titleColor,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          "لینک کانفیگ اصلی (Trojan, Vless, Vmess) را اینجا قرار دهید...",
                      hintStyle: TextStyle(fontSize: 11.5, color: subColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: primaryBlue,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 19,
                          color: primaryBlue,
                        ),
                        tooltip: "جای‌گذاری از کلیپ‌بورد",
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _inputCtrl.text = data!.text!;
                            _convertConfig();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Convert / Generate Button ---
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text(
                      "پردازش و تزریق خودکار روتینگ",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: _convertConfig,
                  ),

                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_parsedConfig != null) ...[
                    const SizedBox(height: 16),
                    // Format Selector Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              index: 0,
                              label: "Happ / Sing-box",
                              subtitle: "توصیه‌شده",
                              primaryBlue: primaryBlue,
                              titleColor: titleColor,
                              subColor: subColor,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              index: 1,
                              label: "v2rayNG",
                              subtitle: "Custom JSON",
                              primaryBlue: primaryBlue,
                              titleColor: titleColor,
                              subColor: subColor,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              index: 2,
                              label: "لینک URL",
                              subtitle: "127.0.0.1",
                              primaryBlue: primaryBlue,
                              titleColor: titleColor,
                              subColor: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Action 1-Tap Buttons
                    if (_selectedTargetTab == 0) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: const Text(
                          "۱ کلیک: کپی و باز کردن Happ",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: _copyAndOpenHapp,
                      ),
                    ] else if (_selectedTargetTab == 1) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: const Text(
                          "۱ کلیک: کپی و باز کردن v2rayNG",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: _copyAndOpenV2rayng,
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text(
                          "کپی لینک استاندارد 127.0.0.1",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: _copyStandardUri,
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Preview of the Generated Config
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          activeOutputPreview,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required String subtitle,
    required Color primaryBlue,
    required Color titleColor,
    required Color subColor,
  }) {
    final isSelected = _selectedTargetTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTargetTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : titleColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? Colors.white.withOpacity(0.85) : subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
