import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';

/// The sole's DFU service in software, following the firmware's rules in
/// docs/ota-ble-protocol.md: one flash page (4096 bytes) per STATUS, BAD_OFFSET
/// once per loss of sync, and the SHA-256 checked on APPLY.
class FakeDfuSole implements DfuLink {
  FakeDfuSole({this.mtu = 247});

  @override
  int mtu;

  @override
  bool isConnected = true;

  /// Answers to START, in order, before one succeeds.
  final startAnswers = <DfuResult>[];

  /// The outcome of each APPLY, in order; when empty, the real hash check.
  final applyAnswers = <DfuResult>[];

  /// How long the sole stays in VERIFYING.
  Duration verifyTime = Duration.zero;

  /// True makes APPLY go silent: no VERIFYING, no result, ever — as if the
  /// sole's answer never made it back over the air.
  bool swallowApply = false;

  /// True loses that data packet in the air.
  bool Function(int offset)? drop;

  /// True makes that data write throw, as a full BLE buffer does.
  bool Function(int offset)? failWrite;

  /// Runs before each data write is handled — e.g. to cut the link.
  void Function(int offset)? onData;

  final controlWrites = <List<int>>[];
  final dataWrites = <List<int>>[];
  final _status = StreamController<List<int>>.broadcast();

  var _state = DfuState.idle;
  var _size = 0;
  var _sha = <int>[];
  var _committed = 0;
  var _expected = 0;
  var _lostSync = false;
  var _flash = Uint8List(0);

  /// The image as the sole stored it.
  Uint8List get received => _flash;

  int get startCount => controlWrites.where((w) => w.first == 0x01).length;

  @override
  Future<Stream<List<int>>> subscribeStatus() async => _status.stream;

  @override
  Future<void> writeControl(List<int> bytes) async {
    if (!isConnected) throw StateError('disconnected');
    controlWrites.add(List.of(bytes));
    switch (bytes.first) {
      case 0x01:
        _onStart(bytes);
      case 0x02:
        _onApply();
      case 0x03:
        _state = DfuState.idle;
        _emit(DfuResult.ok);
      case 0x04:
        _emit(DfuResult.ok);
    }
  }

  @override
  Future<void> writeData(List<int> bytes) async {
    final offset = ByteData.sublistView(
      Uint8List.fromList(bytes),
    ).getUint32(0, Endian.little);
    onData?.call(offset);
    if (!isConnected) throw StateError('disconnected');
    if (failWrite?.call(offset) ?? false) {
      throw StateError('ERROR_GATT_WRITE_REQUEST_BUSY');
    }
    dataWrites.add(List.of(bytes));
    if (drop?.call(offset) ?? false) return;
    _onData(offset, bytes.sublist(4));
  }

  void _onStart(List<int> bytes) {
    if (startAnswers.isNotEmpty) {
      _emit(startAnswers.removeAt(0));
      return;
    }
    _size = ByteData.sublistView(
      Uint8List.fromList(bytes),
    ).getUint32(2, Endian.little);
    _sha = bytes.sublist(6, 38);
    _flash = Uint8List(_size);
    _committed = 0;
    _expected = 0;
    _lostSync = false;
    _state = DfuState.receiving;
    _emit(DfuResult.ok);
  }

  void _onData(int offset, List<int> payload) {
    if (_state != DfuState.receiving) return;
    if (_lostSync) {
      // After BAD_OFFSET the sole takes nothing until `committed` again.
      if (offset != _committed) return;
      _lostSync = false;
    } else if (offset != _expected) {
      _expected = _committed;
      _lostSync = true;
      _emit(DfuResult.badOffset);
      return;
    }
    _flash.setRange(offset, offset + payload.length, payload);
    _expected = offset + payload.length;
    if (_expected - _committed == dfuPageSize || _expected == _size) {
      _committed = _expected;
      _emit(DfuResult.ok);
    }
  }

  void _onApply() {
    if (_state != DfuState.receiving || _committed != _size) {
      _emit(DfuResult.badState);
      return;
    }
    if (swallowApply) {
      // The sole may still install the image — only its answer is lost.
      _state = DfuState.verifying;
      return;
    }
    _state = DfuState.verifying;
    _emit(DfuResult.ok);
    final scripted = applyAnswers.isEmpty ? null : applyAnswers.removeAt(0);
    Timer(verifyTime, () {
      final hashOk = const ListEquality<int>().equals(
        sha256.convert(_flash).bytes,
        _sha,
      );
      final result =
          scripted ?? (hashOk ? DfuResult.ok : DfuResult.hashMismatch);
      _state = result == DfuResult.ok ? DfuState.applied : DfuState.idle;
      _emit(result);
    });
  }

  void _emit(DfuResult result) {
    final out = Uint8List(7);
    out[0] = 0xA0;
    out[1] = _state.index;
    out[2] = result.index;
    ByteData.sublistView(out).setUint32(3, _committed, Endian.little);
    // A notification lands after the write that caused it.
    scheduleMicrotask(() => _status.add(out));
  }
}
