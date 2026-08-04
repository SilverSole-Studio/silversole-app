import 'package:silversole/shared/models/imu_notify_data_model.dart';

/// Simple moving average (SMA) over live IMU samples.
///
/// Smooths the six IMU axes and the FSR pressure channels by averaging the
/// last [windowSize] **raw** samples. The filter keeps its own history because
/// the values it emits are the ones stored downstream — averaging already
/// averaged output would cascade the filter and skew the result.
///
/// `pitch` / `roll` are deliberately passed through untouched: the firmware
/// already fuses those, so filtering them again would only add lag. Battery
/// and charging state are status flags, not signals, and are taken from the
/// newest sample.
class ImuMovingAverageFilter {
  ImuMovingAverageFilter({this.windowSize = defaultWindowSize})
    : assert(windowSize > 0, 'windowSize must be positive');

  /// ~0.5 s of history at the firmware's 20 Hz notify rate.
  static const defaultWindowSize = 10;

  final int windowSize;
  final _window = <ImuNotifyDataModel>[];

  /// Adds [sample] to the window and returns the smoothed sample.
  ///
  /// While the window is still filling, the mean is taken over the samples
  /// collected so far, so early output is smoothed rather than biased toward 0.
  ImuNotifyDataModel apply(ImuNotifyDataModel sample) {
    _window.add(sample);
    if (_window.length > windowSize) {
      _window.removeRange(0, _window.length - windowSize);
    }

    int mean(int Function(ImuNotifyDataModel s) pick) {
      var sum = 0;
      for (final s in _window) {
        sum += pick(s);
      }
      return (sum / _window.length).round();
    }

    // The newest sample decides how many sensors are reported; average each
    // channel only over the samples that actually carry it.
    final pressure = List<int>.generate(sample.pressure.length, (i) {
      var sum = 0;
      var count = 0;
      for (final s in _window) {
        if (i < s.pressure.length) {
          sum += s.pressure[i];
          count++;
        }
      }
      return count == 0 ? sample.pressure[i] : (sum / count).round();
    }, growable: false);

    return sample.copyWith(
      ax: mean((s) => s.ax),
      ay: mean((s) => s.ay),
      az: mean((s) => s.az),
      gx: mean((s) => s.gx),
      gy: mean((s) => s.gy),
      gz: mean((s) => s.gz),
      pressure: pressure,
    );
  }

  /// Drops all history, e.g. after a reconnect so stale samples don't bleed
  /// into the new stream.
  void reset() => _window.clear();
}
