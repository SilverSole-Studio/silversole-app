import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';

/// Feeds the same reading [count] times — the tally only keeps means, so one
/// repeated reading is enough to set them.
FootPressureTally _tally(List<int> reading, {int count = 60}) {
  final tally = FootPressureTally();
  for (var i = 0; i < count; i++) {
    tally.add(reading);
  }
  return tally;
}

void main() {
  group('tally', () {
    test('too few samples cannot be reported on', () {
      final tally = _tally([100, 100, 300], count: 19);
      expect(tally.samples, 19);
      expect(tally.balance, isNull);
    });

    test('a sole that never carried load cannot be reported on', () {
      // Held in the air for the whole minute.
      expect(_tally([0, 0, 0]).balance, isNull);
    });

    test('short readings are ignored rather than averaged in', () {
      final tally = FootPressureTally();
      for (var i = 0; i < 30; i++) {
        tally.add([1, 2]);
      }
      expect(tally.samples, 0);
      expect(tally.balance, isNull);
    });

    test('the ratios come out of the channel means', () {
      // 200 forefoot (120 medial + 80 lateral) against 300 heel.
      final balance = _tally([120, 80, 300]).balance!;
      expect(balance.foreRatio, closeTo(200 / 500, 1e-9));
      expect(balance.rearRatio, closeTo(300 / 500, 1e-9));
      expect(balance.medialRatio, closeTo(120 / 200, 1e-9));
      expect(balance.lateralRatio, closeTo(80 / 200, 1e-9));
    });
  });

  group('bias', () {
    test('a textbook 40/60 split with an even forefoot is balanced', () {
      const balance = FootLoadBalance(foreRatio: 0.40, medialRatio: 0.50);
      expect(balance.foreAft, ForeAftBias.balanced);
      expect(balance.side, MedialLateralBias.balanced);
      expect(balance.rating, FootCheckRating.excellent);
    });

    test('the tolerance edges still count as balanced', () {
      const forward = FootLoadBalance(foreRatio: 0.50, medialRatio: 0.50);
      const backward = FootLoadBalance(foreRatio: 0.30, medialRatio: 0.50);
      expect(forward.foreAft, ForeAftBias.balanced);
      expect(backward.foreAft, ForeAftBias.balanced);
      expect(
        const FootLoadBalance(foreRatio: 0.4, medialRatio: 0.62).side,
        MedialLateralBias.balanced,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.4, medialRatio: 0.38).side,
        MedialLateralBias.balanced,
      );
    });

    test('leaning past the tolerance is named by direction', () {
      expect(
        const FootLoadBalance(foreRatio: 0.70, medialRatio: 0.5).foreAft,
        ForeAftBias.forefoot,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.15, medialRatio: 0.5).foreAft,
        ForeAftBias.rearfoot,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.4, medialRatio: 0.80).side,
        MedialLateralBias.medial,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.4, medialRatio: 0.20).side,
        MedialLateralBias.lateral,
      );
    });
  });

  group('rating', () {
    test('one axis off is very good and both off is good', () {
      expect(
        const FootLoadBalance(foreRatio: 0.70, medialRatio: 0.50).rating,
        FootCheckRating.veryGood,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.40, medialRatio: 0.85).rating,
        FootCheckRating.veryGood,
      );
      expect(
        const FootLoadBalance(foreRatio: 0.70, medialRatio: 0.85).rating,
        FootCheckRating.good,
      );
    });

    test('every band carries the strings the report needs', () {
      for (final bias in ForeAftBias.values) {
        expect(bias.summaryKey, isNotEmpty);
      }
      for (final bias in MedialLateralBias.values) {
        expect(bias.summaryKey, isNotEmpty);
      }
    });
  });
}
