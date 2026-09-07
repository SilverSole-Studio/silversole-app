import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';

/// The single live sole session. Base-timestamp sync is part of the service's
/// per-connection handshake, so there is nothing to drive from here.
final bleConnectProvider = Provider<BleConnectionService>(
  (_) => BleConnectionService(),
);
