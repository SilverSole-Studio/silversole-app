import 'dart:ui' show Brightness;

/// Which visual language the app renders in. Five looks, chosen in 設定 →
/// 切換主題; light or dark is part of the look (there is no separate dark-mode
/// switch).
///
/// Each look owns its own `ThemeData` (see `appThemeFor`); [mascot], the two
/// tech looks, [dashboard] and [journal] each own their home page, because they
/// arrange it differently. Shared providers and the data layer stay common.
///
/// Free for everyone: [mascot] (the default), [techLight], [techDark].
/// Only with an active subscription: [dashboard], [journal].
/// 限時免費: while true, 大數字儀表板 and 紙本手帳 can be picked by everyone
/// (they are still the two looks meant for subscribers). Flip to false when
/// the subscription can be bought and they go back behind it.
const bool kPaidThemesFreeTrial = true;

enum AppThemeVariant {
  /// A · 粗哥手繪小鎮風 — sky and grass, thick brown outlines with a hard
  /// shadow, the mascot's yellow. The default.
  mascot('mascot'),

  /// 極簡科技・白 — the plain blue-accent design, light.
  techLight('tech_light'),

  /// 極簡科技・黑 — the same design, dark.
  techDark('tech_dark'),

  /// B · 大數字健康儀表板 — warm black, brand yellow, big numerals.
  dashboard('dashboard'),

  /// C · 溫暖紙本手帳風 — dot-grid paper, sticky notes, handwritten Kai.
  journal('journal');

  const AppThemeVariant(this.wireName);

  /// What is stored on the phone.
  final String wireName;

  /// The looks anyone can pick.
  static const List<AppThemeVariant> free = [mascot, techLight, techDark];

  /// Whether picking this look needs a subscription.
  bool get requiresSubscription => this == dashboard || this == journal;

  /// Whether this look is locked for an account without a subscription right
  /// now: [requiresSubscription], unless the 限時免費 period is on.
  bool get lockedWithoutSubscription =>
      requiresSubscription && !kPaidThemesFreeTrial;

  /// Dark looks: the [ThemeData] and the system bars follow this.
  Brightness get brightness => switch (this) {
    techDark || dashboard => Brightness.dark,
    _ => Brightness.light,
  };

  /// The two 極簡科技 looks share one set of pages.
  bool get isTech => this == techLight || this == techDark;

  /// Resolves what is stored on the phone, including what older versions
  /// wrote:
  ///  * nothing → [mascot] (the default);
  ///  * `mascot` (the old 插畫 theme) → [mascot];
  ///  * `classic` (the old 經典 theme) → [techDark] when the old dark-mode
  ///    switch was on ([storedDarkMode] is `'true'`), else [techLight].
  /// Anything unknown falls back to [mascot].
  static AppThemeVariant fromStored(String? value, {String? storedDarkMode}) {
    if (value == 'classic') {
      return storedDarkMode == 'true' ? techDark : techLight;
    }
    for (final v in values) {
      if (v.wireName == value) return v;
    }
    return mascot;
  }
}
