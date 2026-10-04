import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';

void main() {
  test('the bands run weakest first and fill one segment more each', () {
    expect(FootCheckRating.values, [
      FootCheckRating.good,
      FootCheckRating.veryGood,
      FootCheckRating.excellent,
    ]);
    expect(FootCheckRating.good.level, 1);
    expect(FootCheckRating.veryGood.level, 2);
    expect(FootCheckRating.excellent.level, 3);
  });

  test('every band carries its label', () {
    for (final rating in FootCheckRating.values) {
      expect(rating.labelKey, isNotEmpty);
    }
  });
}
