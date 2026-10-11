import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/firmware_version.dart';

void main() {
  test('a release candidate is older than its release', () {
    expect(compareFirmware('0.4.0-rc.1', '0.4.0'), FirmwareComparison.upgrade);
    expect(
      compareFirmware('0.4.0', '0.4.0-rc.1'),
      FirmwareComparison.downgrade,
    );
  });

  test('versions compare numerically, not as text', () {
    expect(compareFirmware('0.9.0', '0.10.0'), FirmwareComparison.upgrade);
    expect(
      compareFirmware('0.4.0-rc.9', '0.4.0-rc.10'),
      FirmwareComparison.upgrade,
    );
  });

  test('equal versions are the same', () {
    expect(compareFirmware('0.4.0', '0.4.0'), FirmwareComparison.same);
  });

  test('anything that is not semver compares as unknown', () {
    expect(compareFirmware('v0.4.0', '0.4.0'), isNull);
    expect(compareFirmware('0.4.0', 'latest'), isNull);
    expect(compareFirmware(null, '0.4.0'), isNull);
  });

  test('surrounding whitespace is tolerated', () {
    expect(parseFirmwareVersion(' 0.4.0 '), isNotNull);
  });
}
