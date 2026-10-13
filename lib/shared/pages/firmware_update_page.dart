import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';

/// Installs one firmware image into the connected sole: the confirmation, the
/// progress and the outcome. Shared by both themes — stock Material widgets,
/// styled by whichever theme is on.
class FirmwareUpdatePage extends ConsumerStatefulWidget {
  const FirmwareUpdatePage({super.key, required this.source});

  /// A [FirmwareManifest] from the server, or — debug builds only — a
  /// [FirmwareImage] a developer picked.
  final Object? source;

  @override
  ConsumerState<FirmwareUpdatePage> createState() => _FirmwareUpdatePageState();
}

class _FirmwareUpdatePageState extends ConsumerState<FirmwareUpdatePage> {
  @override
  void initState() {
    super.initState();
    // Open on the confirmation, not on the last update's outcome. Deferred: a
    // provider may not change while the tree is building.
    Future.microtask(() => ref.read(firmwareUpdateProvider.notifier).reset());
  }

  void _start() {
    final ota = ref.read(firmwareUpdateProvider.notifier);
    switch (widget.source) {
      case final FirmwareManifest manifest:
        unawaited(ota.installRelease(manifest));
      case final FirmwareImage image:
        unawaited(ota.installLocal(image));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ota = ref.watch(firmwareUpdateProvider);
    final notifier = ref.read(firmwareUpdateProvider.notifier);
    final cancellable =
        ota.phase == OtaPhase.downloading || ota.phase == OtaPhase.transferring;
    return PopScope(
      // Leaving would not hurt the sole, but would hide how the update ended:
      // cancel is the way out while it runs.
      canPop: !ota.busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !ota.busy,
          title: Text('ota_title'.tr(), style: context.textTheme.titleLarge),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: switch (ota.phase) {
              OtaPhase.idle => _Confirm(
                source: widget.source,
                sole: ref.watch(connectedSoleProvider),
                onStart: _start,
              ),
              OtaPhase.downloading ||
              OtaPhase.transferring ||
              OtaPhase.verifying ||
              OtaPhase.rebooting => _Progress(
                state: ota,
                onCancel: cancellable
                    ? () => unawaited(notifier.cancel())
                    : null,
              ),
              _ => _Outcome(
                state: ota,
                onRetry: notifier.reset,
                onDone: () => context.pop(),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.source,
    required this.sole,
    required this.onStart,
  });

  final Object? source;
  final ConnectedSole? sole;
  final VoidCallback onStart;

  static const _tips = [
    'ota_tip_foreground',
    'ota_tip_nearby',
    'ota_tip_paused',
    'ota_tip_safe',
  ];

  @override
  Widget build(BuildContext context) {
    final (String? target, String notes, int size) = switch (source) {
      final FirmwareManifest m => ('v${m.version}', m.notes, m.size),
      final FirmwareImage i => ('ota_local_file'.tr(), '', i.bin.length),
      _ => (null, '', 0),
    };
    if (target == null) return Text('ota_nothing_to_install'.tr());
    final sole = this.sole;
    final installed = sole?.firmwareVersion;
    final seconds = (size / otaBytesPerSecond).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Text(
              'ota_version_change'.tr(
                args: [installed == null ? '-' : 'v$installed', target],
              ),
              style: context.textTheme.titleLarge,
            ),
            if (sole != null)
              Text(
                soleLabel(sole.device),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              'ota_estimate'.tr(args: ['$seconds', '${(size / 1024).ceil()}']),
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
        if (notes.isNotEmpty)
          _Panel(
            children: [
              Text('ota_notes'.tr(), style: context.textTheme.titleMedium),
              Text(notes, style: context.textTheme.bodyMedium),
            ],
          ),
        _Panel(
          children: [
            Text(
              'ota_before_you_start'.tr(),
              style: context.textTheme.titleMedium,
            ),
            for (final tip in _tips)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Icon(
                    Icons.check,
                    size: 18,
                    color: context.colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(tip.tr(), style: context.textTheme.bodyMedium),
                  ),
                ],
              ),
          ],
        ),
        FilledButton(
          onPressed: sole == null ? null : onStart,
          child: Text('ota_start'.tr()),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.onCancel});

  final OtaState state;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.phase) {
      OtaPhase.downloading => 'ota_downloading'.tr(),
      OtaPhase.transferring => 'ota_transferring'.tr(
        args: ['${state.committed ~/ 1024}', '${state.size ~/ 1024}'],
      ),
      OtaPhase.verifying => 'ota_verifying'.tr(),
      _ => 'ota_rebooting'.tr(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Text(label, style: context.textTheme.titleMedium),
            LinearProgressIndicator(
              value: state.phase == OtaPhase.transferring
                  ? state.progress
                  : null,
            ),
            Text(
              'ota_keep_close'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (onCancel != null)
          OutlinedButton(onPressed: onCancel, child: Text('cancel'.tr())),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.state,
    required this.onRetry,
    required this.onDone,
  });

  final OtaState state;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  static String _v(String? version) => version == null ? '-' : 'v$version';

  @override
  Widget build(BuildContext context) {
    final installed =
        state.phase == OtaPhase.succeeded ||
        state.phase == OtaPhase.localFinished;
    final (IconData icon, Color color, String title) = switch (state.phase) {
      OtaPhase.succeeded => (
        Icons.check_circle_outline,
        context.tokens.success,
        'ota_succeeded'.tr(args: [_v(state.readVersion)]),
      ),
      OtaPhase.localFinished => (
        // Neutral, not a success colour: a local file has no expected
        // version to judge against (the spec's §4).
        Icons.info_outline,
        context.colorScheme.onSurfaceVariant,
        'ota_local_finished'.tr(
          args: [_v(state.fromVersion), _v(state.readVersion)],
        ),
      ),
      OtaPhase.notUpdated => (
        Icons.error_outline,
        context.tokens.alert,
        'ota_not_updated'.tr(),
      ),
      OtaPhase.unconfirmed => (
        Icons.help_outline,
        context.colorScheme.onSurfaceVariant,
        'ota_unconfirmed'.tr(),
      ),
      _ => (
        Icons.cancel_outlined,
        context.colorScheme.error,
        (state.failure ?? DfuFailure.disconnected).messageKey.tr(),
      ),
    };
    final canRetry = switch (state.phase) {
      OtaPhase.notUpdated => true,
      OtaPhase.failed => state.failure?.retryable ?? true,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Icon(icon, size: 48, color: color),
            Text(title, style: context.textTheme.titleLarge),
            if (installed && state.probable)
              Text(
                'ota_probable_note'.tr(),
                style: context.textTheme.bodyMedium,
              ),
            // Every way an update can end short of success leaves the sole on
            // its old firmware, working (the firmware guarantees it).
            if (!installed)
              Text(
                'ota_sole_still_works'.tr(),
                style: context.textTheme.bodyMedium,
              ),
          ],
        ),
        if (canRetry)
          FilledButton(onPressed: onRetry, child: Text('ota_retry'.tr())),
        OutlinedButton(onPressed: onDone, child: Text('ota_done'.tr())),
      ],
    );
  }
}

/// One card section; the theme styles it in both designs.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: children,
      ),
    ),
  );
}
