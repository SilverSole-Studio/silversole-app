import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';

void main() {
  test(
    'clearing nothing is not a write, so a provider may do it while it builds',
    () {
      // The BLE foreground controller clears the connected sole from a
      // fireImmediately listener while it is still building (the paired list
      // is empty until settings load). Riverpod forbids a provider modifying
      // another during its build, so a clear with nothing to clear must not
      // touch state.
      final clearsWhileBuilding = Provider<void>(
        (ref) => ref.read(connectedSoleProvider.notifier).clear(),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(clearsWhileBuilding);
      expect(container.read(connectedSoleProvider), isNull);
    },
  );

  test('clear still drops a connected sole', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(connectedSoleProvider.notifier);

    notifier.set(
      const ConnectedSole(
        device: BlePairedDevice(remoteId: 'M', name: 'SilverSole'),
        dfuSupported: true,
      ),
    );
    notifier.clear();
    expect(container.read(connectedSoleProvider), isNull);
  });
}
