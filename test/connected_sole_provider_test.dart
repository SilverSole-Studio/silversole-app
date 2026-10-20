import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

const _left = ConnectedSole(
  device: BlePairedDevice(remoteId: 'l', name: 'SilverSole', deviceId: 'L'),
  dfuSupported: true,
);
const _right = ConnectedSole(
  device: BlePairedDevice(remoteId: 'r', name: 'SilverSole', deviceId: 'R'),
  dfuSupported: true,
);

/// Settings whose primary sole is 'R'.
class _PrimaryIsRight extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
    pairedDevicesList: [
      BlePairedDevice(remoteId: 'l', name: 'SilverSole', deviceId: 'L'),
      BlePairedDevice(
        remoteId: 'r',
        name: 'SilverSole',
        deviceId: 'R',
        isPreferred: true,
      ),
    ],
  );
}

void main() {
  test(
    'clearing nothing is not a write, so a provider may do it while it builds',
    () {
      // The BLE foreground controller clears connected soles from a
      // fireImmediately listener while it is still building (the paired list
      // is empty until settings load). Riverpod forbids a provider modifying
      // another during its build, so a clear with nothing to clear must not
      // touch state.
      final clearsWhileBuilding = Provider<void>((ref) {
        ref.read(connectedSolesProvider.notifier).clear('L');
        ref.read(connectedSolesProvider.notifier).clearAll();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(clearsWhileBuilding);
      expect(container.read(connectedSolesProvider), isEmpty);
    },
  );

  test('each sole is tracked on its own and cleared on its own', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(connectedSolesProvider.notifier);

    notifier.set('L', _left);
    notifier.set('R', _right);
    expect(container.read(connectedSolesProvider).keys, {'L', 'R'});

    // One foot dropping its link must not take the other down with it.
    notifier.clear('L');
    expect(container.read(connectedSolesProvider).keys, {'R'});

    notifier.clearAll();
    expect(container.read(connectedSolesProvider), isEmpty);
  });

  test('connectedSoleProvider follows the primary sole', () {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_PrimaryIsRight.new)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(connectedSolesProvider.notifier);

    expect(container.read(connectedSoleProvider), isNull);

    notifier.set('L', _left);
    // Only the other foot is connected, so that is what the single-sole UI
    // has to talk about rather than showing nothing.
    expect(container.read(connectedSoleProvider), _left);

    notifier.set('R', _right);
    expect(container.read(connectedSoleProvider), _right);
  });
}
