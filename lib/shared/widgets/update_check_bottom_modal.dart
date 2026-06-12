import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/update_info_model.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:silversole/core/theme/theme.dart';

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
  final downloadPath =
      '${Constants.releaseDownloadUrl}/$latestVersion/$filename';

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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                child: Text(
                  // '發現新版本 $latestVersion',
                  'new_version'.tr(args: [latestVersion.toString()]),
                  style: ts.headlineMedium?.copyWith(color: cs.primaryFixed),
                ),
              ),

              // Update Content
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  child: Text(changelog ?? '', style: ts.titleSmall),
                ),
              ),

              // Download Button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  0,
                  AppSpacing.base,
                  AppSpacing.base,
                ),
                child: Column(
                  spacing: AppSpacing.sm,
                  children: [
                    outlineButtonWithTheme(
                      title: filename ?? 'app-release.apk',
                      subtitle:
                          '${bytesToMiB(size ?? 0).toStringAsFixed(2)} MB',
                      icon: LucideIcons.download,
                      onPressed: () => clickToJump(downloadPath),
                    ),
                    outlineButtonWithTheme(
                      title: 'Github Release ',
                      subtitle: latestVersion.toString(),
                      icon: Icons.open_in_new,
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
    style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
    onPressed: onPressed,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      leading: Icon(icon, size: 28),
      title: Text(title),
      subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
    ),
  );
}
