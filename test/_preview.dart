// Throwaway visual preview (not a *_test.dart, so the normal suite ignores it).
// Run: flutter test test/_preview.dart --update-goldens  → writes _preview_*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/widgets/section_card.dart';

Widget _demo(Brightness b) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(b),
    home: Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          SectionCard(
            title: 'Device status',
            trailing: const Icon(Icons.arrow_forward),
            child: const Text('SilverSole - offline\nbattery / signal'),
          ),
          const SizedBox(height: AppSpacing.base),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: Text('A plain Card floating on the gray page'),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Primary')),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('light', (t) async {
    await t.pumpWidget(_demo(Brightness.light));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('_preview_light.png'),
    );
  });
  testWidgets('dark', (t) async {
    await t.pumpWidget(_demo(Brightness.dark));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('_preview_dark.png'),
    );
  });
}
