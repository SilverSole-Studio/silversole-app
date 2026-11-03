import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// 設定頁「文字大小」：標準／大。
void main() {
  group('initialTextSizeFor (first launch)', () {
    test('a normal phone starts on standard', () {
      expect(initialTextSizeFor(1.0), AppTextSize.normal);
      expect(initialTextSizeFor(1.14), AppTextSize.normal);
    });

    test('a phone already set to a large font starts on large', () {
      expect(initialTextSizeFor(kLargeTextScaleThreshold), AppTextSize.large);
      expect(initialTextSizeFor(1.3), AppTextSize.large);
      expect(initialTextSizeFor(2.0), AppTextSize.large);
    });
  });

  test('wire names are the ones the web games read', () {
    expect(AppTextSize.normal.wireName, 'normal');
    expect(AppTextSize.large.wireName, 'large');
    expect(AppTextSize.fromWireName('large'), AppTextSize.large);
    expect(AppTextSize.fromWireName('normal'), AppTextSize.normal);
    expect(AppTextSize.fromWireName('huge'), isNull);
    expect(AppTextSize.fromWireName(null), isNull);
  });

  group('applySystemFontScale', () {
    Future<double> scaleAt(
      WidgetTester tester,
      double system,
      AppTextSize size,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = system;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      late double seen;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              applySystemFontScale(context, child, textSize: size),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.textScalerOf(context).scale(10) / 10;
              return const SizedBox();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('large is the old behavior: the system scale, capped', (
      tester,
    ) async {
      expect(
        await scaleAt(tester, 1.0, AppTextSize.large),
        closeTo(1.0, 0.001),
      );
      expect(
        await scaleAt(tester, 1.2, AppTextSize.large),
        closeTo(1.2, 0.001),
      );
      expect(
        await scaleAt(tester, 2.0, AppTextSize.large),
        closeTo(kMaxAppTextScale, 0.001),
      );
    });

    testWidgets('standard is smaller than large at every system scale', (
      tester,
    ) async {
      expect(
        await scaleAt(tester, 1.0, AppTextSize.normal),
        closeTo(kStandardTextFactor, 0.001),
      );
      expect(
        await scaleAt(tester, 1.2, AppTextSize.normal),
        closeTo(1.2 * kStandardTextFactor, 0.001),
      );
      expect(
        await scaleAt(tester, 2.0, AppTextSize.normal),
        closeTo(kMaxAppTextScale * kStandardTextFactor, 0.001),
      );
    });

    testWidgets('the real system scale is still passed down', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      late double real;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => applySystemFontScale(
            context,
            child,
            textSize: AppTextSize.normal,
          ),
          home: Builder(
            builder: (context) {
              real = SystemFontScale.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(real, 2.0);
    });
  });

  group('settings: text size', () {
    ProviderContainer containerWithPhoneScale(double scale) {
      final container = ProviderContainer(
        overrides: [
          systemFontScaleReaderProvider.overrideWithValue(() => scale),
        ],
      );
      addTearDown(container.dispose);
      container.listen(settingsProvider, (_, _) {});
      return container;
    }

    Future<void> loaded() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('defaults to standard before anything is loaded', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerWithPhoneScale(1.3);
      expect(c.read(settingsProvider).textSize, AppTextSize.normal);
      await loaded();
    });

    test('first launch on a normal phone: standard, and remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerWithPhoneScale(1.0);
      await loaded();
      expect(c.read(settingsProvider).textSize, AppTextSize.normal);
      expect(await loadLocalValue(LocalSavableKey.textSize), 'normal');
    });

    test('first launch on a large-font phone: large, and remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerWithPhoneScale(1.3);
      await loaded();
      expect(c.read(settingsProvider).textSize, AppTextSize.large);
      expect(await loadLocalValue(LocalSavableKey.textSize), 'large');
    });

    test('after that the stored choice wins over the phone font', () async {
      SharedPreferences.setMockInitialValues({'text_size': 'normal'});
      final c = containerWithPhoneScale(2.0);
      await loaded();
      expect(c.read(settingsProvider).textSize, AppTextSize.normal);

      SharedPreferences.setMockInitialValues({'text_size': 'large'});
      final d = containerWithPhoneScale(1.0);
      await loaded();
      expect(d.read(settingsProvider).textSize, AppTextSize.large);
    });

    test('setTextSize changes the state and is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerWithPhoneScale(1.0);
      await loaded();
      await c.read(settingsProvider.notifier).setTextSize(AppTextSize.large);
      expect(c.read(settingsProvider).textSize, AppTextSize.large);
      expect(await loadLocalValue(LocalSavableKey.textSize), 'large');
    });
  });
}
