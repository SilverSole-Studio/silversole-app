import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

part 'app_settings.freezed.dart';

enum TransmissionMethod { bluetooth, wifi }

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    String? identity,
    String? deviceId,
    @Default(true) bool darkMode,
    @Default(TransmissionMethod.bluetooth) TransmissionMethod transmissionMethod,
    @Default(<BlePairedDevice>[]) List<BlePairedDevice> pairedDevicesList,
  }) = _AppSettings;

  const AppSettings._();

  BlePairedDevice? get preferredDevice => pairedDevicesList.firstWhereOrNull((d) => d.isPreferred);
}

extension TransmissionMethodValue on TransmissionMethod {
  static TransmissionMethod? fromValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final method in TransmissionMethod.values) {
      if (method.name == value) return method;
    }
    return null;
  }

  static String toFormatString(TransmissionMethod method) => method.name.tr();
}
