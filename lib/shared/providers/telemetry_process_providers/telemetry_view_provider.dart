import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';

/// Live telemetry for screens that mean "the sole" rather than a named foot.
/// Follows the primary sole — see [primarySoleKeyProvider].
final telemetryViewProvider = Provider<LiveTelemetryState>(
  (ref) => ref.watch(primaryTelemetryProvider),
);
