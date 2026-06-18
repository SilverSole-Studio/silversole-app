// Throwaway visual preview of the new Home hero (gradient + greeting).
// Not a *_test.dart pattern match? It is, but it's disposable — delete after.
// Run: flutter test test/_preview_home.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/widgets/status_card.dart';

Widget _hero(Brightness b) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(b),
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-0.3, -1.0),
                        end: const Alignment(0.3, 1.0),
                        colors: [
                          context.tokens.brandGradient.first.withValues(
                            alpha: 0.30,
                          ),
                          context.cs.tertiary.withValues(alpha: 0.18),
                          context.tokens.brandGradient.last.withValues(
                            alpha: 0.10,
                          ),
                          context.tokens.brandGradient.last.withValues(
                            alpha: 0.0,
                          ),
                        ],
                        stops: const [0.0, 0.32, 0.55, 0.82],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.xxl,
                    AppSpacing.base,
                    AppSpacing.base,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('歡迎回來', style: context.tt.displaySmall),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.bell),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      statusCard(
                        context,
                        type: StatusCardType.statusDisplay,
                        title: 'SilverSole',
                        model: '未知型號',
                        id: '58:8C:81:A9:2A:32',
                        icon: LucideIcons.footprints,
                        active: false,
                        addition: true,
                        detail: DeviceStatusDetailModel(
                          isCharging: false,
                          lastHeartbeatAt: DateTime(2026, 6, 19, 14, 32),
                        ),
                        frosted: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Card(
                        child: SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: Center(child: Text('plain card')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  for (final (name, b) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('home hero $name', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_hero(b));
      final ctx = t.element(find.byType(Scaffold));
      await t.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/silversole_full.png'),
          ctx,
        ),
      );
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('_preview_home_$name.png'),
      );
    });
  }
}
