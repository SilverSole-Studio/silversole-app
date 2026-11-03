import 'package:flutter/widgets.dart';

/// Upper bound for how much the phone's font-size setting may enlarge the
/// app's own (Flutter) text. Seniors often run the system font at its largest
/// (Android up to 2.0, iOS Dynamic Type up to ~3.1); unclamped, fixed-height
/// widgets (bars, buttons, chips) overflow. 1.3 keeps text clearly bigger than
/// default without breaking layouts. Games on the web side have their own
/// large-text mode — see [SystemFontScale].
const double kMaxAppTextScale = 1.3;

/// The system font scale from which the web games should switch on their own
/// large-text mode (the app already enlarges its own text up to
/// [kMaxAppTextScale]).
const double kLargeTextScaleThreshold = 1.15;

/// How much the app's own text is scaled on top of the phone's font setting
/// (settings page 「文字大小」). 「大」 is the app's full size; 「標準」 shrinks
/// everything to the size a regular app uses.
enum AppTextSize {
  normal,
  large;

  /// The value stored in settings and sent to the web games (`textSize`).
  String get wireName => name;

  /// [wireName] back to the enum; null for anything else (nothing stored yet).
  static AppTextSize? fromWireName(String? value) {
    for (final size in values) {
      if (size.name == value) return size;
    }
    return null;
  }
}

/// How much smaller 「標準」 text is than 「大」 (0.9 = 10% smaller). One knob
/// for the whole app: it multiplies the text scaler, no widget sets its own.
const double kStandardTextFactor = 0.9;

/// The text size to start with when nothing is stored yet (first launch): 「大」
/// when the phone's font setting is already [kLargeTextScaleThreshold] or more,
/// 「標準」 otherwise. After that, the user's own choice wins.
AppTextSize initialTextSizeFor(double systemFontScale) =>
    systemFontScale >= kLargeTextScaleThreshold
    ? AppTextSize.large
    : AppTextSize.normal;

/// The scale factor the system asks for, as one number. Works for the
/// non-linear scalers Android 14+ uses by sampling at 14 logical pixels.
double systemFontScaleOf(TextScaler scaler) {
  if (scaler == TextScaler.noScaling) return 1.0;
  final scale = scaler.scale(14) / 14;
  if (!scale.isFinite || scale <= 0) return 1.0;
  return (scale * 100).round() / 100;
}

/// Carries the phone's real (unclamped) font scale down the tree, below the
/// place where [applySystemFontScale] clamps `MediaQuery.textScaler`.
class SystemFontScale extends InheritedWidget {
  const SystemFontScale({super.key, required this.scale, required super.child});

  final double scale;

  /// The system font scale, `1.0` when no [SystemFontScale] is above.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SystemFontScale>()?.scale ??
      1.0;

  @override
  bool updateShouldNotify(SystemFontScale oldWidget) =>
      scale != oldWidget.scale;
}

/// For `MaterialApp.builder`: caps the text scaler at [kMaxAppTextScale]
/// and keeps the real system scale available through [SystemFontScale].
/// With [AppTextSize.normal] the capped scale is then multiplied by
/// [kStandardTextFactor]; [AppTextSize.large] is the capped scale as it is.
Widget applySystemFontScale(
  BuildContext context,
  Widget? child, {
  AppTextSize textSize = AppTextSize.large,
}) {
  final real = systemFontScaleOf(MediaQuery.textScalerOf(context));
  final inner = child ?? const SizedBox.shrink();
  return SystemFontScale(
    scale: real,
    child: textSize == AppTextSize.large
        ? MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: kMaxAppTextScale,
            child: inner,
          )
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                real.clamp(1.0, kMaxAppTextScale) * kStandardTextFactor,
              ),
            ),
            child: inner,
          ),
  );
}
