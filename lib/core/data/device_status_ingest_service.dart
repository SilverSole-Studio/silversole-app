import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceStatusIngestService {
  DeviceStatusIngestService();

  Future<Result<void>> ingestDeviceStatus({
    required BlePairedDevice device,
    required DeviceStatusModel payload,
  }) async {
    try {
      final deviceId = device.deviceId ?? payload.deviceId;
      if (device.deviceId != null && device.deviceId != payload.deviceId) {
        return Result.error(
          Exception(
            'Device id mismatch, expected: ${device.deviceId}, got: ${payload.deviceId}',
          ),
        );
      }

      await persistLatestStatus(deviceId: deviceId, payload: payload);
      return Result.ok(null);
    } catch (e) {
      return Result.error(
        Exception('Ingest device status failed(${device.deviceId}): $e'),
      );
    }
  }

  Future<void> persistLatestStatus({
    required String deviceId,
    required DeviceStatusModel payload,
  }) async {
    if (deviceId != payload.deviceId) {
      throw Exception(
        'Device id mismatch, expected: $deviceId, got: ${payload.deviceId}',
      );
    }
    final supabase = Supabase.instance.client;

    final response = await supabase.functions.invoke(
      'heartbeat',
      body: payload.toJson(),
    );
    final statusCode = response.status;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(
        'Failed to persist latest status.\n status code: ${response.data}\nbody: ${response.data}',
      );
    }
  }
}
