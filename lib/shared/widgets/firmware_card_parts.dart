import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

// What both themes' firmware cards share. Each theme only draws it.

enum FirmwareCardAction {
  none,
  upToDate,
  update,
  downgrade,
  needsWiredUpdate,
  versionUnreadable,
  retry,
  appTooOld,
}

FirmwareCardAction firmwareCardAction(
  FirmwareCheck check,
) => switch (check.status) {
  FirmwareCheckStatus.notConnected => FirmwareCardAction.none,
  FirmwareCheckStatus.upToDate => FirmwareCardAction.upToDate,
  FirmwareCheckStatus.updateAvailable => FirmwareCardAction.update,
  FirmwareCheckStatus.downgradeAvailable => FirmwareCardAction.downgrade,
  FirmwareCheckStatus.needsWiredUpdate => FirmwareCardAction.needsWiredUpdate,
  FirmwareCheckStatus.versionUnreadable => FirmwareCardAction.versionUnreadable,
  FirmwareCheckStatus.checkFailed => FirmwareCardAction.retry,
  FirmwareCheckStatus.manifestUnsupported => FirmwareCardAction.appTooOld,
};

/// The sole's name plus the one thing that tells two identical "SilverSole"s
/// apart: the foot it is worn on, or its ID suffix before a side is assigned.
///
/// The foot comes first because with one sole per foot a version number is
/// useless without knowing whose it is — the firmware card only ever shows
/// the primary sole's. Same fallback the foreground notification uses.
String soleLabel(BlePairedDevice device) {
  final tag =
      device.footSide?.labelKey.tr() ??
      (device.shortId == null ? null : '••••${device.shortId}');
  return tag == null ? device.name : '${device.name} $tag';
}

/// `SilverSole Left foot · v0.4.0`, or null with no sole connected.
String? firmwareCardDetail(FirmwareCheck? check) {
  final sole = check?.sole;
  if (sole == null) return null;
  final version = sole.firmwareVersion;
  final label = soleLabel(sole.device);
  return version == null ? label : '$label · v$version';
}

void openFirmwareUpdate(BuildContext context, FirmwareCheck check) {
  final manifest = check.manifest;
  if (manifest == null) return;
  context.push('/firmware-update', extra: manifest);
}

/// The sole does not refuse older firmware, so a downgrade (developer mode
/// only) asks first.
Future<void> confirmDowngrade(BuildContext context, FirmwareCheck check) async {
  final manifest = check.manifest;
  if (manifest == null) return;
  await showConfirmLeaveDialog(
    context,
    title: 'firmware_downgrade_title'.tr(),
    text: 'firmware_downgrade_content'.tr(
      args: [manifest.version, check.sole?.firmwareVersion ?? '-'],
    ),
    confirmText: 'firmware_downgrade_to'.tr(args: [manifest.version]),
    confirmType: ConfirmType.delete,
    onConfirm: () {
      if (context.mounted) context.push('/firmware-update', extra: manifest);
    },
  );
}

/// Debug builds only: installs a developer's own signed image, bypassing the
/// server. Release builds compile this out — kDebugMode is a constant and the
/// only button that calls it sits behind it too.
Future<void> pickLocalFirmware(BuildContext context, WidgetRef ref) async {
  if (!kDebugMode) return;
  final bin = await _pickBytes('firmware_pick_bin'.tr());
  if (bin == null) return;
  final signature = await _pickBytes('firmware_pick_sig'.tr());
  if (signature == null) return;
  switch (ref.read(firmwareReleaseServiceProvider).localImage(bin, signature)) {
    case Error(:final error):
      showErrorSnakeBar('firmware_local_invalid'.tr(args: ['$error']));
    case Ok(:final value):
      if (context.mounted) context.push('/firmware-update', extra: value);
  }
}

Future<Uint8List?> _pickBytes(String title) async {
  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: title,
    withData: true,
  );
  return picked?.files.single.bytes;
}

/// Seven quick taps toggle the hidden developer mode: the beta firmware
/// channel and warned downgrades (the firmware handoff's §6.2).
class DevModeTapTarget extends ConsumerStatefulWidget {
  const DevModeTapTarget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DevModeTapTarget> createState() => _DevModeTapTargetState();
}

class _DevModeTapTargetState extends ConsumerState<DevModeTapTarget> {
  static const _taps = 7;
  static const _window = Duration(seconds: 3);

  var _count = 0;
  DateTime? _first;

  void _onTap() {
    final now = DateTime.now();
    final first = _first;
    if (first == null || now.difference(first) > _window) {
      _first = now;
      _count = 0;
    }
    if (++_count < _taps) return;
    _count = 0;
    _first = null;
    final on = !ref.read(settingsProvider).firmwareDevMode;
    unawaited(ref.read(settingsProvider.notifier).setFirmwareDevMode(on));
    showMessage((on ? 'firmware_dev_mode_on' : 'firmware_dev_mode_off').tr());
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _onTap,
    child: widget.child,
  );
}
