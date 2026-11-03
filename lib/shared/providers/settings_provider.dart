import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/user_identity.dart';

/// The phone's font-size setting right now (1.0 = default). A provider so
/// tests can pretend the phone is set to a large font.
final systemFontScaleReaderProvider = Provider<double Function()>(
  (ref) =>
      () =>
          (PlatformDispatcher.instance.scaleFontSize(14) / 14 * 100).round() /
          100,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    // Read before the first await, while the provider is surely alive.
    final systemFontScale = ref.read(systemFontScaleReaderProvider)();
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
      // Nothing stored: light. Dark is only ever an explicit choice.
      _ => false,
    };
    // Nothing stored = first launch: a phone already set to a large font
    // starts on 「大」, anyone else on 「標準」; stored after that, so the
    // user's own choice wins from then on.
    var textSize = AppTextSize.fromWireName(
      await loadLocalValue(LocalSavableKey.textSize),
    );
    if (textSize == null) {
      textSize = initialTextSizeFor(systemFontScale);
      await saveLocalValue(LocalSavableKey.textSize, textSize.wireName);
    }
    // Defaults to the mascot design; only an explicit choice switches the app to
    // the classic design.
    final themeVariant = AppThemeVariant.fromName(
      await loadLocalValue(LocalSavableKey.themeVariant),
    );
    final methodString = await loadLocalValue(
      LocalSavableKey.transmissionMethod,
    );
    final transmissionMethod = switch (methodString) {
      'bluetooth' => TransmissionMethod.bluetooth,
      'wifi' => TransmissionMethod.wifi,
      _ => TransmissionMethod.bluetooth,
    };
    final pairedDevicesList = await loadLocalPairedDevices() ?? [];
    final firmwareDevMode =
        await loadLocalValue(LocalSavableKey.firmwareDevMode) == 'true';
    state = state.copyWith(
      identity: identity,
      deviceId: deviceId,
      darkMode: darkMode,
      textSize: textSize,
      themeVariant: themeVariant,
      transmissionMethod: transmissionMethod,
      pairedDevicesList: pairedDevicesList,
      firmwareDevMode: firmwareDevMode,
    );
  }

  Future<void> setThemeVariant(AppThemeVariant variant) async {
    await saveLocalValue(LocalSavableKey.themeVariant, variant.name);
    state = state.copyWith(themeVariant: variant);
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

  Future<void> setTextSize(AppTextSize value) async {
    await saveLocalValue(LocalSavableKey.textSize, value.wireName);
    state = state.copyWith(textSize: value);
  }

  Future<void> setTransmissionMethod(TransmissionMethod method) async {
    await saveLocalValue(LocalSavableKey.transmissionMethod, method.name);
    state = state.copyWith(transmissionMethod: method);
  }

  Future<void> setFirmwareDevMode(bool value) async {
    await saveLocalValue(
      LocalSavableKey.firmwareDevMode,
      value ? 'true' : 'false',
    );
    state = state.copyWith(firmwareDevMode: value);
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

  /// Remembers [percent] as the last battery level of the sole whose
  /// [BlePairedDevice.identityKey] is [identityKey]. Only touches an existing
  /// entry, so a sole removed mid-session is not re-added.
  Future<void> setLastBatteryPercent(String identityKey, int percent) async {
    final devices = await loadLocalPairedDevices() ?? [];
    final index = devices.indexWhere((d) => d.identityKey == identityKey);
    if (index < 0) return;
    devices[index] = devices[index].copyWith(lastBatteryPercent: percent);
    await setPairedDevices(devices);
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

  /// Assigns [side] to the sole keyed [identityKey], clearing that side from
  /// any other sole — see [assignFootSide].
  Future<void> setFootSide(String identityKey, FootSide? side) async {
    await setLocalFootSide(identityKey, side);
    state = state.copyWith(
      pairedDevicesList: await loadLocalPairedDevices() ?? [],
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
