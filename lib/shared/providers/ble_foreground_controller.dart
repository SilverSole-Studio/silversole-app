import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';

import 'settings_provider.dart';

final bleForegroundControlProvider = Provider<void>((ref) {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  ref.listen<String?>(settingsProvider.select((s) => s.preferredDevice?.remoteId), (prev, next) {
    if (prev == next) return;
    if (next != null) {
      unawaited(startBleService());
    } else {
      unawaited(stopBleService());
    }
  }, fireImmediately: true);
});
