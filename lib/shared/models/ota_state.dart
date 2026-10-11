import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';

part 'ota_state.freezed.dart';

enum OtaPhase {
  idle,
  downloading,
  transferring,

  /// Everything is in flash; the sole is checking the hash and signature.
  verifying,

  /// The sole is installing the image and booting it; the app is waiting to
  /// find it again.
  rebooting,
  succeeded,

  /// The sole came back on its old version.
  notUpdated,

  /// The sole did not come back, or its version could not be read.
  unconfirmed,

  /// A developer's own image: there is no expected version to judge by.
  localFinished,
  failed,
}

@freezed
abstract class OtaState with _$OtaState {
  const OtaState._();

  const factory OtaState({
    @Default(OtaPhase.idle) OtaPhase phase,
    @Default(0) int committed,
    @Default(0) int size,
    String? fromVersion,
    String? toVersion,

    /// The version the sole reported after it came back.
    String? readVersion,

    /// The sole was found by elimination, not by its ID (old firmware).
    @Default(false) bool probable,
    DfuFailure? failure,
  }) = _OtaState;

  /// From the download until the verdict: the page cannot be left and no
  /// second update can start.
  bool get busy => switch (phase) {
    OtaPhase.downloading ||
    OtaPhase.transferring ||
    OtaPhase.verifying ||
    OtaPhase.rebooting => true,
    _ => false,
  };

  double get progress => size == 0 ? 0 : committed / size;
}
