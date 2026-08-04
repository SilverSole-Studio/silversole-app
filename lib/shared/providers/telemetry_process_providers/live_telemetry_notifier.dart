import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/utils/imu_moving_average_filter.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';

class LiveTelemetryNotifier extends Notifier<LiveTelemetryState> {
  /// Smooths incoming live samples before they are stored. Owns its own raw
  /// history, so it must not be recreated per sample.
  final _imuFilter = ImuMovingAverageFilter();

  @override
  LiveTelemetryState build() {
    unawaited(_load());
    return const LiveTelemetryState();
  }

  Future<void> _load() async {}

  void updateImuNotifyData(ImuNotifyDataModel data) {
    final next = [...state.recentImu, _imuFilter.apply(data)];
    final trimmed = next.length > 100 ? next.sublist(next.length - 100) : next;
    state = state.copyWith(
      recentImu: trimmed,
      source: TelemetrySource.bleLive,
      updatedAt: clock.now(),
      errorMessage: null,
    );
  }

  void updateRecordImuNotifyData(RecordImuNotifyDataModel data) {
    final next = [...state.record, data];
    // final trimmed = next.length > max ? next.sublist(next.length - max) : next;
    state = state.copyWith(
      record: next,
      source: TelemetrySource.bleLive,
      updatedAt: clock.now(),
      errorMessage: null,
    );
  }

  void clearRecordImuNotifyData() {
    state = state.copyWith(record: []);
  }
}

final liveTelemetryProvider =
    NotifierProvider<LiveTelemetryNotifier, LiveTelemetryState>(
      LiveTelemetryNotifier.new,
    );
