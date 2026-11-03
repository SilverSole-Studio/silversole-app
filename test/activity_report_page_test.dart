import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/models/mobility_card.dart';
import 'package:silversole/shared/pages/activity_report_page.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/widgets/report/activity_report_card.dart';

import 'helpers/translations.dart';

class _Check extends LastFootCheckNotifier {
  _Check(this._value);

  final FootCheckRecord? _value;

  @override
  FootCheckRecord? build() => _value;
}

class _Games extends GameActivityNotifier {
  _Games(this._value);

  final GameActivityLog _value;

  @override
  GameActivityLog build() => _value;
}

class _History extends GaitHistoryNotifier {
  _History(this._value);

  final Map<String, DailyGait> _value;

  @override
  Map<String, DailyGait> build() => _value;
}

typedef _Shared = ({Uint8List png, String name});

Future<void> _pump(
  WidgetTester tester, {
  FootCheckRecord? check,
  GameActivityLog games = const GameActivityLog(),
  Map<String, DailyGait> history = const {},
  bool realGait = false,
  MobilityCard? mobility,
  Locale? locale,
  Size logicalSize = const Size(400, 3000),
  List<_Shared>? shared,
  Future<void> Function(Uint8List, String)? share,
}) async {
  // Tall enough that the whole page is on screen without scrolling.
  tester.view.physicalSize = logicalSize * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await EasyLocalization.ensureInitialized();
  final app = EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
    path: 'assets/translations/strings.csv',
    assetLoader: CsvAssetLoader(),
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: appTheme(Brightness.light),
        home: ActivityReportPage(
          share:
              share ?? (png, name) async => shared?.add((png: png, name: name)),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastFootCheckProvider.overrideWith(() => _Check(check)),
          gameActivityProvider.overrideWith(() => _Games(games)),
          gaitHistoryProvider.overrideWith(() => _History(history)),
          realGaitEnabledProvider.overrideWithValue(realGait),
          mobilityCardProvider.overrideWith((ref) => mobility),
        ],
        child: app,
      ),
    ),
  );
  await settleTranslations(tester);
}

Finder _inCard(Finder matching) =>
    find.descendant(of: find.byType(ActivityReportCard), matching: matching);

FootCheckRecord _check() => FootCheckRecord(
  rating: FootCheckRating.veryGood,
  takenAt: DateTime.now(),
  foreRatio: 0.38,
  medialRatio: 0.55,
);

GameActivityLog _games() => const GameActivityLog().addAll([
  GameActivity(slug: 'fish', seconds: 300, at: DateTime.now()),
  GameActivity(slug: 'fish', seconds: 300, at: DateTime.now()),
  GameActivity(slug: 'quiz', seconds: 120, at: DateTime.now()),
], today: DateTime.now());

Map<String, DailyGait> _history() {
  final now = DateTime.now();
  final key = gaitDateKey(now);
  return {
    key: DailyGait(
      date: key,
      steps: 1200,
      feet: const {GaitFoot.left: FootGaitStats(walkingMs: 600000)},
    ),
  };
}

