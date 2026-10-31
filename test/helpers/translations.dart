import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until the `EasyLocalization` that was just mounted has its strings
/// and the screen under it shows some text, then settles.
///
/// `strings.csv` is over 50 KB, and Flutter decodes an asset that size on
/// another isolate. A test's fake-async zone never waits for that, so a plain
/// `pumpAndSettle` would leave the screen blank. This hands the clock's wait
/// to real time in short steps instead, giving up after two seconds so a
/// genuine failure still reports as one.
Future<void> settleTranslations(WidgetTester tester) async {
  for (var i = 0; i < 100 && find.byType(Text).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
