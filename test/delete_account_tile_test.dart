import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/widgets/delete_account_tile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount, every case: EasyLocalization keeps global state, so a second
  // mount in the same file never leaves its loading state.
  testWidgets('deleting asks first, cancel does nothing, confirm proceeds', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    var confirmed = 0;
    final busy = ValueNotifier(false);
    addTearDown(busy.dispose);

    await tester.pumpWidget(
      EasyLocalization(
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
              body: ValueListenableBuilder(
                valueListenable: busy,
                builder: (_, value, _) => DeleteAccountTile(
                  busy: value,
                  onConfirmed: () => confirmed++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The dialog says what goes and that it is final.
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('nickname'), findsOneWidget);
    expect(find.textContaining('friends'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    // The destructive button is painted in the error color.
    final confirm = find.widgetWithText(FilledButton, 'Delete permanently');
    final context = tester.element(confirm);
    final style = tester.widget<FilledButton>(confirm).style!;
    expect(
      style.backgroundColor!.resolve({}),
      Theme.of(context).colorScheme.error,
    );

    // Cancel closes it and deletes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(confirmed, 0);

    // Confirm proceeds exactly once.
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmed, 1);

    // While deleting, the row shows progress and ignores taps.
    busy.value = true;
    await tester.pump();
    expect(find.text('Deleting account…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Deleting account…'));
    await tester.pump();
    expect(find.text('Delete your account?'), findsNothing);
  });
}
