import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/widgets/dismiss_keyboard_on_tap_outside.dart';

Future<FocusNode> _pumpField(WidgetTester tester, {required bool wrap}) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          wrap ? DismissKeyboardOnTapOutside(child: child!) : child!,
      home: Scaffold(
        body: Column(children: [TextField(focusNode: focus)]),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pump();
  expect(focus.hasFocus, isTrue);
  return focus;
}

void main() {
  testWidgets('a touch outside the focused field closes the keyboard', (
    tester,
  ) async {
    final focus = await _pumpField(tester, wrap: true);
    await tester.tapAt(const Offset(200, 500));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  // Why the wrapper exists: Flutter's own default ignores touches outside.
  testWidgets('without it a touch outside keeps the field focused', (
    tester,
  ) async {
    final focus = await _pumpField(tester, wrap: false);
    await tester.tapAt(const Offset(200, 500));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });
}
