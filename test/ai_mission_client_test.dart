import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/missions/ai_mission_client.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// Noon on 1 November 2026, a Sunday.
final _today = DateTime(2026, 11, 1, 12);

GameActivity _round(
  String slug,
  DateTime at, {
  int seconds = 60,
  String? stage,
}) => GameActivity(slug: slug, stage: stage, seconds: seconds, at: at);

GameActivityLog _log(List<GameActivity> rounds) =>
    const GameActivityLog().addAll(rounds, today: _today);

Map<String, Object?> _stats(Map<String, Object?> body) =>
    body['stats']! as Map<String, Object?>;

/// A gait day with [steps] and about [walkingMin] minutes of walking on one
/// sole, which gives a cadence of steps / walkingMin.
DailyGait _gaitDay(
  String date, {
  required int steps,
  required int walkingMin,
}) => DailyGait(
  date: date,
  steps: steps,
  feet: {
    GaitFoot.left: FootGaitStats(
      contacts: steps ~/ 2,
      walkingMs: walkingMin * 60000,
    ),
  },
);

void main() {
  group('buildAiMissionBody', () {
    test('sends only the listed fields, and no gait while it is off', () {
      final body = buildAiMissionBody(
        today: _today,
        activity: _log([
          _round('fish', DateTime(2026, 10, 31, 9), seconds: 100),
          _round('fish', DateTime(2026, 10, 31, 10), seconds: 20),
          _round('laojie', DateTime(2026, 10, 31, 11), stage: 'lantern'),
          _round('pool', DateTime(2026, 10, 28, 9)),
          _round('quiz', DateTime(2026, 11, 1, 8)),
        ]),
        lastFootCheck: FootCheckRecord(
          rating: FootCheckRating.veryGood,
          takenAt: DateTime(2026, 10, 28, 20),
        ),
      );

      expect(body.keys.toSet(), {'day', 'stats'});
      expect(body['day'], '2026-11-01');
      final stats = _stats(body);
      expect(stats.keys.toSet(), {
        'games_yesterday',
        'games_7d',
        'foot_check_days_ago',
        'foot_check_rating',
      });
      expect(stats['games_yesterday'], [
        {'slug': 'fish', 'seconds': 100},
        {'slug': 'fish', 'seconds': 20},
        {'slug': 'laojie', 'stage': 'lantern', 'seconds': 60},
      ]);
      // The seven days before today: today's own round is not in it.
      expect(stats['games_7d'], [
        {'slug': 'fish', 'plays': 2},
        {'slug': 'laojie', 'plays': 1},
        {'slug': 'pool', 'plays': 1},
      ]);
      expect(stats['foot_check_days_ago'], 4);
      expect(stats['foot_check_rating'], 'veryGood');
    });

    test('nothing recorded gives empty lists and nulls', () {
      final body = buildAiMissionBody(
        today: _today,
        activity: const GameActivityLog(),
        lastFootCheck: null,
      );
      expect(_stats(body), {
        'games_yesterday': <Object>[],
        'games_7d': <Object>[],
        'foot_check_days_ago': null,
        'foot_check_rating': null,
      });
    });

    test('limits: 20 rounds from yesterday and 30 games from the week', () {
      final rounds = [
        for (var i = 0; i < 25; i++)
          _round('fish', DateTime(2026, 10, 31, 6, i), seconds: i),
        for (var i = 0; i < 40; i++)
          _round('g$i', DateTime(2026, 10, 30, 7, i % 60)),
      ];
      final stats = _stats(
        buildAiMissionBody(
          today: _today,
          activity: _log(rounds),
          lastFootCheck: null,
        ),
      );
      final yesterday = stats['games_yesterday']! as List;
      expect(yesterday, hasLength(20));
      // The newest twenty are kept.
      expect((yesterday.first as Map)['seconds'], 5);
      expect((yesterday.last as Map)['seconds'], 24);
      expect(stats['games_7d'], hasLength(30));
    });

    test('a stored round the server would refuse is not sent', () {
      final stats = _stats(
        buildAiMissionBody(
          today: _today,
          activity: _log([
            _round('Not Valid', DateTime(2026, 10, 31, 9)),
            _round('fish', DateTime(2026, 10, 31, 9), seconds: -5),
            _round('fish', DateTime(2026, 10, 31, 9), seconds: 20000),
            _round('pool', DateTime(2026, 10, 31, 9)),
          ]),
          lastFootCheck: null,
        ),
      );
      expect(stats['games_yesterday'], [
        {'slug': 'pool', 'seconds': 60},
      ]);
      expect(stats['games_7d'], [
        {'slug': 'fish', 'plays': 2},
        {'slug': 'pool', 'plays': 1},
      ]);
    });

    test('foot check days ago is clamped to what the server takes', () {
      int? days(DateTime takenAt) =>
          _stats(
                buildAiMissionBody(
                  today: _today,
                  activity: const GameActivityLog(),
                  lastFootCheck: FootCheckRecord(
                    rating: FootCheckRating.good,
                    takenAt: takenAt,
                  ),
                ),
              )['foot_check_days_ago']
              as int?;
      expect(days(DateTime(2026, 11, 1, 8)), 0);
      expect(days(DateTime(2024, 1, 1)), 365);
      // A phone clock that was ahead when the check was taken.
      expect(days(DateTime(2026, 12, 25)), 0);
    });

    test('gait is added only when asked for, from yesterday and the grade', () {
      final history = {
        '2026-10-31': _gaitDay('2026-10-31', steps: 4000, walkingMin: 40),
      };
      final without = _stats(
        buildAiMissionBody(
          today: _today,
          activity: const GameActivityLog(),
          lastFootCheck: null,
        ),
      );
      expect(without.containsKey('gait'), isFalse);

      final gait =
          _stats(
                buildAiMissionBody(
                  today: _today,
                  activity: const GameActivityLog(),
                  lastFootCheck: null,
                  gaitHistory: history,
                ),
              )['gait']
              as Map;
      expect(gait.keys.toSet(), {
        'steps',
        'cadence',
        'walking_min',
        'mobility_grade',
      });
      expect(gait['steps'], 4000);
      expect(gait['cadence'], 100.0);
      expect(gait['walking_min'], 40.0);
      // One week is too little to grade.
      expect(gait['mobility_grade'], isNull);
    });

    test('gait with nothing from yesterday and no grade is left out', () {
      final stats = _stats(
        buildAiMissionBody(
          today: _today,
          activity: const GameActivityLog(),
          lastFootCheck: null,
          gaitHistory: {
            '2026-10-20': _gaitDay('2026-10-20', steps: 3000, walkingMin: 30),
          },
        ),
      );
      expect(stats.containsKey('gait'), isFalse);
    });

    test('gait numbers are held to the server ranges', () {
      final gait =
          _stats(
                buildAiMissionBody(
                  today: _today,
                  activity: const GameActivityLog(),
                  lastFootCheck: null,
                  gaitHistory: {
                    '2026-10-31': _gaitDay(
                      '2026-10-31',
                      steps: 900000,
                      walkingMin: 10,
                    ),
                  },
                ),
              )['gait']
              as Map;
      expect(gait['steps'], 100000);
      expect(gait['cadence'], 250.0);
    });
  });

  group('parseAiMissionResponse', () {
    Map<String, Object?> ok() => {
      'mode': 'ai',
      'greeting': ' Hello ',
      'missions': <Object?>[
        {'id': 'foot_check', 'reason': 'a'},
        {'id': 'fish', 'reason': 'b'},
        {'id': 'laojie', 'reason': 'c'},
      ],
    };

    test('a good answer becomes an AI plan for the day', () {
      final plan = parseAiMissionResponse(ok(), day: '2026-11-01');
      expect(plan, isNotNull);
      expect(plan!.source, MissionPlanSource.ai);
      expect(plan.day, '2026-11-01');
      expect(plan.greeting, 'Hello');
      expect(plan.items, const [
        MissionPlanItem('foot_check', reason: 'a'),
        MissionPlanItem('fish', reason: 'b'),
        MissionPlanItem('laojie', reason: 'c'),
      ]);
    });

    test('anything else is null', () {
      Object? with_(void Function(Map<String, Object?>) edit) {
        final m = ok();
        edit(m);
        return m;
      }

      final bad = <Object?>[
        null,
        'ai',
        <Object?>[],
        {'mode': 'fallback', 'reason': 'busy'},
        with_((m) => m['mode'] = 'AI'),
        with_((m) => m['greeting'] = '  '),
        with_((m) => m['greeting'] = 5),
        with_((m) => m.remove('missions')),
        with_((m) => (m['missions']! as List).removeLast()),
        with_(
          (m) => (m['missions']! as List).add({'id': 'pool', 'reason': 'd'}),
        ),
        with_(
          (m) => (m['missions']! as List)[1] = {'id': 'racer', 'reason': 'x'},
        ),
        with_(
          (m) => (m['missions']! as List)[1] = {'id': 'golf', 'reason': 'x'},
        ),
        with_(
          (m) =>
              (m['missions']! as List)[1] = {'id': 'foot_check', 'reason': 'x'},
        ),
        with_((m) => (m['missions']! as List)[1] = {'id': 'fish'}),
        with_(
          (m) => (m['missions']! as List)[1] = {'id': 'fish', 'reason': ' '},
        ),
        with_((m) => (m['missions']! as List)[1] = 'fish'),
      ];
      for (final data in bad) {
        expect(
          parseAiMissionResponse(data, day: '2026-11-01'),
          isNull,
          reason: '$data',
        );
      }
    });

    test('every mission the server may name is one the app knows', () {
      // The server's list, copied here on purpose: if either side changes,
      // this fails.
      const server = [
        'foot_check',
        'walkgroup',
        'bike',
        'canoe',
        'fish',
        'ski',
        'hop',
        'rhythm',
        'quiz',
        'pool',
        'laojie',
      ];
      expect(MissionCatalog.ids, server);
    });
  });

  group('SupabaseAiMissionClient', () {
    Future<MissionPlan?> ask(AiMissionInvoke invoke) =>
        SupabaseAiMissionClient(invoke: invoke).plan(
          today: _today,
          activity: const GameActivityLog(),
          lastFootCheck: null,
        );

    test('sends the body and turns the answer into a plan', () async {
      Map<String, Object?>? sent;
      final plan = await ask((body) async {
        sent = body;
        return {
          'mode': 'ai',
          'greeting': 'Hi',
          'missions': [
            {'id': 'fish', 'reason': 'a'},
            {'id': 'pool', 'reason': 'b'},
            {'id': 'ski', 'reason': 'c'},
          ],
        };
      });
      expect(sent!['day'], '2026-11-01');
      expect(plan?.source, MissionPlanSource.ai);
      expect(plan?.items.map((i) => i.id), ['fish', 'pool', 'ski']);
    });

    test(
      'a fallback answer, a null answer and an error are all null',
      () async {
        expect(
          await ask(
            (_) async => {'mode': 'fallback', 'reason': 'not_configured'},
          ),
          isNull,
        );
        expect(await ask((_) async => null), isNull);
        expect(await ask((_) async => throw Exception('401')), isNull);
      },
    );

    testWidgets('waits eight seconds and no longer', (tester) async {
      final never = Completer<Object?>();
      final answer = ask((_) => never.future);
      var done = false;
      unawaited(answer.whenComplete(() => done = true));
      await tester.pump(const Duration(seconds: 7));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(await answer, isNull);
    });
  });
}
