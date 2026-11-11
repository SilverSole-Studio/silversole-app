import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

/// The three home-screen icons the wearer can pick (我的 → App 圖示).
///
/// [standard] is the icon the app ships with; the other two are alternates
/// (Android `activity-alias` `.icon_b` / `.icon_c`, iOS `CFBundleAlternateIcons`
/// `icon_b` / `icon_c`).
enum AppIconChoice {
  standard(null, 'app_icon_default', 'assets/app_icon/preview/cuge.png'),
  wave('icon_b', 'app_icon_wave', 'assets/app_icon/preview/b.png'),
  sLogo('icon_c', 'app_icon_s', 'assets/app_icon/preview/c.png');

  const AppIconChoice(this.platformName, this.nameKey, this.previewAsset);

  /// What is handed to the platform; null = the default icon.
  final String? platformName;
  final String nameKey;
  final String previewAsset;

  /// Reads what the platform reports as the current icon: null or `DEFAULT`
  /// (Android's default alias, possibly fully qualified) is [standard];
  /// anything unknown is [standard] too.
  static AppIconChoice fromPlatformName(String? name) {
    if (name == null || name.isEmpty) return standard;
    for (final c in values) {
      final n = c.platformName;
      if (n != null && (name == n || name.endsWith('.$n'))) return c;
    }
    return standard;
  }
}

/// Thin wrapper over the plugin so pages (and tests) do not touch it directly.
abstract class AppIconGateway {
  Future<AppIconChoice> current();
  Future<void> choose(AppIconChoice choice);
}

class PluginAppIconGateway implements AppIconGateway {
  const PluginAppIconGateway();

  @override
  Future<AppIconChoice> current() async => AppIconChoice.fromPlatformName(
    await FlutterDynamicIconPlus.alternateIconName,
  );

  @override
  Future<void> choose(AppIconChoice choice) =>
      FlutterDynamicIconPlus.setAlternateIconName(
        iconName: choice.platformName,
      );
}
