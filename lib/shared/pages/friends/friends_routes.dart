import 'package:go_router/go_router.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/shared/pages/friends/enter_code_page.dart';
import 'package:silversole/shared/pages/friends/friends_page.dart';
import 'package:silversole/shared/pages/friends/org_pages.dart';
import 'package:silversole/shared/pages/friends/person_pages.dart';
import 'package:silversole/shared/pages/friends/profile_page.dart';
import 'package:silversole/shared/pages/friends/qr_pages.dart';
import 'package:silversole/shared/pages/friends/requests_page.dart';

/// `/friends` and its sub-pages, registered by the app router. While
/// [enabled] is false (see `friendsEnabledProvider`) every friends address
/// sends you home, so no stray link or card can open the screens.
GoRoute friendsRoute({required bool enabled}) => GoRoute(
  path: '/friends',
  redirect: (_, _) => enabled ? null : '/',
  builder: (_, _) => const FriendsPage(),
  routes: [
    GoRoute(path: 'profile', builder: (_, _) => const ProfilePage()),
    GoRoute(path: 'my-qr', builder: (_, _) => const MyQrPage()),
    GoRoute(path: 'scan', builder: (_, _) => const ScanQrPage()),
    GoRoute(
      path: 'code',
      builder: (_, state) =>
          EnterCodePage(mode: (state.extra as CodeMode?) ?? CodeMode.friend),
    ),
    GoRoute(path: 'requests', builder: (_, _) => const RequestsPage()),
    GoRoute(path: 'orgs', builder: (_, _) => const OrgsPage()),
    GoRoute(
      path: 'org',
      builder: (_, state) => OrgMembersPage(org: state.extra! as OrgSummary),
    ),
    GoRoute(
      path: 'person',
      builder: (_, state) => FriendDetailPage(friend: state.extra! as Friend),
    ),
    GoRoute(path: 'blocked', builder: (_, _) => const BlockedPage()),
  ],
);
