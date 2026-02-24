import 'dart:convert';

import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/queued_telemetry_model.dart';

class TelemetryIngestService {
  TelemetryIngestService();

  /// Ingests one IMU payload from a BLE [device].
  ///
  /// Flow:
  /// - Resolve the cloud-facing device id from [device.deviceId].
  /// - Persist the payload via [enqueue].
  /// - Attempt immediate upload via [flushQueue].
  ///
  /// Returns [Result.error] when the device is not bound or any step fails.
  Future<Result<void>> ingestImuData({
    required BlePairedDevice device,
    required ImuNotifyDataModel payload,
    DateTime? ts,
  }) async {
    try {
      final deviceId = device.deviceId;
      final eventTs = ts ?? DateTime.now();
      if (deviceId == null) return Result.error(Exception('Device id not bound with BLE device'));
      await enqueue(deviceId: deviceId, data: payload, ts: eventTs);
      await flushQueue(deviceId: device.deviceId);
      return Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Ingest imu data failed: $e'));
    }
  }

  Future<Result<void>> ingestDeviceStatusData({
    required BlePairedDevice device,
    required Map<String, dynamic> payload, //TODO: make device status model
    DateTime? ts,
  }) async {
    try {
      final deviceId = device.deviceId;
      //TODO: make device status model
      // final eventTs = ts ?? DateTime.now();
      if (deviceId == null) return Result.error(Exception('Device id not bound with BLE device'));
      // await enqueue(deviceId: deviceId, data: payload, ts: eventTs);
      await flushQueue(deviceId: device.deviceId);
      return Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Ingest device status failed: $e'));
    }
  }

  /// Decodes raw BLE bytes [payload] into a JSON map.
  ///
  /// Throws if UTF-8 or JSON decoding fails.
  Map<String, dynamic> parsePayload(List<int> payload) {
    final text = utf8.decode(payload);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// Adds one telemetry record to the local upload queue.
  ///
  /// [deviceId] is the cloud device id, [data] is the parsed IMU payload,
  /// and [ts] is the event timestamp.
  Future<void> enqueue({required String deviceId, required ImuNotifyDataModel data, required DateTime ts}) async {}

  /// Flushes queued telemetry items to backend, optionally filtered by [deviceId].
  ///
  /// Returns [Result.ok] when the flush run completes without fatal errors.
  Future<Result<void>> flushQueue({String? deviceId}) async {
    return Result.ok(null);
  }

  /// Uploads a single queued telemetry [item] to backend.
  ///
  /// This is typically called by [flushQueue].
  Future<Result<void>> uploadOne(QueuedTelemetry item) async {
    return Result.ok(null);
  }

  /// Schedules a retry cycle for failed uploads.
  Future<void> scheduleRetry() async {}
}
