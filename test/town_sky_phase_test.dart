import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/widgets/theme_two/town_kit.dart';

void main() {
  SkyPhase at(int h, [int m = 0]) => skyPhaseFor(DateTime(2026, 11, 11, h, m));

  test('day is 6:00 to 16:59', () {
    expect(at(6), SkyPhase.day);
    expect(at(12), SkyPhase.day);
    expect(at(16, 59), SkyPhase.day);
  });
  test('dusk is 17:00 to 18:59', () {
    expect(at(17), SkyPhase.dusk);
    expect(at(18, 59), SkyPhase.dusk);
  });
  test('night is 19:00 to 5:59', () {
    expect(at(19), SkyPhase.night);
    expect(at(23, 59), SkyPhase.night);
    expect(at(0), SkyPhase.night);
    expect(at(5, 59), SkyPhase.night);
  });
  testWidgets('TownSky builds in every phase', (tester) async {
    for (final p in SkyPhase.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(width: 390, child: TownSky(phase: p)),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
