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
Widget applySystemFontScale(BuildContext context, Widget? child) {
  final real = systemFontScaleOf(MediaQuery.textScalerOf(context));
  return SystemFontScale(
    scale: real,
    child: MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: kMaxAppTextScale,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
