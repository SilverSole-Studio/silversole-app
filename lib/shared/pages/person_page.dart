import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/user_identity.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/account_card.dart';
import 'package:silversole/shared/widgets/basic_dialog.dart';
import 'package:silversole/shared/widgets/build_material_list.dart';
import 'package:silversole/shared/widgets/device_binding_field.dart';

import '../../core/error/result.dart';
import '../providers/auth_provider.dart';

class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key});

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  void goToLogin() => context.push('/sign-in');

  Future<void> signOut() async {
    // Check is signed in
    final user = ref.read(authUserProvider);
    if (user == null) return;

    // Sign out
    final authService = ref.read(authServiceProvider);
    final res = await authService.supabaseSignOut();
    switch (res) {
      case Ok<void>():
        ref.read(authUserProvider.notifier).setUser(null);
        showMessage('sign_out_success'.tr());
      case Error<void>():
        showErrorSnakeBar(res.error.toString());
    }
  }

  Future<void> switchIdentity(String? currentValue) async {
    //TODO: Add dialog to double check
    final old = currentValue ?? UserIdentity.transmitter.value;
    ref
        .read(settingsProvider.notifier)
        .setIdentity(
          old == UserIdentity.transmitter.value ? UserIdentity.observer.value : UserIdentity.transmitter.value,
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final settings = ref.watch(settingsProvider);
    final email = user?.email ?? 'not_signed_in'.tr();
    final uuid = user?.uuid ?? '-';
    final deviceId = settings.deviceId;
    final identity = settings.identity;
    final isSignedIn = user != null;

    final accountSettingList = [
      ListTileData(title: 'sign_in'.tr(), icon: LucideIcons.logIn, onClick: goToLogin, enable: !isSignedIn),
      ListTileData(title: 'sign_out'.tr(), icon: LucideIcons.logOut, onClick: signOut, enable: isSignedIn),
    ];

    final silverSoleSettingList = [
      ListTileData(
        title: 'identity'.tr(),
        subtitle: identity?.tr(),
        icon: LucideIcons.userPlus,
        onClick: () => switchIdentity(identity),
        trailing: true,
      ),
      ListTileData(
        title: 'binding_silversole_device'.tr(),
        subtitle: deviceId,
        icon: LucideIcons.link2,
        onClick: () => showContentDialog(
          context,
          title: 'binding'.tr(),
          content: SizedBox(width: 400, child: DeviceBindingField()),
          buttonText: 'done'.tr()
        ),
        trailing: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'person'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'Oxanium',
            fontVariations: const [FontVariation('wght', 600)],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 36,
            children: [
              SizedBox(
                width: double.infinity,
                height: 100,
                child: statusCard(context, title: email, subtitle: uuid, icon: LucideIcons.user),
              ),
              SizedBox(
                width: double.infinity,
                child: buildMaterialList(context, title: 'account'.tr(), list: accountSettingList),
              ),
              if (isSignedIn) ...[
                SizedBox(
                  width: double.infinity,
                  child: buildMaterialList(context, title: 'device'.tr(), list: silverSoleSettingList),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
