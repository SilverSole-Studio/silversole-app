import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';

/// Every sole this app is connected to right now, keyed by identityKey.
///
/// Set by the BLE foreground controller on each sole's handshake and cleared
/// on that sole's link loss — one foot dropping never clears the other.
class ConnectedSolesNotifier extends Notifier<Map<String, ConnectedSole>> {
  @override
  Map<String, ConnectedSole> build() => const {};

  void set(String identityKey, ConnectedSole sole) =>
      state = {...state, identityKey: sole};

  /// A no-op when nothing is recorded for [identityKey]. The foreground
  /// controller clears from a `fireImmediately` listener while it is still
  /// building, and Riverpod forbids a provider writing another during its
  /// build — so only write when there is something to drop.
  void clear(String identityKey) {
    if (!state.containsKey(identityKey)) return;
    state = {...state}..remove(identityKey);
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final connectedSolesProvider =
    NotifierProvider<ConnectedSolesNotifier, Map<String, ConnectedSole>>(
      ConnectedSolesNotifier.new,
    );

/// The connected sole the single-sole UI means — the firmware card, the status
/// card, an update. The primary sole when it is connected (see
/// [primarySoleKeyProvider]), otherwise whichever sole is, so a screen never
/// goes blank just because the other foot is the one on the air.
final connectedSoleProvider = Provider<ConnectedSole?>((ref) {
  final soles = ref.watch(connectedSolesProvider);
  if (soles.isEmpty) return null;
  final key = ref.watch(primarySoleKeyProvider);
  return soles[key] ?? soles.values.first;
});
