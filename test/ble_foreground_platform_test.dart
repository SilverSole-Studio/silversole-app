import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';

void main() {
  test('BLE runs on both phones and nowhere else', () {
    expect(bleOrchestrationSupported(TargetPlatform.android), isTrue);
    expect(bleOrchestrationSupported(TargetPlatform.iOS), isTrue);
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(bleOrchestrationSupported(p), isFalse, reason: '$p');
    }
  });
}
