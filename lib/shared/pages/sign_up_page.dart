import 'package:easy_localization/easy_localization.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/providers/auth_provider.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  String email = '';
  String password = '';
  String confirmPassword = '';
  bool enableSignUpButton = true;

  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  void back() => context.pop();

  void clearValidatorHint() {
    if (_autoValidate) {
      setState(() => _autoValidate = false);
    }
  }

  void setEmail(String value) => setState(() => email = value);

  void setPassword(String value) => setState(() => password = value);

  void setConfirmPassword(String value) => setState(() => confirmPassword = value);

  String? fieldEmptyValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'field_required'.tr();
    return null;
  }

  String? emailValidator(String value) {
    if (!EmailValidator.validate(value.trim())) return 'invalid_email'.tr();
    return null;
  }

  String? confirmPasswordMatchValidator(String value) {
    if (value != password) return 'password_mismatch'.tr();
    return null;
  }

  void signInGoogle() => comingSoon();

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidate = true);
      return;
    }
    setState(() => enableSignUpButton = false);
    try {
      final authService = ref.read(authServiceProvider);
      final res = await authService.supabaseSignUp(email, password);
      switch (res) {
        case Ok<void>():
          showMessage('sign_up_success'.tr());
          back();
        case Error():
          showErrorSnakeBar(res.error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => enableSignUpButton = true);
      }
    }
  }

  void goToSignUp() => comingSoon();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(onPressed: back, icon: const Icon(LucideIcons.arrowLeft)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 100, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text('sign_up'.tr(), style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text('sign_up_intro'.tr(), style: tt.titleSmall?.copyWith(color: Colors.grey)),
                  ],
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
                onChanged: (value) {
                  clearValidatorHint();
                  setEmail(value);
                },
              ),
              TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                validator: (val) => fieldEmptyValidator(val),
                onChanged: (value) {
                  clearValidatorHint();
                  setPassword(value);
                },
              ),
              TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                validator: (val) => fieldEmptyValidator(val) ?? confirmPasswordMatchValidator(val ?? ''),
                onChanged: (value) {
                  clearValidatorHint();
                  setConfirmPassword(value);
                },
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: enableSignUpButton ? signUp : null, child: Text('sign_up'.tr())),
              ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: textOnDivider(context, 'or'.tr())),
              googleSignInButton(context, onPressed: signInGoogle),
            ],
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
