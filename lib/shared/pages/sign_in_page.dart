import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';

import '../../core/utils/field_validator.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  String email = '';
  String password = '';
  bool enableSignInButton = true;

  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  void back() => context.pop();

  void setEmail(String value) => setState(() => email = value);

  void setPassword(String value) => setState(() => password = value);

  void signInGoogle() => comingSoon();

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidate = true);
      return;
    }
    setState(() => enableSignInButton = false);
    try {
      final authService = ref.read(authServiceProvider);
      final res = await authService.supabaseSignIn(email, password);
      switch (res) {
        case Ok<UserData>():
          final data = res.value;
          ref.read(authUserProvider.notifier).setUser(data);
          showMessage('sign_in_success'.tr());
          back();
        case Error():
          showErrorSnakeBar(res.error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => enableSignInButton = true);
      }
    }
  }

  void goToSignUp() => context.push('/sign-up');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: back, icon: const Icon(LucideIcons.arrowLeft)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(48, 0, 48, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'email'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.mail),
                  ),
                  validator: (val) => fieldEmptyValidator(val) ?? emailValidator(val ?? ''),
                  onChanged: (value) => setEmail(value),
                ),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.lock),
                  ),
                  validator: (val) => fieldEmptyValidator(val),
                  onChanged: (value) => setPassword(value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: enableSignInButton ? signIn : null,
                    child: enableSignInButton
                        ? Text('sign_in'.tr())
                        : SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ), // ignore: deprecated_member_use
                  ),
                ),
                Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: textOnDivider(context, 'or'.tr())),
                googleSignInButton(context, onPressed: signInGoogle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('no_account_prompt'.tr(), style: TextStyle(color: Colors.grey)),
                    TextButton(onPressed: goToSignUp, child: Text('sign_up'.tr())),
                  ],
                ),
              ],
            ),
          ),
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
