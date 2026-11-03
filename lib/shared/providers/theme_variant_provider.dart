import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';

/// The look the app is drawn in right now.
///
/// The chosen look ([SettingsNotifier.setThemeVariant]) unless it needs a
/// subscription the account does not have (it ran out, or the answer from the
/// server has not arrived yet): then the default look, 粗哥手繪小鎮風. The
/// choice itself is kept, so renewing brings the look back.
final themeVariantProvider = Provider<AppThemeVariant>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.themeVariant));
  if (chosen.requiresSubscription && !ref.watch(subscriptionActiveProvider)) {
    return AppThemeVariant.mascot;
  }
  return chosen;
});
