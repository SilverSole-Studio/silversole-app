import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/ble/ota/dfu_transfer.dart';
import 'package:silversole/core/error/result.dart';

import 'helpers/fake_dfu_sole.dart';

/// Two full pages and a short third: covers the short last page.
final _image = List<int>.generate(10000, (i) => (i * 31 + 7) & 0xFF);
final _sha = sha256.convert(_image).bytes;
final _sig = List<int>.filled(64, 0x5A);

/// Runs a transfer against [sole] in fake time.
(Result<void>, DfuTransfer) _run(
  FakeDfuSole sole, {
  void Function(DfuTransfer transfer, FakeAsync async)? during,
  List<(int, int)>? progress,
}) {
  Result<void>? result;
  late DfuTransfer transfer;
  fakeAsync((async) {
    transfer = DfuTransfer(sole);
    transfer
        .run(
          image: _image,
          sha256: _sha,
          signature: _sig,
          onProgress: progress == null ? null : (c, s) => progress.add((c, s)),
        )
        .then((r) => result = r);
    during?.call(transfer, async);
    async.elapse(const Duration(minutes: 10));
  });
  expect(result, isNotNull, reason: 'the transfer never finished');
  return (result!, transfer);
}

DfuFailure? _failure(Result<void> r) => switch (r) {
  Ok() => null,
  Error(:final error) => (error as DfuException).failure,
};

void main() {
  test('sends the image page by page, then applies it', () {
    final sole = FakeDfuSole();
    final progress = <(int, int)>[];
    final (result, transfer) = _run(sole, progress: progress);
    expect(_failure(result), isNull);
    expect(sole.received, _image);
    expect(progress.first, (0, 10000));
    expect(progress.last, (10000, 10000));
    expect(sole.controlWrites.last, [0x02, ..._sig]);
    expect(transfer.applySent, isTrue);
  });

  test('every data packet fills one ATT packet and never more', () {
    final sole = FakeDfuSole();
    _run(sole);
    expect(sole.dataWrites.first, hasLength(244));
    expect(sole.dataWrites.every((w) => w.length <= 244), isTrue);

    final small = FakeDfuSole(mtu: 68);
    final (result, _) = _run(small);
    expect(_failure(result), isNull);
    expect(small.dataWrites.first, hasLength(65));
    expect(small.dataWrites.every((w) => w.length <= 65), isTrue);
  });

  test('refuses to start below MTU 68', () {
    final sole = FakeDfuSole(mtu: 60);
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.mtuTooSmall);
    expect(sole.controlWrites, isEmpty);
  });

  test("a page's lost last packet is recovered by the 2 s timeout", () {
    var dropped = false;
    final sole = FakeDfuSole()
      ..drop = (offset) {
        if (offset != 4080 || dropped) return false;
        return dropped = true;
      };
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
    expect(sole.received, _image);
  });

  test('BAD_OFFSET mid-page is recovered by resending from committed', () {
    var dropped = false;
    final sole = FakeDfuSole()
      ..drop = (offset) {
        if (offset != 480 || dropped) return false;
        return dropped = true;
      };
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
    expect(sole.received, _image);
  });

  test('gives up after more than 10 resends of one page', () {
    final sole = FakeDfuSole()..drop = (offset) => offset == 4080;
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.tooManyRetries);
  });

  test('a failed data write counts as a lost packet', () {
    var failed = false;
    final sole = FakeDfuSole()
      ..failWrite = (offset) {
        if (offset != 240 || failed) return false;
        return failed = true;
      };
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
    expect(sole.received, _image);
  });

  test('BAD_STATE at START stops before any data', () {
    final sole = FakeDfuSole()..startAnswers.add(DfuResult.badState);
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.badState);
    expect(sole.dataWrites, isEmpty);
  });

  test('BATTERY_UNKNOWN waits and sends START again', () {
    final sole = FakeDfuSole()
      ..startAnswers.addAll([
        DfuResult.batteryUnknown,
        DfuResult.batteryUnknown,
      ]);
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
    expect(sole.startCount, 3);
  });

  test('BATTERY_UNKNOWN past 3 retries is a failure', () {
    final sole = FakeDfuSole()
      ..startAnswers.addAll(List.filled(4, DfuResult.batteryUnknown));
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.batteryUnknown);
    expect(sole.startCount, 4);
  });

  test('BAD_SIGNATURE stops at once, without a second try', () {
    final sole = FakeDfuSole()..applyAnswers.add(DfuResult.badSignature);
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.badSignature);
    expect(sole.startCount, 1);
  });

  test('one HASH_MISMATCH sends the whole image again', () {
    final sole = FakeDfuSole()..applyAnswers.add(DfuResult.hashMismatch);
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
    expect(sole.startCount, 2);
  });

  test('a second HASH_MISMATCH in a row is a failure', () {
    final sole = FakeDfuSole()
      ..applyAnswers.addAll([DfuResult.hashMismatch, DfuResult.hashMismatch]);
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.hashMismatch);
    expect(sole.startCount, 2);
  });

  test('waits through a slow VERIFYING', () {
    final sole = FakeDfuSole()..verifyTime = const Duration(seconds: 20);
    final (result, _) = _run(sole);
    expect(_failure(result), isNull);
  });

  test('a link lost mid-transfer is reported as disconnected', () {
    late FakeDfuSole sole;
    sole = FakeDfuSole()
      ..onData = (offset) {
        if (offset == dfuPageSize) sole.isConnected = false;
      };
    final (result, _) = _run(sole);
    expect(_failure(result), DfuFailure.disconnected);
  });

  test('APPLY sent then silence is a timeout, with applySent true', () {
    final sole = FakeDfuSole()..swallowApply = true;
    final (result, transfer) = _run(sole);
    expect(_failure(result), DfuFailure.timeout);
    expect(transfer.applySent, isTrue);
  });

  test('cancel sends ABORT and ends as cancelled', () {
    final sole = FakeDfuSole();
    final (result, _) = _run(
      sole,
      during: (transfer, async) {
        async.elapse(const Duration(milliseconds: 50));
        transfer.cancel();
      },
    );
    expect(_failure(result), DfuFailure.cancelled);
    expect(sole.controlWrites, contains(equals([0x03])));
  });
}
