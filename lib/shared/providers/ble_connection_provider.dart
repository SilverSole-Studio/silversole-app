import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';

final bleConnectProvider = Provider<BleConnectionService>((_) => BleConnectionService());