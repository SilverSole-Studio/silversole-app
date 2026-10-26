import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

void main() {
  final takenAt = DateTime(2026, 10, 26, 9, 30);

  group('FootCheckRecord', () {
    test('survives a JSON round trip', () {
      final record = FootCheckRecord(
        rating: FootCheckRating.veryGood,
        takenAt: takenAt,
      );
      expect(FootCheckRecord.tryDecode(record.encode()), record);
    });

    test(
      'anything unreadable decodes to null rather than a made-up result',
      () {
        expect(FootCheckRecord.tryDecode(null), isNull);
        expect(FootCheckRecord.tryDecode('not json'), isNull);
        expect(
          FootCheckRecord.tryDecode('{"rating":"great","taken_at":1}'),
          isNull,
        );
        expect(FootCheckRecord.tryDecode('{"rating":"good"}'), isNull);
      },
    );

    test('isOnDay compares the local calendar day', () {
      final record = FootCheckRecord(
        rating: FootCheckRating.good,
        takenAt: takenAt,
      );
      expect(record.isOnDay(DateTime(2026, 10, 26, 23, 59)), isTrue);
      expect(record.isOnDay(DateTime(2026, 10, 27, 0, 1)), isFalse);
    });
  });

  group('FootCheckRecord.fromReport', () {
    const balanced = FootLoadBalance(foreRatio: 0.40, medialRatio: 0.50);

    test('keeps the band of a check measured on a sole', () {
      final record = FootCheckRecord.fromReport(
        const FootCheckReport(
          balance: balanced,
          samples: 300,
          collected: Duration(seconds: 60),
        ),
        takenAt,
      );
      expect(
        record,
        FootCheckRecord(rating: balanced.rating, takenAt: takenAt),
      );
    });

    test('keeps nothing when there was too little data', () {
      expect(FootCheckRecord.fromReport(FootCheckReport.empty, takenAt), isNull);
    });

    test('keeps nothing computed from a sample clip', () {
      expect(
        FootCheckRecord.fromReport(
          const FootCheckReport(
            balance: balanced,
            samples: 300,
            collected: Duration(seconds: 60),
            fromSample: true,
          ),
          takenAt,
        ),
        isNull,
      );
    });
  });

  group('lastFootCheckProvider', () {
    test('starts empty when nothing was ever saved', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(lastFootCheckProvider), isNull);
      await pumpEventQueue();
      expect(container.read(lastFootCheckProvider), isNull);
    });

    test('loads the saved result', () async {
      final record = FootCheckRecord(
        rating: FootCheckRating.excellent,
        takenAt: takenAt,
      );
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.lastFootCheck.value: record.encode(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(lastFootCheckProvider);
      await pumpEventQueue();
      expect(container.read(lastFootCheckProvider), record);
    });

    test('record() persists and a slow load never overwrites it', () async {
      final old = FootCheckRecord(
        rating: FootCheckRating.good,
        takenAt: DateTime(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.lastFootCheck.value: old.encode(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fresh = FootCheckRecord(
        rating: FootCheckRating.excellent,
        takenAt: takenAt,
      );
      container.read(lastFootCheckProvider);
      await container.read(lastFootCheckProvider.notifier).record(fresh);
      await pumpEventQueue();

      expect(container.read(lastFootCheckProvider), fresh);
      final prefs = await SharedPreferences.getInstance();
      expect(
        FootCheckRecord.tryDecode(
          prefs.getString(LocalSavableKey.lastFootCheck.value),
        ),
        fresh,
      );
    });
  });
}
