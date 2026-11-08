import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../proxy/proxy_manager.dart';
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
  final TextEditingController _outputCtrl = TextEditingController();
  String _statusMessage = "";
  List<int> _detectedPorts = [];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    super.dispose();
  }

  void _convertConfig() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _statusMessage = "لطفاً ابتدا لینک کانفیگ را وارد کنید.";
        _outputCtrl.clear();
        _detectedPorts = [];
      });
      return;
    }

    final lines = text.split(RegExp(r'[\r\n]+'));
    final convertedLines = <String>[];
    final foundPorts = <int>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        if (trimmed.startsWith('vmess://')) {
          final b64 = trimmed.substring(8);
          String normalizedB64 = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
          final decoded = utf8.decode(base64Decode(normalizedB64));
          final Map<String, dynamic> json = jsonDecode(decoded);

          if (json['port'] != null) {
            final p = int.tryParse(json['port'].toString());
            if (p != null && !foundPorts.contains(p)) foundPorts.add(p);
          }

          json['add'] = '127.0.0.1';
          final newB64 = base64Encode(utf8.encode(jsonEncode(json)));
          convertedLines.add("vmess://$newB64");
        } else if (trimmed.startsWith('vless://') ||
            trimmed.startsWith('trojan://') ||
            trimmed.startsWith('ss://')) {
          final uri = Uri.parse(trimmed);
          if (uri.hasPort && !foundPorts.contains(uri.port)) {
            foundPorts.add(uri.port);
          }

          final newUri = uri.replace(host: '127.0.0.1');
          convertedLines.add(newUri.toString());
        } else {
          final regex = RegExp(r'(@|://)([^/:@?#]+):(\d+)');
          final match = regex.firstMatch(trimmed);
          if (match != null) {
            final port = int.tryParse(match.group(3) ?? "");
            if (port != null && !foundPorts.contains(port)) {
              foundPorts.add(port);
            }
            final replaced = trimmed.replaceFirst(
              "${match.group(1)}${match.group(2)}:",
              "${match.group(1)}127.0.0.1:",
            );
            convertedLines.add(replaced);
          } else {
            convertedLines.add(trimmed);
          }
        }
      } catch (e) {
        convertedLines.add(trimmed);
      }
    }

    for (final p in foundPorts) {
      ProxyManager.instance.addServerPort(p);
    }

    setState(() {
      _detectedPorts = foundPorts;
      _outputCtrl.text = convertedLines.join("\n");
      _statusMessage = foundPorts.isNotEmpty
          ? "تبدیل انجام شد! پورت‌های (${foundPorts.join(', ')}) خودکار به برنامه افزوده شدند."
          : "تبدیل با موفقیت انجام شد.";
    });
  }

  void _copyToClipboard() {
    if (_outputCtrl.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _outputCtrl.text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("کانفیگ تبدیل‌شده در کلیپ‌بورد کپی شد."),
          backgroundColor: Color(0xFF2855D9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance,
      builder: (context, isDark, _) {
        final sheetBg = isDark ? const Color(0xFF131820) : Colors.white;
        final fieldBg = isDark
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

        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
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
                            "تبدیل هوشمند کانفیگ برای Happ",
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "انتقال آدرس به 127.0.0.1 و ثبت خودکار پورت",
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

                // Input TextField
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
                        "لینک کانفیگ اصلی (Vless, Vmess, Trojan) را اینجا قرار دهید...",
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

                // Convert Button
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
                  icon: const Icon(Icons.sync_alt_rounded, size: 18),
                  label: const Text(
                    "تبدیل کانفیگ",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                  if (_detectedPorts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: _detectedPorts.map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            "Port $p",
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],

                if (_outputCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    "کانفیگ آماده استفاده در Happ / v2rayNG:",
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _outputCtrl,
                    maxLines: 3,
                    readOnly: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: titleColor,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: const BorderSide(color: primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      "کپی کانفیگ تبدیل‌شده",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _copyToClipboard,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
