import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/app_gate/app_gate.dart';
import 'package:silversole/core/app_gate/app_gate_check.dart';
import 'package:silversole/core/app_gate/version_compare.dart';

const _url = 'https://example.com/store';

Future<AppGateDecision> _run(
  Future<Map<String, dynamic>?> Function(String) fetch, {
  String version = '1.13.4',
  String platform = 'ios',
  Duration timeout = const Duration(milliseconds: 50),
}) => checkAppGate(
  fetch: fetch,
  currentVersion: version,
  platform: platform,
  timeout: timeout,
);

void main() {
  group('compareVersions', () {
    test('orders numerically, not as text', () {
      expect(compareVersions('1.13.4', '1.14.0'), lessThan(0));
      expect(compareVersions('1.14.0', '1.13.4'), greaterThan(0));
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('missing parts count as 0', () {
      expect(compareVersions('1.14', '1.14.0'), 0);
      expect(compareVersions('1', '1.0.0'), 0);
      expect(compareVersions('1.14', '1.14.1'), lessThan(0));
    });

    test('ignores -rc.N and +build', () {
      expect(compareVersions('1.14.0-rc.2', '1.14.0'), 0);
      expect(compareVersions('1.14.0+7', '1.14.0'), 0);
      expect(compareVersions('1.14.0-rc.2+7', '1.14.0'), 0);
      expect(compareVersions('1.13.9-rc.1', '1.14.0'), lessThan(0));
    });
  });

  group('checkAppGate', () {
    test('blocks when below min', () async {
      final d = await _run(
        (_) async => {'min_version': '1.14.0', 'store_url': _url},
      );
      expect(d.blocked, isTrue);
      expect(d.storeUrl, _url);
    });

    test('allows when equal or above min', () async {
      final eq = await _run(
        (_) async => {'min_version': '1.13.4', 'store_url': _url},
      );
      final above = await _run(
        (_) async => {'min_version': '1.0.0', 'store_url': _url},
      );
      expect(eq.blocked, isFalse);
      expect(above.blocked, isFalse);
    });

    test('passes the platform to the fetcher', () async {
      String? seen;
      await _run((p) async {
        seen = p;
        return {};
      }, platform: 'android');
      expect(seen, 'android');
    });

    test('fails open when the call throws', () async {
      final d = await _run((_) async => throw Exception('network'));
      expect(d.blocked, isFalse);
    });

    test('fails open on timeout', () async {
      final d = await _run((_) => Completer<Map<String, dynamic>?>().future);
      expect(d.blocked, isFalse);
    });

    test('fails open on empty, null or malformed result', () async {
      expect((await _run((_) async => <String, dynamic>{})).blocked, isFalse);
      expect((await _run((_) async => null)).blocked, isFalse);
      expect(
        (await _run((_) async => {'min_version': 5, 'store_url': _url}))
            .blocked,
        isFalse,
      );
      expect(
        (await _run((_) async => {'min_version': '9.0.0'})).blocked,
        isFalse,
      );
    });

    test('skips the gate for dev version 0.0.0 without calling', () async {
      var called = false;
      final d = await _run((_) async {
        called = true;
        return {'min_version': '9.0.0', 'store_url': _url};
      }, version: '0.0.0');
      expect(d.blocked, isFalse);
      expect(called, isFalse);
    });

    test('allows unknown platforms without calling', () async {
      var called = false;
      final d = await _run((_) async {
        called = true;
        return {'min_version': '9.0.0', 'store_url': _url};
      }, platform: 'windows');
      expect(d.blocked, isFalse);
      expect(called, isFalse);
    });
  });

  group('AppGate widget', () {
    Widget host(
      AppGateRunner runner, {
      StoreOpener? openStore,
      DateTime Function()? now,
    }) => MaterialApp(
      home: AppGate(
        runner: runner,
        openStore: openStore ?? (_) async {},
        now: now ?? DateTime.now,
        child: const Scaffold(body: Text('app body')),
      ),
    );

    testWidgets('shows the block screen when below min', (tester) async {
      String? opened;
      await tester.pumpWidget(
        host(
          () async => const AppGateDecision.blocked(_url),
          openStore: (u) async => opened = u,
        ),
      );
      await tester.pump();
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(opened, _url);
    });

    testWidgets('shows nothing extra when allowed', (tester) async {
      await tester.pumpWidget(
        host(() async => const AppGateDecision.allowed()),
      );
      await tester.pump();
      expect(find.text('app body'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('fails open when the runner throws', (tester) async {
      await tester.pumpWidget(host(() async => throw Exception('boom')));
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('rechecks on resume at most once per minute', (tester) async {
      var calls = 0;
      var clock = DateTime(2026, 11, 14, 12);
      await tester.pumpWidget(
        host(() async {
          calls++;
          return const AppGateDecision.allowed();
        }, now: () => clock),
      );
      await tester.pump();
      expect(calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 1);

      clock = clock.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
    });
  });
}
