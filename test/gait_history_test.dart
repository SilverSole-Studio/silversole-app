import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';

DailyGait _day(String date, int steps) => DailyGait(date: date, steps: steps);

void main() {
  final today = DateTime(2026, 11, 2, 10);

  test('deltas for a stored day add to it, new days are added', () {
    final merged = mergeGaitHistory(
      {'2026-11-01': _day('2026-11-01', 100)},
      [_day('2026-11-01', 50), _day('2026-11-02', 30)],
      today,
    );
    expect(merged['2026-11-01']?.steps, 150);
    expect(merged['2026-11-02']?.steps, 30);
  });

  test('keeps ninety days counting today and drops the rest', () {
    final merged = mergeGaitHistory(
      {
        '2026-08-04': _day('2026-08-04', 1), // 90 days before today: dropped
        '2026-08-05': _day('2026-08-05', 1), // 89 days before: kept
      },
      const [],
      today,
    );
    expect(merged.keys, ['2026-08-05']);
  });

  test('round-trips, and anything unreadable comes back empty', () {
    final history = {
      '2026-11-01': _day('2026-11-01', 100),
      '2026-11-02': _day('2026-11-02', 30),
    };
    final decoded = decodeGaitHistory(encodeGaitHistory(history));
    expect(decoded.keys, history.keys);
    expect(decoded['2026-11-01']?.steps, 100);

    expect(decodeGaitHistory(null), isEmpty);
    expect(decodeGaitHistory('not json'), isEmpty);
    expect(decodeGaitHistory('{"a":1}'), isEmpty);
  });

  test('one unreadable day does not take the others with it', () {
    final decoded = decodeGaitHistory(
      '[{"date":"2026-11-01","steps":5,"feet":{},'
      '"double_support_ms":0,"both_walking_ms":0},{"date":3}]',
    );
    expect(decoded.keys, ['2026-11-01']);
  });
}
