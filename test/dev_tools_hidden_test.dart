import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/subscription_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/dev_tools_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';
import 'package:silversole/shared/widgets/gait/gait_raw_record_button.dart';
import 'helpers/translations.dart';

class _SignedOut extends AuthUserNotifier {
  @override
  UserData? build() => null;
}

class _Settings extends SettingsNotifier {
  _Settings(this.devMode);
  final bool devMode;

  @override
  AppSettings build() => AppSettings(firmwareDevMode: devMode);
}

/// Engineering-only controls must not show in a release build: not the raw
/// gait recording button, not the "pretend subscribed" switch. Only developer
/// mode (seven taps on the firmware title) brings them back.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a release build hides dev tools unless developer mode is on', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(412, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final devMode = ValueNotifier(false);
    addTearDown(devMode.dispose);
    final page = ValueNotifier<Widget>(const SubscriptionPage());
    addTearDown(page.dispose);
    final mascot = ValueNotifier(false);
    addTearDown(mascot.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Pretend to be a release build.
          debugBuildProvider.overrideWithValue(false),
          authUserProvider.overrideWith(_SignedOut.new),
          settingsProvider.overrideWith(() => _Settings(devMode.value)),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => ValueListenableBuilder<Widget>(
              valueListenable: page,
              builder: (_, current, _) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                home: current,
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    final fakeSwitch = find.byKey(const Key('fake_subscription_switch'));

    // Release, developer mode off: nothing engineering-looking.
    expect(find.byType(SubscriptionPage), findsOneWidget);
    expect(fakeSwitch, findsNothing);
    expect(find.text('測試用：假裝已訂閱'), findsNothing);
    for (final p in const [AnalyticsPage(), AnalyticsPageT2()]) {
      page.value = p;
      await tester.pumpAndSettle();
      expect(find.byType(GaitRawRecordButton), findsNothing);
      expect(find.text('Record raw gait data (debug)'), findsNothing);
    }

    // Even a stored "pretend subscribed" is ignored without dev tools.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(fakeSubscriptionProvider.notifier).setFake(true);
    expect(container.read(subscriptionActiveProvider), isFalse);

    // Developer mode on: both come back.
    await container.read(settingsProvider.notifier).setFirmwareDevMode(true);
    await tester.pumpAndSettle();
    expect(find.byType(GaitRawRecordButton), findsOneWidget);
    page.value = const SubscriptionPage();
    await tester.pumpAndSettle();
    expect(fakeSwitch, findsOneWidget);
    expect(container.read(subscriptionActiveProvider), isTrue);
  });
}
