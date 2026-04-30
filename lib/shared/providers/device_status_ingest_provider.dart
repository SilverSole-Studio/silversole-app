import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/device_status_ingest_service.dart';

final deviceStatusIngestProvider = Provider<DeviceStatusIngestService>(
  (_) => DeviceStatusIngestService(),
);
