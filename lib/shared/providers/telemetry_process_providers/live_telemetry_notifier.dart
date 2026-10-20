import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/utils/imu_moving_average_filter.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';

/// Live telemetry from **one** sole, keyed by its identityKey.
///
/// One instance per sole: two feet stream at 50 Hz each and neither may
/// overwrite the other's window. Screens that mean "the sole" rather than a
/// named foot read `telemetryViewProvider`, which follows the primary sole.
class LiveTelemetryNotifier extends Notifier<LiveTelemetryState> {
  LiveTelemetryNotifier(this.soleKey);

  /// The sole this window belongs to.
  final String soleKey;

  /// Smooths incoming live samples before they are stored. Owns its own raw
  /// history, so it must not be recreated per sample — which is also why each
  /// sole needs its own notifier rather than a shared one.
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
      updatedAt: _stamp(),
      errorMessage: null,
    );
  }

  void updateRecordImuNotifyData(RecordImuNotifyDataModel data) {
    final next = [...state.record, data];
    // final trimmed = next.length > max ? next.sublist(next.length - max) : next;
    state = state.copyWith(
      record: next,
      source: TelemetrySource.bleLive,
      updatedAt: _stamp(),
      errorMessage: null,
    );
  }

  void clearRecordImuNotifyData() {
    state = state.copyWith(record: []);
  }

  /// Stamps now, and tells [latestTelemetryAtProvider] — which is what "the
  /// wearable is online" reads once there can be two soles.
  DateTime _stamp() {
    final now = clock.now();
    ref.read(latestTelemetryAtProvider.notifier).mark(now);
    return now;
  }
}

final liveTelemetryProvider =
    NotifierProvider.family<LiveTelemetryNotifier, LiveTelemetryState, String>(
      LiveTelemetryNotifier.new,
    );

/// The newest moment **any** sole reported live telemetry.
///
/// Written by [LiveTelemetryNotifier] rather than derived from the paired
/// list: it must not wait for settings to load, and Riverpod gives no way to
/// enumerate a family's live instances. Only ever moves forward.
class LatestTelemetryAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void mark(DateTime at) {
    final current = state;
    if (current == null || at.isAfter(current)) state = at;
  }
}

final latestTelemetryAtProvider =
    NotifierProvider<LatestTelemetryAtNotifier, DateTime?>(
      LatestTelemetryAtNotifier.new,
    );
