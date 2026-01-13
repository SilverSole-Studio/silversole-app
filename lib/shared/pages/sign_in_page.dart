import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String email = '';
  String password = '';

  void back() => context.pop();

  void setEmail(String value) => setState(() => email = value);

  void setPassword(String value) => setState(() => password = value);

  void signInGoogle() => comingSoon();

  void signIn() => comingSoon();

  void goToSignUp() => comingSoon();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(onPressed: back, icon: const Icon(LucideIcons.arrowLeft)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          spacing: 16,
          children: [
            SizedBox(
              height: 250,
              child: Center(
                child: Text(
                  'silversole'.tr(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFamily: 'Oxanium',
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
            ),
            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'email'.tr(), border: OutlineInputBorder()),
              onChanged: (value) => setEmail(value),
            ),
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'password'.tr(), border: OutlineInputBorder()),
              onChanged: (value) => setPassword(value),
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: textOnDivider(context, 'or'.tr())),
            googleSignInButton(context, onPressed: signInGoogle),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: signIn, child: Text('sign_in'.tr())),
            ),
            TextButton(onPressed: goToSignUp, child: Text('Not sign in yet? Go to Sign Up')),
          ],
        ),
      ),
    );
  }
}

Widget textOnDivider(BuildContext context, String text) {
  return SizedBox(
    width: double.infinity,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Divider(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}

Widget googleSignInButton(BuildContext context, {required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset('assets/images/google_logo.svg', width: 20, height: 20),
            ),
            Text('sign_in_with_google'.tr(), style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
