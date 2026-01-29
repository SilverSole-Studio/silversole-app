import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/update_info_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../core/error/result.dart';
import '../../core/utils/update_checker.dart';
import '../../core/utils/utils_function.dart';

Future<void> showUpdateVersionDialog(BuildContext context) async {
  debugPrint('[UpdateCheck] show dialog');

  final String currentVersion = await getAppVersion();
  final String? latestVersion;
  final String? changelog;
  final int? size;
  final String? filename;
  final result = await fetchLatestReleaseTag();
  switch (result) {
    case Ok<UpdateInfo>():
      latestVersion = result.value.tag;
      changelog = result.value.notes;
      filename = result.value.name;
      size = result.value.size;
    case Error():
      debugPrint('[UpdateCheck] fetch failed: ${result.error}');
      if (!context.mounted) return;
      showErrorSnakeBar(result.error.toString());
      return;
  }
  if (!isUpdateAvailable(currentVersion, latestVersion)) return;
  if (!context.mounted) return;

  final ts = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  const releasePath = Constants.latestReleaseUrl;
  final downloadPath = '${Constants.releaseDownloadUrl}/$latestVersion/$filename';

  void clickToJump(String uriStr) {
    final uri = Uri.parse(uriStr);
    launchUrl(uri, mode: LaunchMode.externalApplication).then((ok) {
      if (!ok && context.mounted) {
        showErrorSnakeBar('Could not open release page');
      }
    });
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 50,
            children: [
              // New Version Title
              Container(
                // margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  // '發現新版本 $latestVersion',
                  'new_version'.tr(args: [latestVersion.toString()]),
                  style: ts.headlineMedium?.copyWith(color: cs.primaryFixed, fontWeight: FontWeight.w600),
                ),
              ),

              // Update Content
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(changelog ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),

              // Download Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  spacing: 8,
                  children: [
                    outlineButtonWithTheme(
                      title: filename ?? 'app-release.apk',
                      subtitle: '${bytesToMiB(size ?? 0).toStringAsFixed(2)} MB',
                      icon: LucideIcons.download,
                      onPressed: () => clickToJump(downloadPath),
                    ),
                    outlineButtonWithTheme(
                      title: 'Github Release ',
                      subtitle: latestVersion.toString(),
                      icon: LucideIcons.github,
                      onPressed: () => clickToJump(releasePath),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget outlineButtonWithTheme({
  required String title,
  String subtitle = '',
  required IconData icon,
  required VoidCallback onPressed,
}) {
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onPressed,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(icon, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w400)),
    ),
  );
}
