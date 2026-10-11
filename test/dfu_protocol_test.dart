import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

void main() {
  // The example manifest's digest in the firmware handoff, §2.2.
  const sha =
      '03828d993ac25c06342183424f8c58c8819c75d9fefef7fd79a93f7806d46138';

  test('START is opcode, protocol v2, size u32 LE, then the SHA-256', () {
    final cmd = dfuStartCommand(69236, _hex(sha));
    expect(cmd, hasLength(38));
    expect(cmd.sublist(0, 6), [0x01, 0x02, 0x74, 0x0E, 0x01, 0x00]);
    expect(cmd.sublist(6), _hex(sha));
  });

  test('START rejects a digest that is not 32 bytes', () {
    expect(() => dfuStartCommand(1, [1, 2, 3]), throwsArgumentError);
  });

  test('APPLY is the opcode then the 64-byte signature', () {
    final sig = List<int>.generate(64, (i) => i);
    final cmd = dfuApplyCommand(sig);
    expect(cmd, hasLength(65));
    expect(cmd.first, 0x02);
    expect(cmd.sublist(1), sig);
    expect(() => dfuApplyCommand([1, 2]), throwsArgumentError);
  });

  test('ABORT and GET_STATUS are a single opcode byte', () {
    expect(dfuAbortCommand, [0x03]);
    expect(dfuGetStatusCommand, [0x04]);
  });

  test('a data packet is the offset u32 LE then the payload', () {
    expect(dfuDataPacket(0x00012345, [0xAA, 0xBB]), [
      0x45,
      0x23,
      0x01,
      0x00,
      0xAA,
      0xBB,
    ]);
  });

  test('the payload is min(MTU - 3, 244) - 4', () {
    expect(dfuPayloadSize(247), 240);
    expect(dfuPayloadSize(512), 240);
    expect(dfuPayloadSize(68), 61);
  });

  group('DfuStatus.parse', () {
    test('reads state, result and committed u32 LE', () {
      expect(
        DfuStatus.parse([0xA0, 1, 7, 0x00, 0x10, 0x00, 0x00]),
        const DfuStatus(DfuState.receiving, DfuResult.badOffset, 4096),
      );
    });

    test('rejects anything but a known 7-byte 0xA0 packet', () {
      expect(DfuStatus.parse([0xA0, 1, 0, 0, 0, 0]), isNull);
      expect(DfuStatus.parse([0xA1, 1, 0, 0, 0, 0, 0]), isNull);
      expect(DfuStatus.parse([0xA0, 9, 0, 0, 0, 0, 0]), isNull);
      expect(DfuStatus.parse([0xA0, 1, 11, 0, 0, 0, 0]), isNull);
    });
  });

  test('only the failures the handoff says to stop on are final', () {
    for (final f in [
      DfuFailure.badSignature,
      DfuFailure.tooLarge,
      DfuFailure.badCommand,
      DfuFailure.unsupportedVersion,
      DfuFailure.dfuUnsupported,
      DfuFailure.imageInvalid,
    ]) {
      expect(f.retryable, isFalse, reason: f.name);
    }
    expect(DfuFailure.disconnected.retryable, isTrue);
    expect(DfuFailure.hashMismatch.retryable, isTrue);
  });

  test('every failure has a snake_case message key', () {
    expect(DfuFailure.tooManyRetries.messageKey, 'ota_fail_too_many_retries');
    expect(DfuFailure.badSignature.messageKey, 'ota_fail_bad_signature');
  });
}
