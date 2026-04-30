import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

final bleConnectProvider = Provider<BleConnectionService>(
  (_) => BleConnectionService(),
);

extension BleConnectionServiceTimestampX on BleConnectionService {
  Future<Result<void>> writeBaseTimestamp(
    BlePairedDevice device, {
    DateTime? timestamp,
  }) {
    final value = (timestamp ?? DateTime.now()).millisecondsSinceEpoch
        .toString();
    return writeStringCharacteristic(
      device,
      serviceUuid: serviceUuid,
      characteristicUuid: baseTimestampCharUuid,
      value: value,
    );
  }
}
