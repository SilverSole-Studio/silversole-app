import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// What a foot with no sole on it reads — never a stale window from a sole
/// that has been unpaired or re-assigned.
const _noTelemetry = LiveTelemetryState();

/// The identityKey of the sole worn on [side], or null while that foot has
/// none — which is every foot until the wearer has calibrated.
final footSoleKeyProvider = Provider.family<String?, FootSide>(
  (ref, side) =>
      ref.watch(settingsProvider.select((s) => s.soleFor(side)?.identityKey)),
);

/// Live telemetry from the sole on [side]; empty while that foot has no sole.
final footTelemetryProvider = Provider.family<LiveTelemetryState, FootSide>((
  ref,
  side,
) {
  final key = ref.watch(footSoleKeyProvider(side));
  return key == null ? _noTelemetry : ref.watch(liveTelemetryProvider(key));
});

/// The sole the single-sole UI means: the right foot when one is assigned,
/// else the primary device, else the first paired sole. Null when nothing is
/// paired.
final primarySoleKeyProvider = Provider<String?>(
  (ref) => ref.watch(
    settingsProvider.select(
      (s) =>
          s.soleFor(FootSide.right)?.identityKey ??
          s.preferredDevice?.identityKey ??
          s.pairedDevicesList.firstOrNull?.identityKey,
    ),
  ),
);

/// Live telemetry from the primary sole — what every screen written before
/// two feet existed reads, through `telemetryViewProvider`.
final primaryTelemetryProvider = Provider<LiveTelemetryState>((ref) {
  final key = ref.watch(primarySoleKeyProvider);
  return key == null ? _noTelemetry : ref.watch(liveTelemetryProvider(key));
});

/// What to draw on the right foot.
///
/// The sole assigned to it; or — before anyone has calibrated — whichever sole
/// is primary, as long as it is not the one already assigned to the left foot.
/// A single uncalibrated sole has drawn the right foot since the app shipped
/// and still does, while the left sole's readings never leak onto the right
/// foot just because it is the only sole paired.
///
/// The left foot reads [footTelemetryProvider] directly because an unassigned
/// sole must never be drawn there; the right foot needs this provider to keep
/// the single-uncalibrated-sole behaviour the app shipped with.
final rightFootTelemetryProvider = Provider<LiveTelemetryState>((ref) {
  final assigned = ref.watch(footSoleKeyProvider(FootSide.right));
  if (assigned != null) return ref.watch(liveTelemetryProvider(assigned));

  final leftKey = ref.watch(footSoleKeyProvider(FootSide.left));
  final fallback = ref.watch(primarySoleKeyProvider);
  if (fallback == null || fallback == leftKey) return _noTelemetry;
  return ref.watch(liveTelemetryProvider(fallback));
});
