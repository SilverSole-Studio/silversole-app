import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/active_aging/aa_repository.dart';
import 'package:silversole/core/auth/auth_service.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/models/user_identity.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';
import 'package:silversole/core/app_icon/app_icon_choice.dart';
import 'package:silversole/shared/pages/app_icon_page.dart';
import 'package:silversole/shared/pages/theme_picker_page.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';
import 'package:silversole/shared/providers/theme_variant_provider.dart';
import 'package:silversole/shared/widgets/build_material_list.dart';
import 'package:silversole/shared/widgets/aa_unlock.dart';
import 'package:silversole/shared/widgets/app_card.dart';
import 'package:silversole/shared/widgets/delete_account_tile.dart';
import 'package:silversole/shared/widgets/privacy_policy_link.dart';
import 'package:silversole/shared/widgets/settings_row.dart';

import '../../core/error/result.dart';
import '../providers/auth_provider.dart';

class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key});

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  /// True while the account is being deleted.
  bool _deleting = false;

  void goToLogin() => context.push('/sign-in');

  /// Deletes the account (already confirmed by the user), then leaves the app
  /// signed out on the sign-in page. A failure that left the account in place
  /// keeps the session; one that could not be confirmed has signed out anyway
  /// (see [AuthService.deleteAccount]).
  Future<void> deleteAccount() async {
    if (_deleting || ref.read(authUserProvider) == null) return;
    final authService = ref.read(authServiceProvider);
    final user = ref.read(authUserProvider.notifier);
    final router = GoRouter.of(context);
    setState(() => _deleting = true);
    final res = await authService.deleteAccount();
    if (mounted) setState(() => _deleting = false);
    switch (res) {
      case Ok<void>():
        user.setUser(null);
        showMessage('delete_account_success'.tr());
        router.go('/sign-in');
      case Error<void>(error: AccountDeletionUnconfirmed()):
        user.setUser(null);
        showErrorSnakeBar(res.error.toString());
        router.go('/sign-in');
      case Error<void>():
        showErrorSnakeBar(res.error.toString());
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final settings = ref.watch(settingsProvider);
    final isSignedIn = user != null;
    final variant = ref.watch(themeVariantProvider);
    final isMascot = variant == AppThemeVariant.mascot;
    final subscribed = ref.watch(subscriptionActiveProvider);
    final scheme = context.colorScheme;
    final notifier = ref.read(settingsProvider.notifier);
    final myDevice = settings.preferredDevice;
    final profile = ref.watch(myFriendProfileProvider).value;
    final nickname = profile?.nickname?.trim();
    final hasNickname = nickname != null && nickname.isNotEmpty;
    final aaActive = ref.watch(activeAgingEnabledProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('person'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            // Who is signed in: the nickname and avatar from the friends
            // profile; the email only when there is no nickname yet (it lives
            // under the account settings). No account id, no plan code.
            AppCard(
              tint: true,
              child: Row(
                children: [
                  if (profile != null && hasNickname)
                    FriendAvatar(
                      preset: profile.avatarPreset,
                      photoPath: profile.photoPath,
                      size: 64,
                    )
                  else
                    isMascot
                        ? Image.asset(
                            'assets/mascot-assets/happy.webp',
                            height: 72,
                            fit: BoxFit.contain,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.user,
                              size: 28,
                              color: scheme.primary,
                            ),
                          ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Text(
                      hasNickname
                          ? nickname
                          : (user?.email ?? 'not_signed_in'.tr()),
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SettingsGroup(
              title: 'my_insoles'.tr(),
              children: [
                SettingsRow(
                  icon: LucideIcons.footprints,
                  title: 'my_devices'.tr(),
                  subtitle: myDevice?.name ?? 'not_binding'.tr(),
                  showChevron: true,
                  onTap: () => context.push('/my-devices'),
                ),
              ],
            ),
            // 銀足樂齡: only accounts with the role see this row (see
            // activeAgingEnabledProvider). Everyone else turns it on through the
            // version tag at the bottom.
            if (aaActive)
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: LucideIcons.activity,
                    title: 'aa_title'.tr(),
                    showChevron: true,
                    onTap: () => context.push('/active-aging'),
                  ),
                ],
              ),
            // 2026-11-01 user：訂閱 149／月、解鎖遊戲兌換站的實物（畫面先做、還沒接金流）
            // 金流接上前不顯示訂閱入口（kSubscriptionOffered）。
            if (kSubscriptionOffered || !isSignedIn || hasNickname)
              SettingsGroup(
                title: 'account'.tr(),
                children: [
                  // The email, once the card above shows the nickname.
                  if (isSignedIn && hasNickname)
                    SettingsRow(
                      icon: LucideIcons.mail,
                      title: 'email'.tr(),
                      subtitle: user.email,
                    ),
                  if (kSubscriptionOffered)
                    SettingsRow(
                      icon: LucideIcons.crown,
                      title: 'subscription'.tr(),
                      subtitle: subscribed
                          ? 'subscription_active'.tr()
                          : 'subscription_price'.tr(
                              args: ['$kSubscriptionMonthlyPrice'],
                            ),
                      showChevron: true,
                      onTap: () => context.push('/subscription'),
                    ),
                  if (!isSignedIn)
                    SettingsRow(
                      icon: LucideIcons.logIn,
                      title: 'sign_in'.tr(),
                      showChevron: true,
                      onTap: goToLogin,
                    ),
                ],
              ),
            if (isSignedIn)
              // Plain words for the two ways to use the app; the stored value
              // stays 'transmitter' / 'observer'.
              buildMaterialList(
                context,
                title: 'identity'.tr(),
                raw: [
                  ListTileData.normal(
                    title: (settings.identity ?? UserIdentity.transmitter.value)
                        .tr(),
                    subtitle: 'identity_tap_to_change'.tr(),
                    icon: LucideIcons.userPlus,
                    onClick: () => switchIdentity(settings.identity),
                    needCheck: true,
                    checkTitle: 'switch_identity'.tr(),
                    checkContent: 'change_identity_check_content'.tr(
                      args: [nextIdentity(settings.identity).tr()],
                    ),
                    trailing: true,
                  ),
                ],
              ),
            SettingsGroup(
              title: 'general'.tr(),
              children: [
                _ChoiceCard<AppTextSize>(
                  icon: LucideIcons.type,
                  title: 'text_size'.tr(),
                  value: settings.textSize,
                  onChanged: notifier.setTextSize,
                  options: {
                    AppTextSize.normal: 'text_size_normal'.tr(),
                    AppTextSize.large: 'text_size_large'.tr(),
                  },
                ),
                // Light or dark comes with the look; there is no separate
                // dark-mode switch.
                SettingsRow(
                  icon: LucideIcons.palette,
                  title: 'switch_theme'.tr(),
                  subtitle: themeNameKey(variant).tr(),
                  showChevron: true,
                  onTap: () => context.push('/themes'),
                ),
                SettingsRow(
                  icon: LucideIcons.smartphone,
                  title: 'app_icon'.tr(),
                  subtitle:
                      (ref.watch(appIconChoiceProvider).value ??
                              AppIconChoice.standard)
                          .nameKey
                          .tr(),
                  showChevron: true,
                  onTap: () => context.push('/app-icon'),
                ),
                SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  title: 'privacy_policy'.tr(),
                  showChevron: true,
                  onTap: () => openPrivacyPolicy(context),
                ),
              ],
            ),
            // Sign out and delete account sit at the very bottom, apart from
            // everyday settings.
            if (isSignedIn)
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: LucideIcons.logOut,
                    title: 'sign_out'.tr(),
                    onTap: signOut,
                  ),
                  DeleteAccountTile(
                    busy: _deleting,
                    onConfirmed: deleteAccount,
                  ),
                ],
              ),
            // The app version. Seven quick taps ask for a 銀足樂齡 code, but only
            // for a signed-in account that does not have the role yet.
            VersionTag(
              onUnlockTap:
                  isSignedIn && Constants.activeAgingOnSupabase && !aaActive
                  ? () => showAaCodeDialog(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings card whose value is one of a few choices, shown as a segmented
/// control so the current choice is visible.
class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: context.colorScheme.onSurface),
              const SizedBox(width: AppSpacing.md),
              Text(title, style: context.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final entry in options.entries)
                ButtonSegment<T>(value: entry.key, label: Text(entry.value)),
            ],
            selected: {value},
            onSelectionChanged: (picked) => onChanged(picked.first),
          ),
        ],
      ),
    );
  }
}
