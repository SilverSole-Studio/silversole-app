import 'package:flutter_riverpod/flutter_riverpod.dart';

class TelemetryFacade {
  bool checkDeviceOnline(DateTime? time) {
    if (time == null) return false;
    final now = DateTime.now();
    final diff = now.difference(time);
    return diff.inSeconds < 35;
  }
}

final telemetryFacadeProvider = Provider<TelemetryFacade>((_) => TelemetryFacade());