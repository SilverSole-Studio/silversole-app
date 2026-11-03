import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/report/activity_report.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/widgets/create_file_and_share.dart';
import 'package:silversole/shared/widgets/report/activity_report_card.dart';

/// Hands the finished picture to whatever shares it. A test passes its own so
/// nothing real is opened.
typedef ShareReportImage =
    Future<void> Function(Uint8List png, String fileName);

Future<void> _shareWithSystem(Uint8List png, String fileName) =>
    createImageAndShare(bytes: png, fileName: fileName);

/// Longest name that can be typed on the record.
const reportNicknameMaxLength = 12;

/// Pixel ratio of the shared picture: the card is 360 wide, so 1080 px.
const _imagePixelRatio = 3.0;

/// The page behind the Share button on the analytics page: the wearer sees
/// exactly the picture that will leave the phone, picks what goes on it, may
/// type a name, and only then shares it through the system share sheet.
///
/// Only the parts that have data are offered, all ticked at first. The name is
/// optional and starts empty. Nothing is uploaded: the picture is drawn here
/// and handed to the share sheet.
class ActivityReportPage extends ConsumerStatefulWidget {
  const ActivityReportPage({super.key, ShareReportImage? share})
    : share = share ?? _shareWithSystem;

  /// The share button, for tests.
  static const shareButtonKey = Key('report-share-button');

  /// The empty-state message, for tests.
  static const emptyKey = Key('report-empty');

  final ShareReportImage share;

  @override
  ConsumerState<ActivityReportPage> createState() => _ActivityReportPageState();
}

class _ActivityReportPageState extends ConsumerState<ActivityReportPage> {
  final _name = TextEditingController();
  final _boundaryKey = GlobalKey();

  /// Sections the wearer unticked. Kept as the exceptions so a section that
  /// shows up later starts ticked.
  final _off = <ReportSection>{};
  bool _sharing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ActivityReport _report() {
    final realGait = ref.watch(realGaitEnabledProvider);
    return buildActivityReport(
      today: clock.now(),
      footCheck: ref.watch(lastFootCheckProvider),
      activity: ref.watch(gameActivityProvider),
      // Gait and mobility only come from the wearer's own walking; with the
      // switch off the gait page shows a sample, which must never be shared.
      gaitHistory: realGait ? ref.watch(gaitHistoryProvider) : null,
      mobility: realGait ? ref.watch(mobilityCardProvider) : null,
    );
  }

  Future<void> _share(ActivityReport report) async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _imagePixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('no image data');
      final d = report.generatedOn;
      final fileName =
          'activity_record_${d.year}${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}.png';
      await widget.share(data.buffer.asUint8List(), fileName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('report_share_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report();
    final shown = {
      for (final s in report.sections)
        if (!_off.contains(s)) s,
    };
    final canShare = shown.isNotEmpty && !_sharing;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'report_page_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: report.isEmpty
                  ? const _Empty()
                  : SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.base,
                        children: [
                          Text(
                            'report_privacy_note'.tr(),
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextField(
                            controller: _name,
                            maxLength: reportNicknameMaxLength,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                reportNicknameMaxLength,
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'report_nickname_label'.tr(),
                              helperText: 'report_nickname_hint'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Text(
                            'report_pick_sections'.tr(),
                            style: context.textTheme.titleMedium,
                          ),
                          for (final section in report.sections)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(_sectionTitle(section).tr()),
                              value: !_off.contains(section),
                              onChanged: (on) => setState(() {
                                if (on ?? false) {
                                  _off.remove(section);
                                } else {
                                  _off.add(section);
                                }
                              }),
                            ),
                          Text(
                            'report_preview'.tr(),
                            style: context.textTheme.titleMedium,
                          ),
                          // Scaled down on a narrow screen; the picture itself
                          // is drawn at its full width inside.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: context.colorScheme.outlineVariant,
                                ),
                              ),
                              child: RepaintBoundary(
                                key: _boundaryKey,
                                child: ActivityReportCard(
                                  report: report,
                                  shown: shown,
                                  nickname: _name.text,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                AppSpacing.base,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ActivityReportPage.shareButtonKey,
                  onPressed: report.isEmpty || !canShare
                      ? null
                      : () => _share(report),
                  icon: const Icon(LucideIcons.share2),
                  label: Text('report_share'.tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sectionTitle(ReportSection section) => switch (section) {
    ReportSection.footCheck => 'report_section_foot_check',
    ReportSection.games => 'report_section_games',
    ReportSection.gait => 'report_section_gait',
    ReportSection.mobility => 'mobility_title',
  };
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ActivityReportPage.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.base,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
              child: Icon(
                LucideIcons.footprints,
                size: 28,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'report_empty_title'.tr(),
              style: context.textTheme.titleLarge,
            ),
            Text(
              'report_empty_body'.tr(),
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
