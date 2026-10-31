import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/pages/theme_two/devices_page_t2.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'helpers/translations.dart';

const _left = BlePairedDevice(
  remoteId: 'l',
  name: 'SilverSole',
  deviceId: '00000000000000AA',
  footSide: FootSide.left,
);
const _right = BlePairedDevice(
  remoteId: 'r',
  name: 'SilverSole',
  deviceId: '00000000000000BB',
  footSide: FootSide.right,
);

/// Settings that assign in memory, so the test never touches
/// shared_preferences. [assignFootSide] is the same pure function the real
/// notifier persists through.
class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(pairedDevicesList: [_left, _right]);

  @override
  Future<void> setFootSide(String identityKey, FootSide? side) async {
    state = state.copyWith(
      pairedDevicesList: assignFootSide(
        state.pairedDevicesList,
        identityKey,
        side,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The mascot theme has no menu on a device row, so the badge itself is the
  // only in-theme way to correct a wrong foot. Clearing a side is what brings
  // the calibration overlay back, so a badge that looks tappable but is not
  // leaves a mis-stepped wearer with no way out at all.
  //
  // One EasyLocalization mount per file: it keeps global state, so a second
  // mount never leaves its loading state.
  testWidgets('tapping a foot badge unassigns that sole', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        // The real check reaches for a manifest over the network.
        firmwareCheckProvider.overrideWith(
          (ref) async => const FirmwareCheck(FirmwareCheckStatus.notConnected),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
            path: 'assets/translations/strings.csv',
            assetLoader: CsvAssetLoader(),
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                home: const DevicesPageT2(),
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    expect(find.text('Left foot'), findsOneWidget);
    expect(find.text('Right foot'), findsOneWidget);

    await tester.tap(find.text('Left foot'));
    await tester.pumpAndSettle();

    // The side is gone from the store, which is what makes
    // needsFootSideCalibrationProvider true again, and the badge with it.
    expect(
      container
          .read(settingsProvider)
          .pairedDevicesList
          .firstWhere((d) => d.identityKey == _left.identityKey)
          .footSide,
      isNull,
    );
    expect(find.text('Left foot'), findsNothing);
    // The other sole keeps its side: clearing one is not a reset.
    expect(find.text('Right foot'), findsOneWidget);
  });
}
