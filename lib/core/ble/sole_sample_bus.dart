import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

/// One live IMU packet as it came off a sole: parsed, pressure channels
/// already reordered by `fixPressureChannels`, and **not** smoothed.
class SoleSample {
  const SoleSample({required this.identityKey, required this.data});

  /// The sole it came from — `BlePairedDevice.identityKey`.
  final String identityKey;
  final ImuNotifyDataModel data;
}

/// Every raw sample from every sole, as it arrives.
///
/// `LiveTelemetryNotifier` keeps a moving-averaged window per sole for the
/// charts; this is the unaveraged stream next to it, for consumers that need
/// the timing the average would smear (the H5 games judge steps on it).
class SoleSampleBus {
  final _controller = StreamController<SoleSample>.broadcast();

  Stream<SoleSample> get stream => _controller.stream;

  void emit(SoleSample sample) {
    if (_controller.isClosed) return;
    _controller.add(sample);
  }

  void dispose() {
    _controller.close();
  }
}

final soleSampleBusProvider = Provider<SoleSampleBus>((ref) {
  final bus = SoleSampleBus();
  ref.onDispose(bus.dispose);
  return bus;
});
