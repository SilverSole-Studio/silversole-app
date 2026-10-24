import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';

void main() {
  for (final path in ['/friends', '/friends/my-qr', '/friends/requests']) {
    testWidgets('with friends off, $path goes home', (tester) async {
      final router = GoRouter(
        initialLocation: path,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          friendsRoute(enabled: false),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  }
}
