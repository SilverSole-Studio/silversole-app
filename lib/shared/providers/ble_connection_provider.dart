import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';

/// Every live sole session, one per foot. Base-timestamp sync is part of each
/// connection's own handshake, so there is nothing to drive from here.
final soleSessionsProvider = Provider<SoleSessionRegistry>(
  (_) => SoleSessionRegistry(),
);
