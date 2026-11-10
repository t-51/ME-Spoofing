import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../services/profile_generator.dart';
import '../theme_controller.dart';

void showRoutingAssistantDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const RoutingAssistantDialog(),
  );
}

class RoutingAssistantDialog extends StatefulWidget {
  const RoutingAssistantDialog({super.key});

  @override
  State<RoutingAssistantDialog> createState() => _RoutingAssistantDialogState();
}

class _RoutingAssistantDialogState extends State<RoutingAssistantDialog> {
  final TextEditingController _configInputCtrl = TextEditingController();
  ParsedProxyConfig? _parsedConfig;
  String _statusMessage = "";
  int _selectedTutorialTab = 0; // 0: v2rayNG, 1: Happ, 2: Other clients

  @override
  void dispose() {
    _configInputCtrl.dispose();
    super.dispose();
  }

  void _onProcessConfig() {
    final text = _configInputCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedConfig = null;
        _statusMessage = "";
      });
      return;
    }

    final parsed = ProfileGenerator.parse(text);
    final hostDomain = ProfileGenerator.getPrimaryHostDomain(config: parsed);

    ProxyManager.instance.applyConfigDetails(
      port: parsed.port,
      hostDomain: hostDomain,
    );

    setState(() {
      _parsedConfig = parsed;
      _statusMessage =
          "✓ Port ${parsed.port} & Host ($hostDomain)";
    });
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2855D9),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openApp(
    BuildContext context,
    String scheme,
    String packageName,
    String appName,
  ) async {
    final loc = AppLocalizations.of(context);
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

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$appName: ${loc.openAppError}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = ThemeController.instance.isDarkMode(context);
    final loc = AppLocalizations.of(context);

    final cardBg = isDark ? const Color(0xFF131820) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final boxBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);
    const primaryBlue = Color(0xFF2855D9);

    final currentHostDomain =
        ProfileGenerator.getPrimaryHostDomain(config: _parsedConfig);
    final cleanIpsList = ProfileGenerator.getBypassIps();
    final cleanIpsCsv = cleanIpsList.join(', ');
    final allDirectRules =
        ProfileGenerator.getAllDirectRulesString(config: _parsedConfig);

    String convertedUri = "";
    if (_parsedConfig != null) {
      convertedUri = ProfileGenerator.generateStandardUri(_parsedConfig!);
    }

    return Directionality(
      textDirection: loc.textDirection,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Drag Handle ---
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

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
                      Icons.alt_route_rounded,
                      color: primaryBlue,
                      size: 22,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.routingAssistantDesc,
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // --- CRITICAL WARNING BANNER ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.routingNotice,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.criticalHostWarning,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- CONFIG LINK AUTO-DETECTION INPUT ---
              TextField(
                controller: _configInputCtrl,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: loc.pasteConfigHint,
                  hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                  filled: true,
                  fillColor: boxBg,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 18,
                          color: primaryBlue,
                        ),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            _configInputCtrl.text = data.text!.trim();
                            _onProcessConfig();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: primaryBlue,
                        ),
                        onPressed: _onProcessConfig,
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _onProcessConfig(),
              ),

              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${loc.autoConfiguredPortAndHost}: $_statusMessage",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // --- CONVERTED 127.0.0.1 URI (IF CONFIG PASTED) ---
              if (convertedUri.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(
                    loc.copyConvertedUri,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _copyToClipboard(
                    context,
                    convertedUri,
                    "${loc.copyConvertedUri} ${loc.copiedToClipboard}",
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // --- DIRECT ROUTING DATA BOXES ---
              // 1. Host Domain
              _buildDataBox(
                context: context,
                title: loc.hostDomain,
                value: currentHostDomain,
                copyButtonLabel: loc.copyHostDomain,
                icon: Icons.language_rounded,
                boxBg: boxBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryBlue: primaryBlue,
                onCopy: () => _copyToClipboard(
                  context,
                  currentHostDomain,
                  "${loc.copyHostDomain}: $currentHostDomain ${loc.copiedToClipboard}",
                ),
              ),
              const SizedBox(height: 10),

              // 2. Clean IPs
              _buildDataBox(
                context: context,
                title: loc.cleanIps,
                value: cleanIpsCsv,
                copyButtonLabel: loc.copyDirectIps,
                icon: Icons.security_rounded,
                boxBg: boxBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryBlue: primaryBlue,
                onCopy: () => _copyToClipboard(
                  context,
                  cleanIpsCsv,
                  "${loc.copyDirectIps} ${loc.copiedToClipboard}",
                ),
              ),
              const SizedBox(height: 10),

              // 3. All Direct Rules (domain:host + IPs)
              _buildDataBox(
                context: context,
                title: loc.allBypassRules,
                value: allDirectRules,
                copyButtonLabel: loc.copyAllBypassRules,
                icon: Icons.all_inclusive_rounded,
                boxBg: boxBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryBlue: primaryBlue,
                onCopy: () => _copyToClipboard(
                  context,
                  allDirectRules,
                  "${loc.copyAllBypassRules} ${loc.copiedToClipboard}",
                ),
              ),

              const SizedBox(height: 18),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 14),

              // --- STEP-BY-STEP APP TUTORIALS ---
              Text(
                "📱 ${loc.languageCode == 'fa' ? 'راهنمای گام‌به‌گام اتصال نرم‌افزارها' : 'Client Connection Guides'}:",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Tutorial App Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        index: 0,
                        title: "v2rayNG",
                        isSelected: _selectedTutorialTab == 0,
                        primaryBlue: primaryBlue,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () => setState(() => _selectedTutorialTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        index: 1,
                        title: "Happ",
                        isSelected: _selectedTutorialTab == 1,
                        primaryBlue: primaryBlue,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () => setState(() => _selectedTutorialTab = 1),
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        index: 2,
                        title: "SSH / Other",
                        isSelected: _selectedTutorialTab == 2,
                        primaryBlue: primaryBlue,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () => setState(() => _selectedTutorialTab = 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tutorial Body
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedTutorialTab == 0) ...[
                      Row(
                        children: [
                          const Icon(Icons.android_rounded,
                              color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            loc.tutorialV2rayngTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.tutorialV2rayngSteps,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.55,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(loc.openV2rayng),
                          onPressed: () => _openApp(
                            context,
                            'v2rayng://',
                            'com.v2ray.ang',
                            'v2rayNG',
                          ),
                        ),
                      ),
                    ] else if (_selectedTutorialTab == 1) ...[
                      Row(
                        children: [
                          const Icon(Icons.rocket_launch_rounded,
                              color: primaryBlue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            loc.tutorialHappTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.tutorialHappSteps,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.55,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(loc.openHapp),
                          onPressed: () => _openApp(
                            context,
                            'happ://',
                            'com.github.happ.android',
                            'Happ',
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            loc.tutorialOtherClientsTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.tutorialOtherClientsSteps,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.55,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "SSH / Tunnel: برای کلاینت‌های SSH (مانند Termius یا JuiceSSH)، هاست را روی 127.0.0.1 و پورت را روی 22 تنظیم کنید تا ترافیک مستقیماً از بستر تانل دی‌ان‌اس منتقل شود.",
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataBox({
    required BuildContext context,
    required String title,
    required String value,
    required String copyButtonLabel,
    required IconData icon,
    required Color boxBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primaryBlue),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text(copyButtonLabel, style: const TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: BorderSide(color: primaryBlue.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onCopy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required bool isSelected,
    required Color primaryBlue,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
