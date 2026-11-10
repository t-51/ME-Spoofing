import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../theme_controller.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ProxyManager _manager = ProxyManager.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilterId = "all";
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(String log) {
    if (_searchQuery.isNotEmpty &&
        !log.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }

    switch (_selectedFilterId) {
      case "dns":
        return log.contains("[DNS Tunnel]") ||
            log.contains("DNS") ||
            log.contains("Resolver") ||
            log.contains("VayDNS") ||
            log.contains("DNSTT");
      case "fake":
        return log.contains("Decoy") || log.contains("Injected");
      case "fragment":
        return log.contains("Fragmented") || log.contains("Split");
      case "connections":
        return log.contains("Listening") ||
            log.contains("listening") ||
            log.contains("Connected") ||
            log.contains("Client connected") ||
            log.contains("session ended") ||
            log.contains("Session #") ||
            log.contains("🚀");
      case "errors":
        return log.contains("failed") ||
            log.contains("Error") ||
            log.contains("error") ||
            log.contains("❌") ||
            log.contains("⚠️") ||
            log.contains("timeout") ||
            log.contains("NXDOMAIN") ||
            log.contains("SERVFAIL");
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode(context);
    final loc = AppLocalizations.of(context);

    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final headerColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2328);
    final secondaryTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);
    final chipBgColor = isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2);
    final defaultLogTextColor = isDark ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);

    final filters = [
      {'id': 'all', 'label': loc.all},
      {'id': 'connections', 'label': loc.connections},
      {'id': 'errors', 'label': loc.errors},
      {'id': 'fake', 'label': loc.fakeInjection},
      {'id': 'fragment', 'label': loc.fragment},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: primaryTextColor,
        elevation: 0,
        title: Text(
          loc.logsTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              color: Color(0xFF2855D9),
              size: 20,
            ),
            tooltip: loc.copyLogs,
            onPressed: () {
              final allLogs = _manager.logs.where(_matchesFilter).join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.logsCopied),
                  backgroundColor: const Color(0xFF2855D9),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: secondaryTextColor,
              size: 22,
            ),
            tooltip: loc.clearLogs,
            onPressed: () {
              _manager.clearLogs();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Search Box
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: primaryTextColor,
                          ),
                          decoration: InputDecoration(
                            hintText: loc.searchLogs,
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: secondaryTextColor.withValues(alpha: 0.7),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((item) {
                      final filterId = item['id']!;
                      final filterLabel = item['label']!;
                      final isSelected = _selectedFilterId == filterId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(
                            filterLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : secondaryTextColor,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2855D9),
                          backgroundColor: chipBgColor,
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF2855D9)
                                : borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilterId = filterId);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Log List
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _manager.logNotifier,
              builder: (context, allLogs, _) {
                final filteredLogs = allLogs.where(_matchesFilter).toList();

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Text(
                      loc.noLogs,
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final logLine = filteredLogs[index];
                    Color textColor = defaultLogTextColor;

                    if (logLine.contains("failed") ||
                        logLine.contains("Error") ||
                        logLine.contains("❌") ||
                        logLine.contains("⚠️") ||
                        logLine.contains("NXDOMAIN") ||
                        logLine.contains("SERVFAIL") ||
                        logLine.contains("timeout")) {
                      textColor = const Color(0xFFD9383A);
                    } else if (logLine.contains("listening") ||
                        logLine.contains("🚀") ||
                        logLine.contains("Listening") ||
                        logLine.contains("Handshake successful") ||
                        logLine.contains("Client connected")) {
                      textColor = const Color(0xFF10B981);
                    } else if (logLine.contains("[DNS Tunnel]")) {
                      textColor = const Color(0xFF0EA5E9);
                    } else if (logLine.contains("Fragmented") ||
                        logLine.contains("Decoy") ||
                        logLine.contains("SNI")) {
                      textColor = const Color(0xFF2855D9);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Text(
                        logLine,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
