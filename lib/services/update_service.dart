import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class ReleaseInfo {
  final String tagName;
  final String title;
  final String body;
  final String htmlUrl;
  final String? apkDownloadUrl;

  ReleaseInfo({
    required this.tagName,
    required this.title,
    required this.body,
    required this.htmlUrl,
    this.apkDownloadUrl,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  static const String currentVersion = '1.1.0';
  static const List<String> releaseApiUrls = [
    'https://api.github.com/repos/t-51/ME-Spoofing/releases/latest',
    'https://api.github.com/repos/t-51/MHPanel/releases/latest',
  ];

  Future<ReleaseInfo?> checkLatestRelease() async {
    final client = HttpClient();
    client.userAgent = 'ME-Spoofing-App/$currentVersion';
    client.connectionTimeout = const Duration(seconds: 7);

    for (final url in releaseApiUrls) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('Accept', 'application/vnd.github.v3+json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final tagName = (data['tag_name'] as String? ?? '').trim();
          final title = (data['name'] as String? ?? tagName).trim();
          final notes = (data['body'] as String? ?? '').trim();
          final htmlUrl = (data['html_url'] as String? ?? 'https://github.com/t-51/MHPanel').trim();

          String? apkUrl;
          final assets = data['assets'] as List<dynamic>?;
          if (assets != null) {
            for (final asset in assets) {
              if (asset is Map<String, dynamic>) {
                final name = (asset['name'] as String? ?? '').toLowerCase();
                final dl = asset['browser_download_url'] as String?;
                if (name.endsWith('.apk') && dl != null) {
                  apkUrl = dl;
                  break;
                }
              }
            }
          }

          if (tagName.isNotEmpty) {
            return ReleaseInfo(
              tagName: tagName,
              title: title,
              body: notes,
              htmlUrl: htmlUrl,
              apkDownloadUrl: apkUrl,
            );
          }
        }
      } catch (_) {
        // Try next fallback endpoint
      }
    }
    client.close();
    return null;
  }

  bool isNewerVersion(String releaseTag) {
    final cleanTag = releaseTag.toLowerCase().replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final tagParts = cleanTag.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final t = i < tagParts.length ? tagParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (t > c) return true;
      if (t < c) return false;
    }
    return false;
  }

  Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);

    // Show quick checking indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.checkingUpdate),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    final release = await checkLatestRelease();

    if (!context.mounted) return;

    if (release == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.updateTitle),
          content: Text('${loc.upToDate}\n(v$currentVersion)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.close),
            ),
          ],
        ),
      );
      return;
    }

    final hasUpdate = isNewerVersion(release.tagName);
    if (!hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.updateTitle),
          content: Text('${loc.upToDate}\n(${loc.currentVersion}: v$currentVersion)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.close),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(loc.newVersionAvailable),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${loc.newVersionAvailable}: ${release.tagName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${loc.currentVersion}: v$currentVersion',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              if (release.body.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  release.body,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.close),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final target = release.apkDownloadUrl ?? release.htmlUrl;
              final uri = Uri.parse(target);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(loc.downloadAndInstall),
          ),
        ],
      ),
    );
  }
}

