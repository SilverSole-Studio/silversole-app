import 'package:go_router/go_router.dart';
import 'package:silversole/shared/pages/home_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => HomePage(title: 'Silver Sole'),
    ),
    GoRoute(path: '/sign-in', builder: (_, _) => SignInPage())
  ],
);
