import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/app_icon/app_icon_choice.dart';
import 'package:silversole/shared/pages/app_icon_page.dart';

class _FakeGateway implements AppIconGateway {
  AppIconChoice now = AppIconChoice.standard;
  final chosen = <AppIconChoice>[];

  @override
  Future<AppIconChoice> current() async => now;

  @override
  Future<void> choose(AppIconChoice choice) async {
    chosen.add(choice);
    now = choice;
  }
}

void main() {
  test('the platform name maps back to a choice', () {
    expect(AppIconChoice.fromPlatformName(null), AppIconChoice.standard);
    expect(AppIconChoice.fromPlatformName(''), AppIconChoice.standard);
    expect(
      AppIconChoice.fromPlatformName('com.dongyutech.silversole.DEFAULT'),
      AppIconChoice.standard,
    );
    expect(AppIconChoice.fromPlatformName('icon_b'), AppIconChoice.wave);
    expect(
      AppIconChoice.fromPlatformName('com.dongyutech.silversole.icon_c'),
      AppIconChoice.sLogo,
    );
    expect(AppIconChoice.fromPlatformName('nonsense'), AppIconChoice.standard);
  });

  test('the default icon is handed to the platform as null', () {
    expect(AppIconChoice.standard.platformName, isNull);
    expect(AppIconChoice.wave.platformName, 'icon_b');
    expect(AppIconChoice.sLogo.platformName, 'icon_c');
  });

  testWidgets('three icons, one ticked; tapping another switches the tick', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appIconGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(home: AppIconPage(showAndroidNote: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

    await tester.tap(find.byType(Image).at(1));
    await tester.pumpAndSettle();
    expect(gateway.chosen, [AppIconChoice.wave]);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

    await tester.tap(find.byType(Image).at(0));
    await tester.pumpAndSettle();
    expect(gateway.chosen.last, AppIconChoice.standard);
  });
}
