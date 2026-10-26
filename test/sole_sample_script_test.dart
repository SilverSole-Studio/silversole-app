import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_sample_script.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

const _sample = ImuNotifyDataModel(
  ax: 1,
  ay: -2,
  az: 1000,
  gx: 3,
  gy: -4,
  gz: 5,
  pitch: 3.5,
  roll: -12.25,
  pressure: [900, 120, 1500],
  batteryPercent: 77,
  isCharging: true,
);

/// Splits the script into its two JSON payloads and the primary literal.
({Map<String, dynamic> sole, Map<String, dynamic> legacy, String primary})
_parse(String script) {
  final match = RegExp(
    r'^window\.onSoleSample \? onSoleSample\((.*)\) : '
    r'\((true|false) && window\.onImuData && onImuData\((.*)\)\)$',
  ).firstMatch(script);
  expect(match, isNotNull, reason: 'unexpected script shape: $script');
  return (
    sole: jsonDecode(match!.group(1)!) as Map<String, dynamic>,
    primary: match.group(2)!,
    legacy: jsonDecode(match.group(3)!) as Map<String, dynamic>,
  );
}

void main() {
  test('is exactly the compat expression around one payload', () {
    final script = soleSampleScript(
      _sample,
      foot: FootSide.left,
      primary: true,
    );
    final json = jsonEncode({
      ..._sample.toJson(),
      'foot': 'left',
      'primary': true,
    });
    expect(
      script,
      'window.onSoleSample ? onSoleSample($json) : '
      '(true && window.onImuData && onImuData($json))',
    );
  });

  test('carries the raw sample fields under the firmware JSON names', () {
    final parsed = _parse(
      soleSampleScript(_sample, foot: FootSide.right, primary: false),
    );
    expect(parsed.sole, {
      'ax': 1,
      'ay': -2,
      'az': 1000,
      'gx': 3,
      'gy': -4,
      'gz': 5,
      'pitch': 3.5,
      'roll': -12.25,
      'pressure': [900, 120, 1500],
      'battery_percent': 77,
      'is_charging': true,
      'foot': 'right',
      'primary': false,
    });
    expect(parsed.legacy, parsed.sole);
  });

  test('foot is left, right or null', () {
    expect(
      _parse(
        soleSampleScript(_sample, foot: FootSide.left, primary: true),
      ).sole['foot'],
      'left',
    );
    expect(
      _parse(
        soleSampleScript(_sample, foot: FootSide.right, primary: true),
      ).sole['foot'],
      'right',
    );
    final unassigned = _parse(
      soleSampleScript(_sample, foot: null, primary: true),
    ).sole;
    expect(unassigned.containsKey('foot'), isTrue);
    expect(unassigned['foot'], isNull);
  });

  test('only the primary sole reaches the legacy onImuData', () {
    expect(
      _parse(soleSampleScript(_sample, foot: null, primary: true)).primary,
      'true',
    );
    expect(
      _parse(soleSampleScript(_sample, foot: null, primary: false)).primary,
      'false',
    );
    expect(
      _parse(
        soleSampleScript(_sample, foot: null, primary: false),
      ).sole['primary'],
      false,
    );
  });

  group('gameOriginGuard', () {
    test('runs the script only on the given origin', () {
      expect(
        gameOriginGuard('onSoleSample({})', 'https://h5.example.com'),
        'if(location.origin==="https://h5.example.com"){onSoleSample({})}',
      );
    });

    test('quotes the origin as a JS string literal', () {
      expect(
        gameOriginGuard('x()', 'https://a"b'),
        startsWith(r'if(location.origin==="https://a\"b"){'),
      );
    });
  });
}
