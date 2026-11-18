import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/pages/foot_check_session_page.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'helpers/translations.dart';

const _sole = BlePairedDevice(
  remoteId: 'addr',
  name: 'SilverSole',
  deviceId: 'A',
);

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  void pair() => state = const AppSettings(pairedDevicesList: [_sole]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One test on purpose: EasyLocalization keeps global state per file.
  testWidgets('no sole: explains instead of running an empty minute', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final settings = _Settings();
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => settings)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const FootCheckSessionPage()),
      ],
    );
    addTearDown(router.dispose);

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
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    // Nothing paired: a pairing prompt, and no clock or progress bar.
    expect(find.text('Pair your sole first'), findsOneWidget);
    expect(find.text('Pair sole'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:00'), findsNothing);

    // Paired but not connected: says so and offers to reconnect.
    container.read(settingsProvider.notifier);
    settings.pair();
    await tester.pumpAndSettle();
    expect(find.text('Sole not connected'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Once it connects the minute starts by itself.
    container
        .read(connectedSolesProvider.notifier)
        .set(
          _sole.identityKey,
          const ConnectedSole(device: _sole, dfuSupported: false),
        );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Sole not connected'), findsNothing);

    // Let the 60 s timer run out so no timer is left pending.
    await tester.pump(FootCheckSessionPage.sessionLength);
  });
}
