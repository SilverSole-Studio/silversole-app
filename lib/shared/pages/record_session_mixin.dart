import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/create_file_and_share.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

/// Drives a device recording session: start/stop the sole's record
/// characteristic, track whether it is running, and export what came back.
///
/// Lives in a mixin because the analytics detail screen has one implementation
/// per theme; only the chrome differs, so the BLE half is shared rather than
/// copied.
mixin RecordSessionMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Whether the sole reports an active recording.
  bool isRecordingNow = false;

  Future<void> startRecord() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }

    final ble = ref.read(bleConnectProvider);
    final telemetryNotifier = ref.read(liveTelemetryProvider.notifier);
    telemetryNotifier.clearRecordImuNotifyData();
    final result = await ble.writeBool(recordRequestCharUuid, true);

    switch (result) {
      case Error():
        showErrorSnakeBar(result.error.toString());
      case Ok():
        break;
    }

    unawaited(() async {
      final result = await isRecording();
      if (mounted) setState(() => isRecordingNow = result);
    }());

    final recordingResult = await isRecording();
    if (mounted) setState(() => isRecordingNow = recordingResult);
  }

  Future<void> stopRecord() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }

    final ble = ref.read(bleConnectProvider);
    final result = await ble.writeBool(recordRequestCharUuid, false);

    switch (result) {
      case Error():
        showErrorSnakeBar(result.error.toString());
      case Ok():
        setState(() => isRecordingNow = false);
    }

    final recordingResult = await isRecording();
    if (mounted) setState(() => isRecordingNow = recordingResult);
  }

  Future<bool> isRecording() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return false;
    }

    final ble = ref.read(bleConnectProvider);
    final result = await ble.readString(recordRequestCharUuid);

    switch (result) {
      case Error():
        showErrorSnakeBar(result.error.toString());
        return false;
      case Ok():
        return result.value == '1';
    }
  }

  /// [example]
  /// The output json string like:
  /// ```
  /// {
  ///   "start_ts_ms": 1700000000000,
  ///   "sample_rate_hz": 50,
  ///   "samples": [
  ///     [ts_ms, ax, ay, az, gx, gy, gz, p0, p1, p2, wear_status, battery_percent],
  ///     [...],
  ///     ...
  ///   ]
  /// }
  /// ```
  String buildRecordJson(List<RecordImuNotifyDataModel> recordList) {
    final startTs = recordList.first.timestamp;
    final sampleRate = 200;
    // Pressure is a 3-sensor array; pad/truncate to a fixed width so every
    // sample row keeps the same number of columns.
    List<int> pressure3(List<int> p) =>
        List.generate(3, (i) => i < p.length ? p[i] : 0, growable: false);
    final samples = recordList
        .map(
          (e) => [
            e.timestamp,
            e.ax,
            e.ay,
            e.az,
            e.gx,
            e.gy,
            e.gz,
            ...pressure3(e.pressure),
            e.wearStatus,
            e.batteryPercent,
          ],
        )
        .toList(growable: false);

    return jsonEncode({
      'start_ts_ms': startTs,
      'sample_rate_hz': sampleRate,
      'samples': samples,
    });
  }

  Future<void> exportRecorded(List<RecordImuNotifyDataModel> recordList) async {
    if (recordList.isEmpty) return;
    final userID = ref.read(authUserProvider)?.uuid ?? '';
    final now = DateTime.now().toIso8601String().replaceAll(':', '-');
    final json = buildRecordJson(recordList);
    final optionsMap = {
      'walk': 'walk'.tr(),
      'run': 'run'.tr(),
      'sitDown': 'sit_down'.tr(),
      'standUp': 'stand_up'.tr(),
      'fall': 'fall'.tr(),
      'kick': 'kick'.tr(),
    };

    await showContentDialog(
      context,
      title: 'export_record_file_title'.tr(),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...optionsMap.entries.map((e) {
                final typeLabel = e.key;
                final title = e.value;
                return outlineButtonWithTheme(
                  title: title,
                  icon: LucideIcons.personStanding,
                  onPressed: () {
                    Navigator.pop(context);
                    createFileAndShare(
                      fileName: '${userID}_${now}_$typeLabel.json',
                      content: json,
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
