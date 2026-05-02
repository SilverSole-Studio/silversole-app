import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/shared/pages/analytics_detail_page.dart';
import 'package:silversole/shared/pages/device_recent_warnings_page.dart';
import 'package:silversole/shared/pages/home_page.dart';
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
        builder: (_, _) => AnalyticsDetailPage(),
      ),
    ],
    redirect: (_, state) {
      final isGuest = user == null;
      final isAuthPage =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      if (isGuest && !isAuthPage) return '/sign-in';
      if (!isGuest && isAuthPage) return '/';
      return null;
    },
  );
});
