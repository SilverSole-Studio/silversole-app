import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/shared/pages/active_aging_page.dart';
import 'package:silversole/shared/pages/activity_report_page.dart';
import 'package:silversole/shared/pages/analytics_detail_page.dart';
import 'package:silversole/shared/pages/device_recent_warnings_page.dart';
import 'package:silversole/shared/pages/devices_page.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/pages/foot_check_result_page.dart';
import 'package:silversole/shared/pages/foot_check_session_page.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/pages/friends/nickname_setup_page.dart';
import 'package:silversole/shared/pages/firmware_update_page.dart';
import 'package:silversole/shared/pages/game_webview_page.dart';
import 'package:silversole/shared/pages/home_page.dart';
import 'package:silversole/shared/pages/shop_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';
import 'package:silversole/shared/pages/sign_up_page.dart';
import 'package:silversole/shared/pages/subscription_page.dart';
import 'package:silversole/shared/pages/app_icon_page.dart';
import 'package:silversole/shared/pages/theme_picker_page.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authUserProvider);
  final friendsOn = ref.watch(friendsEnabledProvider);
  final pendingShareLink = ref.read(pendingShareLinkProvider);

  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        // A signed-in user with no nickname picks one before the app opens.
        builder: (_, _) => NicknameGate(child: HomePage(title: 'Silver Sole')),
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
      GoRoute(
        path: '/activity-report',
        builder: (_, _) => const ActivityReportPage(),
      ),
      GoRoute(
        path: '/foot-check',
        builder: (_, _) => const FootCheckSessionPage(),
      ),
      GoRoute(
        path: '/foot-check-result',
        builder: (_, state) => FootCheckResultPage(
          // Measured by the session; a direct visit has nothing to report on.
          report: (state.extra as FootCheckReport?) ?? FootCheckReport.empty,
        ),
      ),
      GoRoute(path: '/my-devices', builder: (_, _) => const DevicesRoute()),
      GoRoute(
        path: '/firmware-update',
        builder: (_, state) => FirmwareUpdatePage(source: state.extra),
      ),
      GoRoute(path: '/shop', builder: (_, _) => const ShopRoute()),
      GoRoute(path: '/themes', builder: (_, _) => const ThemePickerPage()),
      GoRoute(path: '/app-icon', builder: (_, _) => const AppIconPage()),
      GoRoute(
        path: '/subscription',
        builder: (_, _) => const SubscriptionPage(),
      ),
      // 銀足樂齡: reached only from the hidden row on 「我的」; the page checks
      // aa_me() itself and the server checks every call.
      GoRoute(
        path: '/active-aging',
        builder: (_, _) => const ActiveAgingPage(),
      ),
      friendsRoute(enabled: friendsOn),
      shareLinkRoute(enabled: friendsOn),
      GoRoute(
        path: '/game-webview',
        builder: (_, state) {
          final args = (state.extra as Map?) ?? const {};
          return GameWebViewPage(
            url: (args['url'] as String?) ?? 'https://example.com',
            title: args['title'] as String?,
            closeOnLeavePath: args['closeOnLeavePath'] == true,
          );
        },
      ),
    ],
    redirect: (_, state) => appRedirect(
      isGuest: user == null,
      friendsOn: friendsOn,
      uri: state.uri,
      matchedLocation: state.matchedLocation,
      pendingShareLink: pendingShareLink,
    ),
  );
});

/// The router's sign-in gate, as a plain function so it can be tested.
@visibleForTesting
String? appRedirect({
  required bool isGuest,
  required bool friendsOn,
  required Uri uri,
  required String matchedLocation,
  required PendingShareLink pendingShareLink,
  bool skipAuthGate = kDebugMode && Constants.skipAuthGate,
}) {
  final isAuthPage =
      matchedLocation == '/sign-in' || matchedLocation == '/sign-up';

  // Debug-only bypass (see Constants.skipAuthGate): guests are left where
  // they are rather than pushed to /sign-in, so the auth pages stay
  // reachable by hand. Signed-in users are still bounced off them.
  if (skipAuthGate) {
    return !isGuest && isAuthPage ? '/' : null;
  }

  // A friend's link opened while signed out: hold it through sign-in, then
  // open it from the home page the sign-in lands on.
  final shareToken = friendsOn ? parseShareLinkToken(uri) : null;
  if (isGuest && shareToken != null) {
    pendingShareLink.hold(shareToken);
    return '/sign-in';
  }
  if (isGuest && !isAuthPage) return '/sign-in';
  if (!isGuest && isAuthPage) return '/';
  if (!isGuest && matchedLocation == '/') {
    final held = pendingShareLink.take();
    if (held != null) return '$kShareLinkPath?$kShareLinkParam=$held';
  }
  return null;
}
