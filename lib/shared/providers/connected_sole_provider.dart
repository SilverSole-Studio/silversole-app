import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/connected_sole.dart';

/// Set by the BLE foreground controller on every handshake, cleared on every
/// link loss.
class ConnectedSoleNotifier extends Notifier<ConnectedSole?> {
  @override
  ConnectedSole? build() => null;

  void set(ConnectedSole sole) => state = sole;

  void clear() => state = null;
}

final connectedSoleProvider =
    NotifierProvider<ConnectedSoleNotifier, ConnectedSole?>(
      ConnectedSoleNotifier.new,
    );
