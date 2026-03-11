import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/chard_section.dart';

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
        showMessage('start_record'.tr());
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
        showMessage('stop_record'.tr());
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

  Future<void> exportRecorded() async {
    comingSoon(); //TODO: complete export recorded json file
  }

  @override
  Widget build(BuildContext context) {
    final recordCount = ref.watch(liveTelemetryProvider).record.length;
    final labels = ['pressure'.tr(), 'acc'.tr(), 'gyro'.tr(), 'battery'.tr()];

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
                ChardSection(type: ChardDisplayType.single, selectedList: [_selectedIndex]),
                const SizedBox(height: 16),
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
                          Text('recording'.tr(), style: context.tt.titleSmall.bold),
                          if (_isRecording)
                          ChardSection(type: ChardDisplayType.all, source: ChardDataSource.recordImu),
                          // if (_isRecording)
                          //   Text('already_recording_with_seconds'.tr(args: ["0"]), style: context.tt.titleMedium),
                          Text('already_recording_with_count'.tr(args: [recordCount.toString()]), style: context.tt.titleMedium),
                          if (!_isRecording)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: context.cs.primary, elevation: 0),
                                  onPressed: exportRecorded,
                                  child: Text('export'.tr()),
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
