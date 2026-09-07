import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/shared/pages/analytics_detail_page.dart';
import 'package:silversole/shared/pages/device_recent_warnings_page.dart';
import 'package:silversole/shared/pages/devices_page.dart';
import 'package:silversole/shared/pages/game_webview_page.dart';
import 'package:silversole/shared/pages/home_page.dart';
import 'package:silversole/shared/pages/shop_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';
import 'package:silversole/shared/pages/sign_up_page.dart';
import 'package:silversole/shared/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authUserProvider);

  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomePage(title: 'Silver Sole'),
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => SignInPage()),
      GoRoute(path: '/sign-up', builder: (_, _) => SignUpPage()),
      GoRoute(
        path: '/device-recent-warnings',
        builder: (_, _) => DeviceRecentWarningsPage(),
      ),
      GoRoute(
        path: '/analytics-detail',
        builder: (_, _) => const AnalyticsDetailRoute(),
      ),
      GoRoute(path: '/my-devices', builder: (_, _) => const DevicesRoute()),
      GoRoute(path: '/shop', builder: (_, _) => const ShopRoute()),
      GoRoute(
        path: '/game-webview',
        builder: (_, state) {
          final args = (state.extra as Map?) ?? const {};
          return GameWebViewPage(
            url: (args['url'] as String?) ?? 'https://example.com',
            title: args['title'] as String?,
          );
        },
      ),
    ],
    redirect: (_, state) {
      final isGuest = user == null;
      final isAuthPage =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      // Debug-only bypass (see Constants.skipAuthGate): guests are left where
      // they are rather than pushed to /sign-in, so the auth pages stay
      // reachable by hand. Signed-in users are still bounced off them.
      if (kDebugMode && Constants.skipAuthGate) {
        return !isGuest && isAuthPage ? '/' : null;
      }

      if (isGuest && !isAuthPage) return '/sign-in';
      if (!isGuest && isAuthPage) return '/';
      return null;
    },
  );
});