const _graded = MobilityGraded(
  weekStart: '2026-11-02',
  isCurrentWeek: true,
  grade: MobilityGrade.d,
  changes: [
    MobilityChange(metric: MobilityMetric.dailySteps, better: false),
    MobilityChange(metric: MobilityMetric.doubleSupport, better: false),
  ],
  rows: [
    MobilityMetricRow(
      metric: MobilityMetric.dailySteps,
      grade: MobilityGrade.d,
      trend: [],
    ),
    MobilityMetricRow(
      metric: MobilityMetric.doubleSupport,
      grade: MobilityGrade.c,
      trend: [],
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('en'), Locale('zh', 'TW')]) {
    testWidgets('every section at once lays out without overflow ($locale)', (
      tester,
    ) async {
      await _pump(
        tester,
        check: _check(),
        games: _games(),
        history: _history(),
        realGait: true,
        mobility: _graded,
        locale: locale,
      );

      expect(tester.takeException(), isNull);
      for (final letter in ['D', 'C']) {
        expect(_inCard(find.text(letter)), findsWidgets);
      }
      expect(
        tester.getSize(find.byType(ActivityReportCard)).width,
        ActivityReportCard.width,
      );
    });
  }

  testWidgets('mobility needs the real-gait switch', (tester) async {
    await _pump(tester, check: _check(), mobility: _graded, realGait: false);
    expect(_inCard(find.text('Mobility')), findsNothing);
  });

  testWidgets('nothing recorded: a plain notice and Share is off', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(ActivityReportPage.emptyKey), findsOneWidget);
    expect(find.text('Nothing to share yet'), findsOneWidget);
    expect(find.byType(ActivityReportCard), findsNothing);
    final share = tester.widget<FilledButton>(
      find.byKey(ActivityReportPage.shareButtonKey),
    );
    expect(share.onPressed, isNull);
  });

  testWidgets('a foot check and games: both sections are on the picture', (
    tester,
  ) async {
    await _pump(tester, check: _check(), games: _games());

    expect(_inCard(find.text('Foot pressure check')), findsOneWidget);
    expect(_inCard(find.text('Game exercise')), findsOneWidget);
    expect(_inCard(find.text('Foot check result')), findsOneWidget);
    expect(_inCard(find.text('Overall')), findsNothing);
    expect(_inCard(find.text('Very good')), findsOneWidget);
    expect(find.byKey(ActivityReportCard.noMedialKey), findsNothing);
    expect(_inCard(find.text('Forefoot 38%')), findsOneWidget);
    expect(_inCard(find.text('45% Lateral')), findsOneWidget);
    expect(_inCard(find.text('Chu Fish Catch')), findsOneWidget);
    expect(_inCard(find.text('2 times')), findsOneWidget);
    expect(
      _inCard(find.text('Active on 1 days with 12 minutes in total')),
      findsOneWidget,
    );
    // Nothing from gait without the switch.
    expect(_inCard(find.text('Walking')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(ActivityReportPage.shareButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a heel-only check shows one line instead of the inner split', (
    tester,
  ) async {
    await _pump(
      tester,
      check: FootCheckRecord.fromReport(
        const FootCheckReport(
          balance: FootLoadBalance(
            foreRatio: 0,
            medialRatio: FootLoadBalance.medialTarget,
          ),
          samples: 300,
          collected: Duration(seconds: 60),
        ),
        DateTime.now(),
      ),
    );

    expect(_inCard(find.text('Forefoot 0%')), findsOneWidget);
    expect(_inCard(find.textContaining('Medial')), findsNothing);
    expect(
      _inCard(
        find.text('Too little forefoot load for an inner and outer split'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mobility letters share one neutral fill whatever the grade', (
    tester,
  ) async {
    Future<Set<Color?>> fills(MobilityGrade main, MobilityGrade row) async {
      await _pump(
        tester,
        realGait: true,
        history: _history(),
        mobility: MobilityGraded(
          weekStart: '2026-11-02',
          isCurrentWeek: true,
          grade: main,
          changes: const [],
          rows: [
            MobilityMetricRow(
              metric: MobilityMetric.cadence,
              grade: row,
              trend: const [],
            ),
          ],
        ),
      );
      return {
        for (final box in tester.widgetList<Container>(
          find.byKey(ActivityReportCard.gradeBoxKey),
        ))
          (box.decoration as BoxDecoration).color,
      };
    }

    final mixed = await fills(MobilityGrade.a, MobilityGrade.e);
    expect(mixed, hasLength(1));
    expect(_inCard(find.text('A')), findsOneWidget);
    expect(_inCard(find.text('E')), findsOneWidget);
    expect(
      mixed.single,
      appTheme(Brightness.light).colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('unticking games takes them off the picture', (tester) async {
    await _pump(tester, check: _check(), games: _games());

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Game exercise'));
    await tester.pumpAndSettle();

    expect(_inCard(find.text('Game exercise')), findsNothing);
    expect(_inCard(find.text('Chu Fish Catch')), findsNothing);
    expect(_inCard(find.text('Foot pressure check')), findsOneWidget);
  });

  testWidgets('only the sections that have data are offered', (tester) async {
    await _pump(tester, check: _check());

    expect(
      find.widgetWithText(CheckboxListTile, 'Foot pressure check'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Game exercise'),
      findsNothing,
    );
    expect(find.widgetWithText(CheckboxListTile, 'Walking'), findsNothing);
  });

  testWidgets('no name is printed until one is typed', (tester) async {
    await _pump(tester, check: _check());

    expect(find.byKey(ActivityReportCard.nicknameKey), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );

    await tester.enterText(find.byType(TextField), 'Grandma Wang');
    await tester.pump();
    expect(_inCard(find.text('Name: Grandma Wang')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.byKey(ActivityReportCard.nicknameKey), findsNothing);
  });

  testWidgets('the name is capped at 12 characters', (tester) async {
    await _pump(tester, check: _check());

    await tester.enterText(
      find.byType(TextField),
      'abcdefghijklmnopqrstuvwxyz',
    );
    await tester.pump();
    expect(_inCard(find.text('Name: abcdefghijkl')), findsOneWidget);
  });

  testWidgets('the disclaimer is on the picture even with nothing ticked', (
    tester,
  ) async {
    await _pump(tester, check: _check());
    expect(
      _inCard(find.textContaining('is not a medical diagnosis')),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Foot pressure check'),
    );
    await tester.pumpAndSettle();
    expect(
      _inCard(find.textContaining('is not a medical diagnosis')),
      findsOneWidget,
    );
    // Nothing left to share.
    expect(
      tester
          .widget<FilledButton>(find.byKey(ActivityReportPage.shareButtonKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets('gait is left out while the real-gait switch is off', (
    tester,
  ) async {
    await _pump(tester, history: _history(), realGait: false);
    // A history alone, with nothing else, gives nothing to share.
    expect(find.byKey(ActivityReportPage.emptyKey), findsOneWidget);
  });

  testWidgets('gait appears once the switch is on', (tester) async {
    await _pump(tester, history: _history(), realGait: true);

    expect(_inCard(find.text('Walking')), findsOneWidget);
    expect(_inCard(find.text('Steps each day')), findsOneWidget);
    expect(_inCard(find.text('1200')), findsOneWidget);
    expect(_inCard(find.text('120 steps per minute')), findsOneWidget);
    expect(_inCard(find.text('10 minutes')), findsOneWidget);
  });

  testWidgets('Share hands a PNG of the picture to the share function', (
    tester,
  ) async {
    final shared = <_Shared>[];
    await _pump(tester, check: _check(), games: _games(), shared: shared);

    await tester.tap(find.byKey(ActivityReportPage.shareButtonKey));
    // Drawing the picture is real engine work, outside the fake-async zone.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(shared, hasLength(1));
    final png = shared.single.png;
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    // 360 logical px at 3x: the width sits in the IHDR chunk.
    final width = ByteData.sublistView(png, 16, 20).getUint32(0);
    expect(width, 1080);
    expect(
      shared.single.name,
      matches(RegExp(r'^activity_record_\d{8}\.png$')),
    );
  });

  testWidgets('on a narrow phone the picture is still 1080 px wide', (
    tester,
  ) async {
    final shared = <_Shared>[];
    await _pump(
      tester,
      check: _check(),
      games: _games(),
      shared: shared,
      logicalSize: const Size(390, 844),
    );

    await tester.ensureVisible(find.byKey(ActivityReportPage.shareButtonKey));
    await tester.tap(find.byKey(ActivityReportPage.shareButtonKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(shared, hasLength(1));
    final png = shared.single.png;
    expect(ByteData.sublistView(png, 16, 20).getUint32(0), 1080);
  });

  testWidgets('a share that fails says so and Share works again', (
    tester,
  ) async {
    await _pump(
      tester,
      check: _check(),
      share: (_, _) async => throw StateError('no share sheet'),
    );

    await tester.tap(find.byKey(ActivityReportPage.shareButtonKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.text('Could not share. Please try again.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(ActivityReportPage.shareButtonKey))
          .onPressed,
      isNotNull,
    );
  });
}
