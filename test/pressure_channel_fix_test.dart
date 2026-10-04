import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/pressure_channel_fix.dart';

/// Builds one live IMU notify payload the way the firmware packs it: 6 int16
/// axes, 2 float32 angles, 3 int16 pressures, then battery and charging.
List<int> _imuPacket(List<int> pressure) {
  final d = ByteData(28);
  for (var i = 0; i < 6; i++) {
    d.setInt16(i * 2, i + 1, Endian.little);
  }
  d.setFloat32(12, 1, Endian.little);
  d.setFloat32(16, 2, Endian.little);
  for (var i = 0; i < 3; i++) {
    d.setInt16(20 + i * 2, pressure[i], Endian.little);
  }
  d.setUint8(26, 90);
  d.setUint8(27, 0);
  return d.buffer.asUint8List();
}

void main() {
  test('the heel and big-toe-ball readings trade places', () {
    // Wire order on this board: [heel, little toe, hallux].
    expect(fixPressureChannels([100, 200, 300]), [300, 200, 100]);
  });

  test('applying it twice is the wire order again', () {
    expect(fixPressureChannels(fixPressureChannels([1, 2, 3])), [1, 2, 3]);
  });

  test('a short reading is left alone rather than reordered', () {
    expect(fixPressureChannels([]), isEmpty);
    expect(fixPressureChannels([7]), [7]);
    expect(fixPressureChannels([7, 8]), [7, 8]);
  });

  test('extra sensors keep their order behind the first three', () {
    expect(fixPressureChannels([1, 2, 3, 4, 5]), [3, 2, 1, 4, 5]);
  });

  test('a decoded live packet carries the corrected order', () {
    final imu = BleConnectionService().parseImuNotify(
      _imuPacket([100, 200, 300]),
    );
    expect(imu.pressure, [300, 200, 100]);
    // The rest of the packet is untouched by the workaround.
    expect(imu.ax, 1);
    expect(imu.batteryPercent, 90);
    expect(imu.isCharging, isFalse);
  });
}
