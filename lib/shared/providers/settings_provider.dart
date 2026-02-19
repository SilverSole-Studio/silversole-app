import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/user_identity.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    var identity = await loadLocalValue(LocalSavableKey.identity);
    if (identity == null) {
      identity = UserIdentity.transmitter.value;
      await saveLocalValue(LocalSavableKey.identity, identity);
    }
    final deviceId = await loadLocalValue(LocalSavableKey.deviceId);
    final darkModeRaw = await loadLocalValue(LocalSavableKey.darkMode);
    final darkMode = switch (darkModeRaw) {
      'true' => true,
      'false' => false,
      _ => true,
    };
    if (darkModeRaw == null) {
      await saveLocalValue(LocalSavableKey.darkMode, 'true');
    }
    final methodString = await loadLocalValue(LocalSavableKey.transmissionMethod);
    final transmissionMethod = switch (methodString) {
      'bluetooth' => TransmissionMethod.bluetooth,
      'wifi' => TransmissionMethod.wifi,
      _ => TransmissionMethod.bluetooth,
    };
    final pairedDevicesList = await loadLocalPairedDevices() ?? [];
    state = state.copyWith(
      identity: identity,
      deviceId: deviceId,
      darkMode: darkMode,
      transmissionMethod: transmissionMethod,
      pairedDevicesList: pairedDevicesList,
    );
  }

  Future<void> setIdentity(String value) async {
    await saveLocalValue(LocalSavableKey.identity, value);
    state = state.copyWith(identity: value);
  }

  Future<void> setDeviceId(String value) async {
    await saveLocalValue(LocalSavableKey.deviceId, value);
    state = state.copyWith(deviceId: value);
  }

  Future<void> setDarkMode(bool value) async {
    await saveLocalValue(LocalSavableKey.darkMode, value ? 'true' : 'false');
    state = state.copyWith(darkMode: value);
  }

  Future<void> setTransmissionMethod(TransmissionMethod method) async {
    await saveLocalValue(LocalSavableKey.transmissionMethod, method.name);
    state = state.copyWith(transmissionMethod: method);
  }

  Future<void> setPairedDevices(List<BlePairedDevice> devicesList) async {
    await setLocalPairedDevices(devicesList);
    state = state.copyWith(pairedDevicesList: devicesList);
  }

  Future<void> addOrUpdatePairedDevice(BlePairedDevice device) async {
    await addOrUpdateLocalPairedDevice(device);
    final updated = await loadLocalPairedDevices() ?? [];
    state = state.copyWith(pairedDevicesList: updated);
  }

  Future<void> removePairedDevice(BlePairedDevice targetDevice) async {
    await removeLocalPairedDevice(targetDevice);
    final updated = await loadLocalPairedDevices() ?? [];
    state = state.copyWith(pairedDevicesList: updated);
  }

  Future<void> setPreferredDevice(BlePairedDevice target) async {
    await setLocalPreferredDevice(target);
    final updated = await loadLocalPairedDevices() ?? [];
    state = state.copyWith(pairedDevicesList: updated);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
