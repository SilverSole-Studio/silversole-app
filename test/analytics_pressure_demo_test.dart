import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'helpers/translations.dart';

/// Settings a test can hand straight in, skipping the shared_preferences load.
class _Settings extends SettingsNotifier {
  _Settings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

ImuNotifyDataModel _imu(List<int> pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: pressure,
  batteryPercent: 90,
  isCharging: false,
);

Future<void> _pumpAnalytics(WidgetTester tester, Widget page) async {
  // Pumped through runAsync because easy_localization reads strings.csv off
  // disk, and the fake-async zone never settles on real file I/O.
  await tester.runAsync(
    () => tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              home: page,
            ),
          ),
        ),
      ),
    ),
  );
  await settleTranslations(tester);
}

/// Switches to the pressure tab, replays the walk clip and returns the
/// pressure the heat map is actually rendering.
Future<List<int>> _playWalkOnPressureTab(WidgetTester tester) async {
  await tester.tap(find.text('Pressure map'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Sample'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<void>, 'Walk'));

  // Reading the bundled clip is real file I/O, which only completes outside
  // the fake-async zone. The fake clock stands still meanwhile, so playback is
  // still on frame 0 when we come back.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();

  return tester
      .widget<FootPressureHeatmap>(find.byType(FootPressureHeatmap))
      .pressure;
}

/// Mounts a bare [PressureDemoScope] on [container], printing what it hands
/// its builder.
Future<void> _pumpScope(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.runAsync(
    () => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              home: Scaffold(
                body: PressureDemoScope(
                  builder: (context, reading, header) => Column(
                    children: [
                      header,
                      Text('p=${reading.right}'),
                      Text('left=${reading.left}'),
                      Text('has=${reading.hasData}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await settleTranslations(tester);
}

ProviderContainer _containerWith(List<BlePairedDevice> paired) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _Settings(AppSettings(pairedDevicesList: paired)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

BlePairedDevice _sole(String id, FootSide side) => BlePairedDevice(
  remoteId: id.toLowerCase(),
  name: 'SilverSole',
  deviceId: id,
  footSide: side,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('classic analytics replays the walk clip on the pressure tab', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(tester, const AnalyticsPage());

    // First frame of silversole_v1.1_walk_right.json.
    expect(await _playWalkOnPressureTab(tester), [600, 380, 2600]);

    // Leave playback stopped so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pumpAndSettle();
  });

  testWidgets('mascot analytics replays the walk clip on the pressure tab', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(tester, const AnalyticsPageT2());

    expect(await _playWalkOnPressureTab(tester), [600, 380, 2600]);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pumpAndSettle();
  });

  testWidgets('the demo scope falls back to live telemetry when idle', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(
      tester,
      Scaffold(
        body: PressureDemoScope(
          builder: (context, reading, header) => Column(
            children: [
              header,
              Text('p=${reading.right}'),
              Text('left=${reading.left}'),
              Text('has=${reading.hasData}'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('p=[0, 0, 0]'), findsOneWidget);
    expect(find.text('has=false'), findsOneWidget);
    // Nothing is paired, so no sole feeds the left foot and no clip is playing.
    expect(find.text('left=null'), findsOneWidget);
  });

  testWidgets('a left sole feeds the left foot instead of a dash', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final settings = _Settings(
      const AppSettings(
        pairedDevicesList: [
          BlePairedDevice(
            remoteId: 'l',
            name: 'SilverSole',
            deviceId: 'L',
            footSide: FootSide.left,
          ),
          BlePairedDevice(
            remoteId: 'r',
            name: 'SilverSole',
            deviceId: 'R',
            footSide: FootSide.right,
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => settings)],
    );
    addTearDown(container.dispose);
    container
        .read(liveTelemetryProvider('L').notifier)
        .updateImuNotifyData(_imu(const [11, 22, 33]));
    container
        .read(liveTelemetryProvider('R').notifier)
        .updateImuNotifyData(_imu(const [44, 55, 66]));

    await _pumpScope(tester, container);

    expect(find.text('p=[44, 55, 66]'), findsOneWidget);
    expect(find.text('left=[11, 22, 33]'), findsOneWidget);
    expect(find.text('has=true'), findsOneWidget);
  });

  // hasData speaks for the right foot alone. With a sole only on the left, the
  // right foot has no source, so it must read as absent — the readouts print
  // `--` and the heat map paints the "no sensor" fill. Reporting it as data
  // would draw a foot bearing zero load, and "this foot takes no weight" is a
  // clinical statement the wearer cannot tell apart from "no sole on".
  testWidgets('a lone left sole leaves the right foot reading as absent', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = _containerWith([_sole('L', FootSide.left)]);
    container
        .read(liveTelemetryProvider('L').notifier)
        .updateImuNotifyData(_imu(const [11, 22, 33]));

    await _pumpScope(tester, container);

    expect(find.text('has=false'), findsOneWidget);
    // `right` is non-nullable, so it still carries the zero placeholder:
    // `hasData` is the only thing standing between that and the screen.
    expect(find.text('p=[0, 0, 0]'), findsOneWidget);
    // The left foot still carries its own reading.
    expect(find.text('left=[11, 22, 33]'), findsOneWidget);
  });

  // A playing clip owns both feet. A right-only payload (schema 1, or schema 2
  // with no left track) must blank the left foot, not mix live readings in.
  testWidgets('a right-only clip blanks the left foot instead of going live', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = _containerWith([_sole('L', FootSide.left)]);
    container
        .read(liveTelemetryProvider('L').notifier)
        .updateImuNotifyData(_imu(const [11, 22, 33]));

    // Stands in for the bundled walk clip; nothing test-only ships in the app.
    const rightOnly =
        '{"schema_version":1,"sample_rate_hz":25,"samples":['
        '[0,0,0,0,0,0,0,7,8,9,0,0],[40,0,0,0,0,0,0,7,8,9,0,0]]}';
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final bytes = key == DemoMotion.walk.asset
          ? utf8.encode(rightOnly)
          : await File(key).readAsBytes();
      return ByteData.sublistView(Uint8List.fromList(bytes));
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    await _pumpScope(tester, container);
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<void>, 'Walk'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(find.text('p=[7, 8, 9]'), findsOneWidget);
    expect(find.text('left=null'), findsOneWidget);

    // Stop playback so no timer outlives the test.
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pumpAndSettle();
  });
}
