import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/fall_tilt_detector.dart';
import 'package:silversole/shared/providers/fall_demo_provider.dart';
import 'package:silversole/shared/widgets/fall_demo_overlay.dart';

/// Stands in for the real notifier so the test drives the judgement directly
/// instead of feeding telemetry through the detector.
class _TestFallDemo extends FallDemoNotifier {
  @override
  FallTilt build() => FallTilt.idle;

  void judge(FallTilt tilt) => state = tilt;
}

const _halfway = FallTilt(
  tiltDegrees: 82,
  progress: 0.5,
  held: Duration(milliseconds: 1500),
);
const _fallen = FallTilt(
  tiltDegrees: 82,
  progress: 1,
  held: Duration(seconds: 3),
);

/// A fresh finder per call: Finder instances cache their results, so sharing
/// one across frames reads a stale tree.
Finder panel() => find.byIcon(LucideIcons.triangleAlert);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final haptics = <String>[];

  setUp(() {
    haptics.clear();
    // easy_localization persists the chosen locale through shared_preferences;
    // without the mock that channel call never answers and the test blocks
    // forever.
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? 'vibrate');
          }
          return null;
        });
  });

  // One test for the whole lifecycle on purpose: EasyLocalization keeps global
  // state, so a second mount in the same file never leaves its loading state.
  testWidgets('the demo warning buzzes, latches, and only the button clears it', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final container = ProviderContainer(
      overrides: [fallDemoProvider.overrideWith(_TestFallDemo.new)],
    );
    addTearDown(container.dispose);

    Future<void> judge(FallTilt tilt) async {
      (container.read(fallDemoProvider.notifier) as _TestFallDemo).judge(tilt);
      await tester.pump();
    }

    await tester.pumpWidget(
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
              home: const FallDemoOverlay(
                child: Scaffold(body: Text('page content')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing steep yet: the page shows through, no panel, no buzzing.
    expect(find.text('page content'), findsOneWidget);
    expect(panel(), findsNothing);
    expect(haptics, isEmpty);

    // Building up: one pulse every half second, so the hold can be felt coming.
    await judge(_halfway);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);
    expect(panel(), findsNothing, reason: 'not fired yet');

    // It fires: one heavier buzz, the red panel, and the pulsing stops.
    await judge(_fallen);
    expect(haptics.last, 'HapticFeedbackType.heavyImpact');
    expect(panel(), findsOneWidget);
    expect(find.text('Your family member may need help'), findsOneWidget);
    expect(find.textContaining('°'), findsNothing, reason: 'no sensor readout');

    final afterFiring = haptics.length;
    await tester.pump(const Duration(seconds: 1));
    expect(haptics, hasLength(afterFiring), reason: 'pulsing stopped');

    // Standing back up must NOT take the panel away — only the button does.
    await judge(FallTilt.idle);
    expect(panel(), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Got it'));
    await tester.pump();
    expect(panel(), findsNothing);

    // A judgement that is still standing must not re-latch straight away.
    await judge(_fallen);
    expect(panel(), findsNothing);

    // Upright again re-arms it, so the next demo run shows the panel.
    await judge(FallTilt.idle);
    await judge(_fallen);
    expect(panel(), findsOneWidget);
  });
}
