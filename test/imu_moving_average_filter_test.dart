import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/imu_moving_average_filter.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

ImuNotifyDataModel _sample({
  int ax = 0,
  int ay = 0,
  int az = 0,
  int gx = 0,
  int gy = 0,
  int gz = 0,
  List<int> pressure = const [0, 0, 0],
  double? pitch,
  double? roll,
  int battery = 100,
  bool charging = false,
}) => ImuNotifyDataModel(
  ax: ax,
  ay: ay,
  az: az,
  gx: gx,
  gy: gy,
  gz: gz,
  pitch: pitch,
  roll: roll,
  pressure: pressure,
  batteryPercent: battery,
  isCharging: charging,
);

void main() {
  test('a single sample passes through unchanged', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    final out = f.apply(_sample(ax: 100, gz: -50, pressure: [10, 20, 30]));
    expect(out.ax, 100);
    expect(out.gz, -50);
    expect(out.pressure, [10, 20, 30]);
  });

  test('averages the six IMU axes over the window', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    f.apply(_sample(ax: 0, ay: 10, az: 100, gx: -10, gy: 0, gz: 20));
    final out = f.apply(_sample(ax: 10, ay: 20, az: 200, gx: 10, gy: 4, gz: 0));
    // window still filling: mean of the two samples
    expect(out.ax, 5);
    expect(out.ay, 15);
    expect(out.az, 150);
    expect(out.gx, 0);
    expect(out.gy, 2);
    expect(out.gz, 10);
  });

  test('averages each pressure sensor independently', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    f.apply(_sample(pressure: [0, 100, 60]));
    final out = f.apply(_sample(pressure: [10, 200, 0]));
    expect(out.pressure, [5, 150, 30]);
  });

  test('drops the oldest sample once the window is full', () {
    final f = ImuMovingAverageFilter(windowSize: 3);
    f.apply(_sample(ax: 30)); // this one must fall out
    f.apply(_sample(ax: 0));
    f.apply(_sample(ax: 0));
    final out = f.apply(_sample(ax: 30));
    // window is now [0, 0, 30] -> 10, not (30+0+0+30)/4
    expect(out.ax, 10);
  });

  test('rounds to the nearest int rather than truncating', () {
    final f = ImuMovingAverageFilter(windowSize: 2);
    final out = f.apply(_sample(ax: 1)); // mean 1
    expect(out.ax, 1);
    final out2 = f.apply(_sample(ax: 2)); // mean 1.5 -> 2
    expect(out2.ax, 2);
  });

  test('leaves pitch, roll, battery and charging untouched', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    f.apply(_sample(pitch: 1, roll: 1, battery: 50, charging: false));
    final out = f.apply(
      _sample(pitch: 9, roll: -9, battery: 80, charging: true),
    );
    // passed through from the newest sample, not averaged
    expect(out.pitch, 9);
    expect(out.roll, -9);
    expect(out.batteryPercent, 80);
    expect(out.isCharging, isTrue);
  });

  test('handles a shorter pressure array without crashing', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    f.apply(_sample(pressure: [10, 20, 30]));
    final out = f.apply(_sample(pressure: [20])); // only one sensor reported
    expect(out.pressure.length, 1);
    expect(out.pressure.first, 15);
  });

  test('reset clears the history', () {
    final f = ImuMovingAverageFilter(windowSize: 10);
    f.apply(_sample(ax: 100));
    f.reset();
    final out = f.apply(_sample(ax: 20));
    expect(out.ax, 20);
  });
}
