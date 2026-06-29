import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TelemetryFacade {
  /// A device counts as "online" while live telemetry keeps arriving within
  /// this window; once it elapses with no new data, it flips to offline.
  static const onlineWindow = Duration(seconds: 35);

  bool checkDeviceOnline(DateTime? time) {
    if (time == null) return false;
    return clock.now().difference(time) < onlineWindow;
  }
}

final telemetryFacadeProvider = Provider<TelemetryFacade>((_) => TelemetryFacade());
