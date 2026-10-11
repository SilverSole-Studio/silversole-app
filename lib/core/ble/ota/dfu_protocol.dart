import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// SilverSole OTA BLE protocol v2, byte for byte as the firmware repo's
// docs/ota-ble-protocol.md defines it. Every multi-byte integer is
// little-endian.

const dfuProtocolVersion = 0x02;

/// The sole buffers this much before each flash write, and reports progress
/// (`committed`) once per page — the transfer's unit of flow control.
const dfuPageSize = 4096;

/// The firmware's ACTIVE slot: 416 KiB.
const dfuMaxImageSize = 425984;

const dfuSignatureLength = 64;

/// APPLY is 65 bytes and one write carries at most `MTU − 3`; the sole cannot
/// take long writes (it stalls for ~30 s, then drops the link).
const dfuMinMtu = 68;

/// The `data` characteristic's declared maximum.
const _dfuMaxDataWrite = 244;

const _opStart = 0x01;
const _opApply = 0x02;
const _opStatus = 0xA0;

enum DfuState { idle, receiving, verifying, applied }

enum DfuResult {
  ok,
  badCommand,
  badState,
  unsupportedVersion,
  tooLarge,
  lowBattery,
  batteryUnknown,
  badOffset,
  hashMismatch,
  flashError,
  badSignature,
}

/// One STATUS notification: `[0xA0, state, result, committed u32 LE]`.
@immutable
class DfuStatus {
  const DfuStatus(this.state, this.result, this.committed);

  final DfuState state;
  final DfuResult result;

  /// Bytes already written to flash: a multiple of [dfuPageSize], except at
  /// the very end, where it equals the image size.
  final int committed;

  /// Null for anything that is not a well-formed STATUS packet.
  static DfuStatus? parse(List<int> bytes) {
    if (bytes.length != 7 || bytes[0] != _opStatus) return null;
    if (bytes[1] >= DfuState.values.length) return null;
    if (bytes[2] >= DfuResult.values.length) return null;
    final committed = ByteData.sublistView(
      Uint8List.fromList(bytes),
    ).getUint32(3, Endian.little);
    return DfuStatus(
      DfuState.values[bytes[1]],
      DfuResult.values[bytes[2]],
      committed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DfuStatus &&
      other.state == state &&
      other.result == result &&
      other.committed == committed;

  @override
  int get hashCode => Object.hash(state, result, committed);

  @override
  String toString() => '${state.name}/${result.name} committed=$committed';
}

/// START: `[0x01, 0x02, size u32 LE, sha256 × 32]`, 38 bytes.
Uint8List dfuStartCommand(int size, List<int> sha256) {
  if (sha256.length != 32) {
    throw ArgumentError.value(sha256.length, 'sha256', 'must be 32 bytes');
  }
  final out = Uint8List(38);
  out[0] = _opStart;
  out[1] = dfuProtocolVersion;
  ByteData.sublistView(out).setUint32(2, size, Endian.little);
  out.setRange(6, 38, sha256);
  return out;
}

/// APPLY: `[0x02, signature × 64]`, 65 bytes.
Uint8List dfuApplyCommand(List<int> signature) {
  if (signature.length != dfuSignatureLength) {
    throw ArgumentError.value(
      signature.length,
      'signature',
      'must be 64 bytes',
    );
  }
  return Uint8List.fromList([_opApply, ...signature]);
}

const List<int> dfuAbortCommand = [0x03];
const List<int> dfuGetStatusCommand = [0x04];

/// A data packet: `[offset u32 LE] + payload`.
Uint8List dfuDataPacket(int offset, List<int> chunk) {
  final out = Uint8List(4 + chunk.length);
  ByteData.sublistView(out).setUint32(0, offset, Endian.little);
  out.setRange(4, out.length, chunk);
  return out;
}

/// The most image bytes one data packet can carry at [mtu].
int dfuPayloadSize(int mtu) => math.min(mtu - 3, _dfuMaxDataWrite) - 4;
