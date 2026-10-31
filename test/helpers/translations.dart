import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until the `EasyLocalization` that was just mounted has its strings
/// and `MaterialApp` has built its page, then settles.
///
/// `strings.csv` is over 50 KB, and Flutter decodes an asset that size on
/// another isolate. A test's fake-async zone never waits for that, so a plain
/// `pumpAndSettle` would leave the screen blank. This hands the clock's wait
/// to real time in short steps instead. `Localizations` builds nothing, not
/// even a `Directionality`, until every delegate has loaded, so that is what
/// is waited for. After two seconds without it this throws, so a blank screen
/// can never satisfy a `findsNothing`.
Future<void> settleTranslations(WidgetTester tester) async {
  for (
    var i = 0;
    i < 100 && find.byType(Directionality).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  if (find.byType(Directionality).evaluate().isEmpty) {
    throw TestFailure('translations never loaded');
  }
  await tester.pumpAndSettle();
}
