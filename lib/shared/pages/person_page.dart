import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/models/user_identity.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/build_material_list.dart';
import 'package:silversole/shared/widgets/status_card.dart';

import '../../core/error/result.dart';
import '../models/app_settings.dart';
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

  String nextIdentity(String? currentValue) {
    return currentValue == UserIdentity.transmitter.value
        ? UserIdentity.observer.value
        : UserIdentity.transmitter.value;
  }

  Future<void> switchIdentity(String? currentValue) async {
    final old = currentValue ?? UserIdentity.transmitter.value;
    ref.read(settingsProvider.notifier).setIdentity(nextIdentity(old));
  }

  Future<void> switchDarkMode() async {
    final darkMode = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).setDarkMode(!darkMode.darkMode);
  }

  IconData getTransmissionIcon(TransmissionMethod method) {
    return switch (method) {
      TransmissionMethod.bluetooth => LucideIcons.bluetooth,
      TransmissionMethod.wifi => LucideIcons.wifi,
    };
  }

  String getTransmissionTitle(TransmissionMethod method) {
    return switch (method) {
      TransmissionMethod.bluetooth => 'bluetooth'.tr(),
      TransmissionMethod.wifi => 'wifi'.tr(),
    };
  }

  Future<void> setTransmissionMethod(TransmissionMethod method) async {
    ref.read(settingsProvider.notifier).setTransmissionMethod(method);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final settings = ref.watch(settingsProvider);
    final email = user?.email ?? 'not_signed_in'.tr();
    final uuid = user?.uuid ?? '-';
    final isSignedIn = user != null;

    final accountSettingList = [
      ListTileData.normal(title: 'sign_in'.tr(), icon: LucideIcons.logIn, onClick: goToLogin, enable: !isSignedIn),
      ListTileData.normal(title: 'sign_out'.tr(), icon: LucideIcons.logOut, onClick: signOut, enable: isSignedIn),
    ];

    final silverSoleSettingList = [
      ListTileData.normal(
        title: 'identity'.tr(),
        subtitle: settings.identity?.tr(),
        icon: LucideIcons.userPlus,
        onClick: () => switchIdentity(settings.identity),
        needCheck: true,
        checkTitle: 'switch_identity'.tr(),
        checkContent: 'change_identity_check_content'.tr(args: [nextIdentity(settings.identity).tr()]),
        trailing: true,
      ),
      /*
      ListTileData.dropdown(
        title: 'transmission_method'.tr(),
        enable: settings.identity == 'transmitter',
        selected: settings.transmissionMethod.name,
        icon: getTransmissionIcon(settings.transmissionMethod),
        onClick: comingSoon,
        optionsMap: {TransmissionMethod.bluetooth.name: 'bluetooth'.tr(), TransmissionMethod.wifi.name: 'wifi'.tr()},
        onChanged: (int idx, String key) =>
            setTransmissionMethod(TransmissionMethodValue.fromValue(key) ?? TransmissionMethod.bluetooth),
      ),
       */
      /*
      ListTileData.normal(
        title: 'binding_silversole_device'.tr(),
        subtitle: settings.deviceId,
        icon: LucideIcons.link2,
        onClick: () => showContentDialog(
          context,
          title: 'binding'.tr(),
          content: SizedBox(width: 400, child: DeviceBindingField()),
          buttonText: 'done'.tr(),
        ),
        trailing: true,
      ),
       */
    ];

    final generalSettingList = [
      ListTileData.normal(
        title: 'dark_mode'.tr(),
        subtitle: settings.darkMode ? 'on'.tr() : 'off'.tr(),
        icon: LucideIcons.moon,
        onClick: switchDarkMode,
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 36,
            children: [
              SizedBox(
                width: double.infinity,
                child: statusCard(
                  context,
                  title: email,
                  model: 'Basic',
                  id: uuid,
                  icon: LucideIcons.user,
                  addition: false,
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: buildMaterialList(context, title: 'account'.tr(), raw: accountSettingList),
              ),
              if (isSignedIn) ...[
                SizedBox(
                  width: double.infinity,
                  child: buildMaterialList(context, title: 'device'.tr(), raw: silverSoleSettingList),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: buildMaterialList(context, title: 'general'.tr(), raw: generalSettingList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
