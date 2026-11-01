import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';
import 'helpers/translations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount, every case: EasyLocalization keeps global state, so a second
  // mount in the same file never leaves its loading state.
  testWidgets("today's planned missions, done only when the app knows it", (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDailyMissionsBottomSheet(context),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/foot-check',
          builder: (_, _) => const Scaffold(body: Text('at foot check')),
        ),
        GoRoute(
          path: '/game-webview',
          builder: (_, state) {
            final extra = state.extra as Map;
            return Scaffold(body: Text('at game ${extra['url']}'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              routerConfig: router,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    Future<void> openSheet() async {
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
    }

    await openSheet();

    // Never checked, nothing played: three missions, the foot check first.
    final plan = container.read(todayMissionPlanProvider).requireValue;
    expect(plan.items, hasLength(3));
    expect(plan.items.first.id, MissionCatalog.footCheck);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(find.text('Done'), findsNothing);
    expect(find.text('3 left today'), findsOneWidget);
    expect(find.text('Measure foot pressure once'), findsOneWidget);
    // The other two are games from the catalog, each with its own title.
    final games = [for (final i in plan.items.skip(1)) i.id];
    expect(games.every(MissionCatalog.isGame), isTrue);
    for (final id in games) {
      expect(find.text(_title[id]!), findsOneWidget, reason: id);
    }

    // No pedometer, so no walking mission and no step counts; no rewards; no
    // AI wording on a plan made by rules.
    expect(find.textContaining('steps'), findsNothing);
    expect(find.textContaining('+'), findsNothing);
    expect(find.textContaining('Coins'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);

    // The first row is the foot check: its button opens the foot check.
    await tester.tap(find.widgetWithText(FilledButton, 'Go').first);
    await tester.pumpAndSettle();
    expect(find.text('at foot check'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await openSheet();

    // A round of a game that is not today's mission completes nothing.
    final other = MissionCatalog.gameIds.firstWhere(
      (id) => !games.contains(id),
    );
    await container
        .read(gameActivityProvider.notifier)
        .record(GameActivity(slug: other, seconds: 30, at: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(find.text('3 left today'), findsOneWidget);

    // A round of today's first game completes that row only.
    await container
        .read(gameActivityProvider.notifier)
        .record(
          GameActivity(slug: games.first, seconds: 30, at: DateTime.now()),
        );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(2));
    expect(find.text('Done'), findsNWidgets(2), reason: 'subtitle + pill');
    expect(find.text('2 left today'), findsOneWidget);

    // A foot check finished today completes the measuring mission.
    await container
        .read(lastFootCheckProvider.notifier)
        .record(
          FootCheckRecord(
            rating: FootCheckRating.good,
            takenAt: DateTime.now(),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Go'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(4));
    expect(find.text('1 left today'), findsOneWidget);

    // The open mission's button goes to that game, under the games' site.
    await tester.tap(find.widgetWithText(FilledButton, 'Go'));
    await tester.pumpAndSettle();
    final path = MissionCatalog.gamePath(games.last, DateTime.now());
    expect(find.text('at game ${Constants.gameUrl}$path'), findsOneWidget);

    // Back home the sheet reopens with the same plan, not a new draw.
    router.pop();
    await tester.pumpAndSettle();
    await openSheet();
    expect(
      container.read(todayMissionPlanProvider).requireValue.items,
      plan.items,
    );
    expect(find.text('Measure foot pressure once'), findsOneWidget);
    expect(find.text('1 left today'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}

const _title = {
  'walkgroup': 'Play a round of Group Walk',
  'bike': 'Play a round of Chu Bike',
  'canoe': 'Play a round of Chu Canoe',
  'fish': 'Play a round of Chu Fish Catch',
  'ski': 'Play a round of Chu Ski',
  'hop': 'Play a round of Chu Hop',
  'rhythm': 'Play a round of Rhythm Steps',
  'quiz': 'Play a round of Foot Quiz',
  'pool': 'Play a round of Pool',
  'laojie': 'Play one stage of Step into Old Street',
};
