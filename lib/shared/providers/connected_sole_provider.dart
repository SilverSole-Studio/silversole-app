import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/connected_sole.dart';

/// Set by the BLE foreground controller on every handshake, cleared on every
/// link loss.
class ConnectedSoleNotifier extends Notifier<ConnectedSole?> {
  @override
  ConnectedSole? build() => null;

  void set(ConnectedSole sole) => state = sole;

  /// A no-op when nothing is connected. The foreground controller clears from
  /// a `fireImmediately` listener while it is still building, and Riverpod
  /// forbids a provider writing another during its build — so only write when
  /// there is a sole to drop.
  void clear() {
    if (state != null) state = null;
  }
}

final connectedSoleProvider =
    NotifierProvider<ConnectedSoleNotifier, ConnectedSole?>(
      ConnectedSoleNotifier.new,
    );
