import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

part 'connected_sole.freezed.dart';

/// The sole this app is connected to right now, as its last handshake saw it.
@freezed
abstract class ConnectedSole with _$ConnectedSole {
  const factory ConnectedSole({
    required BlePairedDevice device,

    /// The DFU `version`, e.g. `0.4.0-rc.1`; null when it could not be read.
    String? firmwareVersion,

    /// False on firmware without the DFU service (wired updates only).
    required bool dfuSupported,
  }) = _ConnectedSole;
}
