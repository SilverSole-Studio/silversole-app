import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';

class LiveTelemetryNotifier extends Notifier<LiveTelemetryState> {
  @override
  LiveTelemetryState build() {
    unawaited(_load());
    return const LiveTelemetryState();
  }

  Future<void> _load() async {}

  void updateImuNotifyData(ImuNotifyDataModel data) async {
    final next = [...state.recent, data];
    final trimmed = next.length > 100 ? next.sublist(next.length - 100) : next;
    state = state.copyWith(
      recent: trimmed,
      source: TelemetrySource.bleLive,
      updatedAt: DateTime.now(),
      errorMessage: null,
    );
  }
}

final liveTelemetryProvider = NotifierProvider<LiveTelemetryNotifier, LiveTelemetryState>(LiveTelemetryNotifier.new);
