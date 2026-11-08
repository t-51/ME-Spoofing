import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../proxy/proxy_manager.dart';
import '../proxy/dns_tunnel.dart';
import '../services/locale_controller.dart';
import '../theme_controller.dart';
import '../widgets/community_dialog.dart';
import '../widgets/routing_assistant_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProxyManager _manager = ProxyManager.instance;
  final _formKey = GlobalKey<FormState>();

  // Active Transport Mode
  late TransportMode _selectedTransportMode;

  // --- Mode 1: Direct SNI Controllers ---
  late TextEditingController _serverHostController;
  late TextEditingController _daemonPortController;
  late TextEditingController _serverPortsController;
  late TextEditingController _fallbackLocalPortController;
  late TextEditingController _fragmentDelayController;
  late String _selectedFakeSni;
  late TextEditingController _customSniController;
  late bool _enableFakePacket;

  // --- Port Manager Input ---
  final TextEditingController _newPortController = TextEditingController();

  // --- Mode 2: Cloudflare Clean IP Controllers ---
  late TextEditingController _cfCleanIpController;
  late TextEditingController _cfCleanPortController;
  late TextEditingController _cfServerSniController;
  late TextEditingController _cfFragmentDelayController;
  late String _selectedCfCleanPreset;

  // --- Mode 3: DNS Tunnel Controllers ---
  late String _selectedDnsProtocol;
  late TextEditingController _dnsSubdomainController;
  late TextEditingController _dnsPublicKeyController;
  late String _selectedDnsResolver;
  late TextEditingController _customDnsResolverController;
  late String _dnsResolverType;
  late TextEditingController _dnsLocalPortController;

  final List<String> _fakeSniPresets = [
    "speedtest.net",
    "auth.vercel.com",
    "dl.google.com",
    "shaparak.ir",
    "sanjesh.org",
    "www.wikipedia.org",
    "Custom ...",
  ];

  final List<String> _cfCleanPresets = [
    "188.114.98.0",
    "104.18.119.142",
    "104.25.165.92",
    "162.159.192.1",
    "104.16.132.229",
    "Custom ...",
  ];

  @override
  void initState() {
    super.initState();
    _selectedTransportMode = _manager.transportMode;

    // Mode 1
    _serverHostController = TextEditingController(
      text: _manager.mhServerHostsString,
    );
    _daemonPortController = TextEditingController(
      text: _manager.mhDaemonPort.toString(),
    );
    _serverPortsController = TextEditingController(
      text: _manager.mhServerPortsString,
    );
    _fallbackLocalPortController = TextEditingController(
      text: _manager.mhLocalPort.toString(),
    );
    _fragmentDelayController = TextEditingController(
      text: _manager.mhFragmentDelayMs.toString(),
    );
    _enableFakePacket = _manager.mhEnableFakePacket;

    if (_fakeSniPresets.contains(_manager.mhFakeSni) &&
        _manager.mhFakeSni != "Custom ...") {
      _selectedFakeSni = _manager.mhFakeSni;
      _customSniController = TextEditingController(text: "");
    } else {
      _selectedFakeSni = "Custom ...";
      _customSniController = TextEditingController(text: _manager.mhFakeSni);
    }

    // Mode 2
    _cfCleanIpController = TextEditingController(text: _manager.cfCleanIp);
    _cfCleanPortController = TextEditingController(
      text: _manager.cfCleanPort.toString(),
    );
    _cfServerSniController = TextEditingController(
      text: _manager.cfServerSni,
    );
    _cfFragmentDelayController = TextEditingController(
      text: _manager.cfFragmentDelayMs.toString(),
    );
    if (_cfCleanPresets.contains(_manager.cfCleanIp) &&
        _manager.cfCleanIp != "Custom ...") {
      _selectedCfCleanPreset = _manager.cfCleanIp;
    } else {
      _selectedCfCleanPreset = "Custom ...";
    }

    // Mode 3
    _selectedDnsProtocol = _manager.dnsProtocol;
    _dnsSubdomainController = TextEditingController(
      text: _manager.dnsSubdomain,
    );
    _dnsPublicKeyController = TextEditingController(
      text: _manager.dnsPublicKey,
    );
    _dnsResolverType = _manager.dnsResolverType;
    _dnsLocalPortController = TextEditingController(
      text: _manager.dnsLocalPort.toString(),
    );

    final resolverPresets =
        DnsResolverOption.presets.map((e) => e.endpoint).toList();
    if (resolverPresets.contains(_manager.dnsResolver)) {
      _selectedDnsResolver = _manager.dnsResolver;
      _customDnsResolverController = TextEditingController(text: "");
    } else {
      _selectedDnsResolver = "Custom ...";
      _customDnsResolverController = TextEditingController(
        text: _manager.dnsResolver,
      );
    }
  }

  @override
  void dispose() {
    _serverHostController.dispose();
    _daemonPortController.dispose();
    _serverPortsController.dispose();
    _fallbackLocalPortController.dispose();
    _fragmentDelayController.dispose();
    _customSniController.dispose();
    _newPortController.dispose();

    _cfCleanIpController.dispose();
    _cfCleanPortController.dispose();
    _cfServerSniController.dispose();
    _cfFragmentDelayController.dispose();

    _dnsSubdomainController.dispose();
    _dnsPublicKeyController.dispose();
    _customDnsResolverController.dispose();
    _dnsLocalPortController.dispose();

    super.dispose();
  }

  List<String> _parsedPortChips() {
    return _serverPortsController.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _addNewPort() {
    final text = _newPortController.text.trim();
    final port = int.tryParse(text);
    if (port != null && port > 0 && port <= 65535) {
      final ports = _parsedPortChips();
      if (!ports.contains(port.toString())) {
        ports.add(port.toString());
        _serverPortsController.text = ports.join(', ');
        _newPortController.clear();
        setState(() {});
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("شماره پورت باید عددی بین ۱ تا ۶۵۵۳۵ باشد."),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removePort(String portStr) {
    final ports = _parsedPortChips();
    ports.remove(portStr);
    _serverPortsController.text = ports.join(', ');
    setState(() {});
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      // Parse ports dynamically without forcing any hardcoded port
      final parts = _serverPortsController.text.split(RegExp(r'[,;\s]+'));
      final ports = <int>[];
      for (final p in parts) {
        final parsed = int.tryParse(p.trim());
        if (parsed != null && parsed > 0 && parsed <= 65535) {
          if (!ports.contains(parsed)) ports.add(parsed);
        }
      }

      // Save Transport Mode
      _manager.setTransportMode(_selectedTransportMode);

      // Save Mode 1 Settings
      final daemonPort = int.tryParse(_daemonPortController.text) ?? 15443;
      final localPort =
          int.tryParse(_fallbackLocalPortController.text) ?? 40443;
      final fragmentDelay = int.tryParse(_fragmentDelayController.text) ?? 3;

      String finalFakeSni = _selectedFakeSni;
      if (_selectedFakeSni == "Custom ...") {
        finalFakeSni = _customSniController.text.trim();
      }

      try {
        _manager.updateMhpanelConfig(
          serverHosts: _serverHostController.text
              .split(',')
              .map((host) => host.trim())
              .where((host) => host.isNotEmpty)
              .toList(),
          daemonPort: daemonPort,
          localPort: localPort,
          fakeSni: finalFakeSni,
          fragmentDelayMs: fragmentDelay,
          enableFakePacket: _enableFakePacket,
          serverPorts: ports,
        );

        // Save Mode 2 Settings
        String finalCfCleanIp = _selectedCfCleanPreset == "Custom ..."
            ? _cfCleanIpController.text.trim()
            : _selectedCfCleanPreset;
        if (finalCfCleanIp.isEmpty) finalCfCleanIp = "104.18.119.142";

        _manager.updateCloudflareCleanConfig(
          cleanIp: finalCfCleanIp,
          cleanPort: int.tryParse(_cfCleanPortController.text) ?? 443,
          serverSni: _cfServerSniController.text.trim().isEmpty
              ? "ws.kigaping.com"
              : _cfServerSniController.text.trim(),
          fragmentDelayMs:
              int.tryParse(_cfFragmentDelayController.text) ?? 5,
        );

        // Save Mode 3 Settings
        String finalResolver = _selectedDnsResolver == "Custom ..."
            ? _customDnsResolverController.text.trim()
            : _selectedDnsResolver;
        if (finalResolver.isEmpty) {
          finalResolver = "https://cloudflare-dns.com/dns-query";
        }

        _manager.updateDnsTunnelConfig(
          protocol: _selectedDnsProtocol,
          subdomain: _dnsSubdomainController.text.trim().isEmpty
              ? "v.vpn.kigaping.com"
              : _dnsSubdomainController.text.trim(),
          publicKey: _dnsPublicKeyController.text.trim(),
          resolver: finalResolver,
          resolverType: _dnsResolverType,
          localPort: int.tryParse(_dnsLocalPortController.text) ?? 53001,
        );

        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _manager.isRunning
                  ? loc.saveRestartNotice
                  : loc.savedSuccess,
            ),
            backgroundColor: const Color(0xFF2855D9),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildFieldLabel(String text, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: TextStyle(
            color: labelColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(
    String text,
    Color bg,
    Color border,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
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
        final currentThemeMode = ThemeController.instance.themeMode;
        final bgColor =
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);
        final surfaceColor =
            isDark ? const Color(0xFF131820) : Colors.white;
        final borderColor =
            isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
        final chipBgColor =
            isDark ? const Color(0xFF161B22) : const Color(0xFFF3F4F6);
        final textPrimary =
            isDark ? Colors.white : const Color(0xFF111827);
        final textSecondary =
            isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
        const primaryBlue = Color(0xFF2855D9);

        final portChips = _parsedPortChips();

        return Directionality(
          textDirection: loc.textDirection,
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: textPrimary),
              title: Text(
                loc.settings,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.campaign_outlined, color: textSecondary),
                  tooltip: loc.support,
                  onPressed: () => showCommunityDialog(context),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // --- زبان و ظاهر نرم‌افزار ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        // تم ظاهری
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_outlined,
                                  color: primaryBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.appearance,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: _buildThemeSegment(
                                currentMode: currentThemeMode,
                                chipBgColor: chipBgColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                loc: loc,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 12),
                        // زبان برنامه
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  color: primaryBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.language,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: _buildLanguageDropdown(
                                surfaceColor: surfaceColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- ROUTING ASSISTANT BANNER ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            color: primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.routingAssistant,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.routingAssistantDesc,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => showRoutingAssistantDialog(context),
                          child: Text(
                            loc.routingAssistant,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- TRANSPORT MODE SELECTOR ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      loc.transportMode,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.transportModeDesc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildModeSelector(
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryBlue: primaryBlue,
                    loc: loc,
                  ),

                  const SizedBox(height: 20),

                  // --- MODE SPECIFIC CONFIGURATION ---
                  if (_selectedTransportMode == TransportMode.directSni) ...[
                    _buildMode1Section(
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      chipBgColor: chipBgColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryBlue: primaryBlue,
                      loc: loc,
                    ),
                  ] else if (_selectedTransportMode ==
                      TransportMode.cloudflareClean) ...[
                    _buildMode2Section(
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      chipBgColor: chipBgColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryBlue: primaryBlue,
                      loc: loc,
                    ),
                  ] else ...[
                    _buildMode3Section(
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      chipBgColor: chipBgColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryBlue: primaryBlue,
                      loc: loc,
                    ),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: borderColor, height: 1),
                  ),

                  // --- SERVER & LOCAL PORTS SECTION (DYNAMIC / NON-HARDCODED) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          loc.profilePorts,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: chipBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          "${portChips.length}",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.profilePortsDesc,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                  const SizedBox(height: 12),

                  // Interactive Port Chips with delete button
                  if (portChips.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: portChips.map((port) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: chipBgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 14,
                                color: Color(0xFF22C55E),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                port,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _removePort(port),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  if (portChips.isNotEmpty) const SizedBox(height: 12),

                  // Add Port dynamically
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newPortController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: loc.addNewPort,
                            hintStyle: TextStyle(
                              color: textSecondary.withOpacity(0.7),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: surfaceColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          onFieldSubmitted: (_) => _addNewPort(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _addNewPort,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          loc.add,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(
                    loc.allPortsText,
                    textSecondary,
                  ),
                  TextFormField(
                    controller: _serverPortsController,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "20456, 20451, 20454",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel(loc.fallbackPort, textSecondary),
                            TextFormField(
                              controller: _fallbackLocalPortController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: "40443",
                                filled: true,
                                fillColor: surfaceColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                              validator: (val) {
                                final port = int.tryParse(val ?? "");
                                return port == null || port < 1 || port > 65535
                                    ? "Invalid"
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Divider(color: borderColor, height: 1),
                  ),

                  // --- SUPPORT & VERSION FOOTER ---
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showCommunityDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: primaryBlue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "پشتیبانی و اخبار",
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "@kigaping_fa  •  نسخه 1.0.1",
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildInfoBadge(
                                "1.0.1",
                                chipBgColor,
                                borderColor,
                                textSecondary,
                              ),
                              _buildInfoBadge(
                                "زمان رایگان ۳۰ دقیقه‌ای با تمدید خودکار",
                                chipBgColor,
                                borderColor,
                                textSecondary,
                              ),
                              _buildInfoBadge(
                                "۴ ساعت پاداش پس از تماشای کامل تبلیغ",
                                chipBgColor,
                                borderColor,
                                textSecondary,
                              ),
                              _buildInfoBadge(
                                "بازطراحی صفحهٔ تنظیمات",
                                chipBgColor,
                                borderColor,
                                textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: isDark ? 0 : 4,
                    shadowColor: primaryBlue.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _saveSettings,
                  child: Text(
                    loc.saveSettings,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelector({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
    required AppLocalizations loc,
  }) {
    return Column(
      children: [
        _buildModeOptionTile(
          mode: TransportMode.directSni,
          title: loc.mode1Title,
          subtitle: loc.mode1Sub,
          icon: Icons.security_rounded,
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          primaryBlue: primaryBlue,
        ),
        const SizedBox(height: 8),
        _buildModeOptionTile(
          mode: TransportMode.cloudflareClean,
          title: loc.mode2Title,
          subtitle: loc.mode2Sub,
          icon: Icons.filter_drama_rounded,
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          primaryBlue: primaryBlue,
        ),
        const SizedBox(height: 8),
        _buildModeOptionTile(
          mode: TransportMode.dnsTunnel,
          title: loc.mode3Title,
          subtitle: loc.mode3Sub,
          icon: Icons.dns_rounded,
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          primaryBlue: primaryBlue,
        ),
      ],
    );
  }

  Widget _buildModeOptionTile({
    required TransportMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
  }) {
    final isSelected = _selectedTransportMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTransportMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue.withOpacity(0.08) : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryBlue : borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryBlue.withOpacity(0.15)
                    : (isDark
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? primaryBlue : textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? primaryBlue : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? primaryBlue : textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMode1Section({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color chipBgColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
    required AppLocalizations loc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            loc.serverSection,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel(loc.serverHost, textSecondary),
        TextFormField(
          controller: _serverHostController,
          style: TextStyle(
            color: textPrimary,
            fontSize: 13.5,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: "212.227.143.16",
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          validator: (val) =>
              (val == null || val.trim().isEmpty) ? loc.serverHost : null,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.daemonPort, textSecondary),
                  TextFormField(
                    controller: _daemonPortController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "15443",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    validator: (val) {
                      final port = int.tryParse(val ?? "");
                      return port == null || port < 1 || port > 65535
                          ? "Invalid"
                          : null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.fragmentDelay, textSecondary),
                  TextFormField(
                    controller: _fragmentDelayController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "3",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildFieldLabel(loc.fakeSni, textSecondary),
        DropdownButtonFormField<String>(
          value: _selectedFakeSni,
          dropdownColor: surfaceColor,
          style: TextStyle(color: textPrimary, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: _fakeSniPresets.map((sni) {
            return DropdownMenuItem(value: sni, child: Text(sni));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedFakeSni = val);
          },
        ),

        if (_selectedFakeSni == "Custom ...") ...[
          const SizedBox(height: 12),
          _buildFieldLabel(loc.customDomain, textSecondary),
          TextFormField(
            controller: _customSniController,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: "speedtest.net",
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.fakePacketToggle,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: _enableFakePacket,
              activeColor: primaryBlue,
              onChanged: (val) => setState(() => _enableFakePacket = val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMode2Section({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color chipBgColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
    required AppLocalizations loc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            loc.cfSection,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel(loc.cfCleanIp, textSecondary),
        DropdownButtonFormField<String>(
          value: _selectedCfCleanPreset,
          dropdownColor: surfaceColor,
          style: TextStyle(color: textPrimary, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: _cfCleanPresets.map((ip) {
            return DropdownMenuItem(value: ip, child: Text(ip));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCfCleanPreset = val;
                if (val != "Custom ...") {
                  _cfCleanIpController.text = val;
                }
              });
            }
          },
        ),

        if (_selectedCfCleanPreset == "Custom ...") ...[
          const SizedBox(height: 12),
          _buildFieldLabel(loc.customCleanIp, textSecondary),
          TextFormField(
            controller: _cfCleanIpController,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: "104.18.119.142",
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.cfPort, textSecondary),
                  TextFormField(
                    controller: _cfCleanPortController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "443",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.fragmentDelay, textSecondary),
                  TextFormField(
                    controller: _cfFragmentDelayController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "5",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildFieldLabel(loc.cfSni, textSecondary),
        TextFormField(
          controller: _cfServerSniController,
          style: TextStyle(
            color: textPrimary,
            fontSize: 13.5,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: "ws.kigaping.com",
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMode3Section({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color chipBgColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryBlue,
    required AppLocalizations loc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            loc.dnsSection,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel(loc.dnsProto, textSecondary),
        DropdownButtonFormField<String>(
          value: _selectedDnsProtocol,
          dropdownColor: surfaceColor,
          style: TextStyle(color: textPrimary, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: DnsTunnelProtocol.values.map((p) {
            return DropdownMenuItem(
              value: p.id,
              child: Text(p.displayName),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              final proto = DnsTunnelProtocol.fromId(val);
              setState(() {
                _selectedDnsProtocol = val;
                _dnsSubdomainController.text = proto.defaultSubdomain;
                if (proto.defaultPublicKey.isNotEmpty) {
                  _dnsPublicKeyController.text = proto.defaultPublicKey;
                }
              });
            }
          },
        ),
        const SizedBox(height: 14),

        _buildFieldLabel(loc.dnsSubdomain, textSecondary),
        TextFormField(
          controller: _dnsSubdomainController,
          style: TextStyle(
            color: textPrimary,
            fontSize: 13.5,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: "v.vpn.kigaping.com",
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          validator: (val) =>
              (val == null || val.trim().isEmpty) ? loc.dnsSubdomain : null,
        ),
        const SizedBox(height: 14),

        _buildFieldLabel(loc.dnsPubKey, textSecondary),
        TextFormField(
          controller: _dnsPublicKeyController,
          style: TextStyle(
            color: textPrimary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: "4438c41e91bf44b10a9e1a67bbade78f99137a875efc189ba54a6c95ecc2650a",
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel(loc.dnsResolver, textSecondary),
        DropdownButtonFormField<String>(
          value: _selectedDnsResolver,
          dropdownColor: surfaceColor,
          isExpanded: true,
          style: TextStyle(color: textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: [
            ...DnsResolverOption.presets.map((r) {
              return DropdownMenuItem(
                value: r.endpoint,
                child: Text("${r.name} (${r.type.toUpperCase()})"),
              );
            }),
            const DropdownMenuItem(
              value: "Custom ...",
              child: Text("Custom ..."),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedDnsResolver = val;
                final opt = DnsResolverOption.presets
                    .where((e) => e.endpoint == val)
                    .firstOrNull;
                if (opt != null) {
                  _dnsResolverType = opt.type;
                }
              });
            }
          },
        ),

        if (_selectedDnsResolver == "Custom ...") ...[
          const SizedBox(height: 12),
          _buildFieldLabel(loc.customDomain, textSecondary),
          TextFormField(
            controller: _customDnsResolverController,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: "https://cloudflare-dns.com/dns-query",
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.dnsType, textSecondary),
                  DropdownButtonFormField<String>(
                    value: _dnsResolverType,
                    dropdownColor: surfaceColor,
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "doh", child: Text("DoH (HTTPS)")),
                      DropdownMenuItem(value: "udp", child: Text("UDP (Port 53)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _dnsResolverType = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.dnsLocalPort, textSecondary),
                  TextFormField(
                    controller: _dnsLocalPortController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "53001",
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSegment({
    required ThemeMode currentMode,
    required Color chipBgColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required AppLocalizations loc,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: chipBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSegmentItem(
              label: loc.themeSystem,
              icon: Icons.brightness_auto_rounded,
              selected: currentMode == ThemeMode.system,
              onTap: () => ThemeController.instance.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(width: 4),
            _buildSegmentItem(
              label: loc.themeLight,
              icon: Icons.light_mode_rounded,
              selected: currentMode == ThemeMode.light,
              onTap: () => ThemeController.instance.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(width: 4),
            _buildSegmentItem(
              label: loc.themeDark,
              icon: Icons.dark_mode_rounded,
              selected: currentMode == ThemeMode.dark,
              onTap: () => ThemeController.instance.setThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, currentLang, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppLanguage>(
              value: currentLang,
              dropdownColor: surfaceColor,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: textPrimary,
                size: 20,
              ),
              isDense: true,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              items: AppLanguage.values.map((lang) {
                return DropdownMenuItem<AppLanguage>(
                  value: lang,
                  child: Text(
                    lang.displayName,
                    style: TextStyle(color: textPrimary, fontSize: 12.5),
                  ),
                );
              }).toList(),
              onChanged: (lang) {
                if (lang != null) {
                  LocaleController.instance.setLanguage(lang);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2855D9) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : const Color(0xFF8B949E),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
