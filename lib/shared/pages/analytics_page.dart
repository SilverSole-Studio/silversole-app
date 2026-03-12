import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';
import 'package:silversole/shared/widgets/chart/record_imu_chart_section.dart';
import 'package:silversole/shared/widgets/create_file_and_share.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int _selectedIndex = 0;
  bool _isRecording = false;

  Widget notActiveBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context).vertical;
    final bodyHeight = (screenHeight - safePadding - 220).clamp(220.0, screenHeight);
    return SizedBox(
      height: bodyHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            SvgPicture.asset('assets/images/undraw_void_wez2.svg', width: 300),
            const SizedBox(height: 32),
            Text('no_primary_device_title'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              'no_primary_device_body'.tr(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget singleTab({required List<String> data, required int selectedIndex, required Function(int) onSelected}) {
    if (data.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 4,
      children: [
        ...data.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          return GestureDetector(
            onTap: () {
              onSelected(i);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 100),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == i ? context.cs.surfaceContainerHighest : context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(selectedIndex == i ? 50 : 4),
              ),
              child: Text(label, style: context.tt.bodyLarge.bold),
            ),
          );
        }),
      ],
    );
  }

  Future<void> startRecord() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }

    final ble = ref.read(bleConnectProvider);
    final telemetryNotifier = ref.read(liveTelemetryProvider.notifier);
    telemetryNotifier.clearRecordImuNotifyData();
    final result = await ble.writeBoolCharacteristic(
      preferredDevice,
      serviceUuid: serviceUuid,
      characteristicUuid: recordRequestCharUuid,
      value: true,
    );

    switch (result) {
      case Error():
        showErrorSnakeBar(result.error.toString());
      case Ok():
        break;
    }

    unawaited(() async {
      final result = await isRecording();
      if (mounted) setState(() => _isRecording = result);
    }());

    final recordingResult = await isRecording();
    if (mounted) setState(() => _isRecording = recordingResult);
  }

  Future<void> stopRecord() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }

    final ble = ref.read(bleConnectProvider);
    final result = await ble.writeBoolCharacteristic(
      preferredDevice,
      serviceUuid: serviceUuid,
      characteristicUuid: recordRequestCharUuid,
      value: false,
    );

    switch (result) {
      case Error():
        showErrorSnakeBar(result.error.toString());
      case Ok():
        setState(() => _isRecording = false);
    }

    final recordingResult = await isRecording();
    if (mounted) setState(() => _isRecording = recordingResult);
  }

  Future<bool> isRecording() async {
    final preferredDevice = ref.read(settingsProvider).preferredDevice;
    if (preferredDevice == null) {
      showErrorSnakeBar('not_binding'.tr());
      return false;
    }

    final ble = ref.read(bleConnectProvider);
    final result = await ble.readStringCharacteristic(
      preferredDevice,
      serviceUuid: serviceUuid,
      characteristicUuid: recordRequestCharUuid,
    );

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
  ///     [ts_ms, ax, ay, az, gx, gy, gz, pressure, wear_status, battery_percent],
  ///     [...],
  ///     ...
  ///   ]
  /// }
  /// ```
  String buildRecordJson(List<RecordImuNotifyDataModel> recordList) {
    final startTs = recordList.first.timestamp;
    final sampleRate = 200;
    final samples = recordList
        .map((e) => [e.timestamp, e.ax, e.ay, e.az, e.gx, e.gy, e.gz, e.pressure, e.wearStatus, e.batteryPercent])
        .toList(growable: false);

    return jsonEncode({
      'start_ts_ms': startTs,
    'sample_rate_hz': sampleRate,
    'samples': samples
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
      'kick': 'kick'.tr()
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
                    createFileAndShare(fileName: '${userID}_${now}_$typeLabel.json', content: json);
                  },
                );
              }),
            ],
          ),
        ),
      )
    );
  }

  Future<void> openShareFileBottomSheet() async {

  }

  @override
  Widget build(BuildContext context) {
    final recordList = ref.watch(liveTelemetryProvider).record;
    final recordCount = recordList.length;
    final labels = ['pressure'.tr(), 'acc'.tr(), 'gyro'.tr(), 'six-axis'.tr(), 'battery'.tr()];

    return Scaffold(
      appBar: AppBar(
        title: Text('analytics'.tr(), style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              spacing: 16,
              children: [
                singleTab(
                  data: labels,
                  selectedIndex: _selectedIndex,
                  onSelected: (i) => setState(() => _selectedIndex = i),
                ),
                ImuChartSection(type: ChardDisplayType.single, selectedList: [_selectedIndex]),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: !_isRecording ? startRecord : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Row(
                            spacing: 8,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [const Icon(LucideIcons.play), Text('start_record'.tr())],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(elevation: 0),
                        onPressed: stopRecord,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Row(
                            spacing: 8,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [const Icon(LucideIcons.square), Text('stop_record'.tr())],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: Card.filled(
                    color: context.cs.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        spacing: 32,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('record'.tr(), style: context.tt.titleSmall.bold),
                          if (_isRecording) RecordImuChartSection(type: ChardDisplayType.all),
                          // if (_isRecording)
                          //   Text('already_recording_with_seconds'.tr(args: ["0"]), style: context.tt.titleMedium),
                          Text(
                            'already_recording_with_count'.tr(args: [recordCount.toString()]),
                            style: context.tt.titleMedium,
                          ),
                          if (!_isRecording)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: context.cs.primary, elevation: 0),
                                  onPressed: recordList.isEmpty ? null : () => exportRecorded(recordList),
                                  child: Row(spacing: 8, children: [Icon(LucideIcons.download), Text('export'.tr())]),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
