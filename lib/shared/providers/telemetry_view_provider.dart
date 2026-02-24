import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';

import 'live_telemetry_notifier.dart';

final telemetryViewProvider = Provider<LiveTelemetryState>((ref) => ref.watch(liveTelemetryProvider));