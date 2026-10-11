# 鞋墊韌體 OTA（App 端）實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 App 透過 BLE 把伺服器上（或 debug 版的本機檔案）已簽章的韌體更新進已連線的鞋墊，並在鞋墊重開機後用 device ID 找回同一隻、確認版本。

**Architecture:** 純邏輯放在 `lib/core/`：DFU 協定編解碼、傳送演算法（只依賴抽象的 `DfuLink`）、semver、manifest 驗證、重連目標比對，全部可以單元測試。BLE 整合沿用唯一那條連線：`BleConnectionService` 提供 `DfuLink`，foreground controller 對外提供 `SoleConnectionController`（hold / release / reacquire）。狀態與畫面放在 `lib/shared/`：`firmwareCheckProvider` 判斷有沒有新版，`firmwareUpdateProvider` 是 OTA 狀態機，另外有兩個主題的韌體卡片和共用的 `/firmware-update` 頁面。

**Tech Stack:** Flutter、Riverpod 3、flutter_blue_plus 2.1.1、freezed + json_serializable、dio、supabase_flutter（只用 `getPublicUrl`）、crypto、pub_semver、wakelock_plus、file_picker 10.3.8、fake_async。

**Spec:** `docs/superpowers/specs/2026-10-11-firmware-ota-design.md`（以及它依據的韌體 repo `docs/ota-app-handoff.md`）

## Global Constraints

- 韌體 repo（`../silversole_firmware_embassy_lab`）**只能讀，不能改**。
- BLE 位元組格式必須和交接文件 §3 完全一致；所有多 byte 整數都是 little-endian。
- **禁止 long write**：每一次 write ≤ `MTU − 3`，`allowLongWrite` 永遠是 false。
- 只支援 Android（BLE 流程在非 Android 平台會直接返回）。
- 使用者看得到的文字一律放在 `assets/translations/strings.csv`（欄位 `key,en,zh_TW`），en 和 zh_TW 兩欄都要填。**值裡面不能有 ASCII 逗號**（CSV），中文請用全形「，」。
- 主題色和字型一律透過 `context.colorScheme` / `context.textTheme` / `context.tokens` 取得，**不要用 `Theme.of(context)`**；優先使用原生 Material 元件。
- service 方法回傳 `Result<T>`（`lib/core/error/result.dart`），不用 try/catch 往外丟例外。
- 修改任何 freezed / json_serializable 模型後都要執行 `dart run build_runner build --delete-conflicting-outputs`，生成檔要一起 commit。
- 「從本機檔案更新」只能在 `kDebugMode` 之下出現。
- 程式碼註解用英文，密度比照周圍程式碼。
- 每個 shell 指令前面都要先執行 `export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"`（Flutter 不在非互動 shell 的 PATH 上）。
- **Commit 範圍**：只 `git add` 這個任務提到的檔案，不要用 `-A` / `.`。共用檔（`CLAUDE.md`、`strings.csv`、`pubspec.yaml`）常有別的 session 還沒 commit 的修改，commit 前先看 `git diff <檔案>`；如果有不是你的 hunk，只 commit 自己的部分。
- `dev_previews/` 是 gitignore 掉的本機草稿。`flutter analyze` 在那裡報的錯與本計畫無關，所以一律跑 `flutter analyze lib test`。

## 檔案結構

**新增**

| 檔案 | 職責 |
|---|---|
| `lib/core/ble/ota/dfu_protocol.dart` | 協定常數、指令與 data 封包編碼、STATUS 解析 |
| `lib/core/ble/ota/dfu_failure.dart` | `DfuFailure`（能不能重試、對應的訊息 key）、`DfuException` |
| `lib/core/ble/ota/dfu_link.dart` | `DfuLink` 抽象介面 |
| `lib/core/ble/ota/dfu_transfer.dart` | 傳送演算法（交接文件 §4） |
| `lib/core/ble/ota/reacquire_match.dart` | 重開機後找回目標鞋墊的判斷 |
| `lib/core/utils/firmware_version.dart` | semver 解析與比較 |
| `lib/core/data/firmware_release_service.dart` | 伺服器合約、`FirmwareImage`、`validateImage`、下載 |
| `lib/shared/models/firmware_manifest.dart` | manifest 模型（freezed + json） |
| `lib/shared/models/connected_sole.dart` | 目前連著的鞋墊與它的韌體版本（freezed） |
| `lib/shared/models/ota_state.dart` | OTA 階段與狀態（freezed） |
| `lib/shared/providers/connected_sole_provider.dart` | `connectedSoleProvider` |
| `lib/shared/providers/sole_connection_controller.dart` | `SoleConnectionController` 介面、`ReacquiredSole`、`NoSoleConnection` |
| `lib/shared/providers/firmware_check_provider.dart` | `FirmwareCheck`、判斷函式、`firmwareCheckProvider`、`firmwareReleaseServiceProvider` |
| `lib/shared/providers/firmware_update_provider.dart` | `FirmwareUpdateNotifier`（OTA 狀態機） |
| `lib/shared/widgets/firmware_card_parts.dart` | 兩個主題共用的韌體卡片邏輯：連點 7 次、文字、動作、本機選檔 |
| `lib/shared/pages/firmware_update_page.dart` | `/firmware-update` 頁面 |
| `test/helpers/fake_dfu_sole.dart` | 照韌體規則模擬的鞋墊 DFU 服務 |

**修改**：`pubspec.yaml`、`lib/core/ble/ble_uuids.dart`、`lib/core/ble/ble_connection_service.dart`、`lib/core/ble/sole_scanner.dart`、`lib/shared/providers/ble_foreground_controller.dart`、`lib/shared/models/app_settings.dart`、`lib/core/data/save_service.dart`、`lib/shared/providers/settings_provider.dart`、`lib/shared/providers/telemetry_process_providers/device_online_provider.dart`、`lib/shared/models/device_view_data.dart`、`lib/shared/pages/devices_page.dart`、`lib/shared/pages/theme_two/devices_page_t2.dart`、`lib/core/routing/router.dart`、`assets/translations/strings.csv`、`CLAUDE.md`。

---

### Task 1：套件依賴、DFU 協定編解碼與失敗類型

**Files:**
- Modify: `pubspec.yaml`、`pubspec.lock`（透過 `flutter pub add`）
- Create: `lib/core/ble/ota/dfu_protocol.dart`
- Create: `lib/core/ble/ota/dfu_failure.dart`
- Test: `test/dfu_protocol_test.dart`

**Interfaces:**
- Produces:
  - 常數：`dfuProtocolVersion`（0x02）、`dfuPageSize`（4096）、`dfuMaxImageSize`（425984）、`dfuSignatureLength`（64）、`dfuMinMtu`（68）
  - `enum DfuState { idle, receiving, verifying, applied }`
  - `enum DfuResult { ok, badCommand, badState, unsupportedVersion, tooLarge, lowBattery, batteryUnknown, badOffset, hashMismatch, flashError, badSignature }`
  - `class DfuStatus(DfuState state, DfuResult result, int committed)`，以及 `static DfuStatus? parse(List<int>)`
  - `Uint8List dfuStartCommand(int size, List<int> sha256)`、`Uint8List dfuApplyCommand(List<int> signature)`、`const List<int> dfuAbortCommand`、`const List<int> dfuGetStatusCommand`
  - `Uint8List dfuDataPacket(int offset, List<int> chunk)`、`int dfuPayloadSize(int mtu)`
  - `enum DfuFailure`（成員列在下方程式碼），有 `bool get retryable`、`String get messageKey`
  - `class DfuException(DfuFailure failure, [String? detail]) implements Exception`

- [ ] **Step 1：加入套件**

```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter pub add crypto:^3.0.7 pub_semver:^2.2.0 wakelock_plus
```

預期：`pubspec.yaml` 的 dependencies 多了這三個套件，`pub get` 成功。
- `crypto` 和 `pub_semver` 原本就是間接依賴，指定的版本要跟 lock 裡的一樣。
- 如果 `wakelock_plus` 跟 `package_info_plus: ^9.0.0` 衝突導致解析失敗，執行 `flutter pub add 'wakelock_plus:any'` 讓 pub 自己挑一個相容的版本，並把最後選到的版本記錄在 commit 訊息裡。

- [ ] **Step 2：寫會失敗的測試** `test/dfu_protocol_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
];

void main() {
  // The example manifest's digest in the firmware handoff, §2.2.
  const sha = '03828d993ac25c06342183424f8c58c8819c75d9fefef7fd79a93f7806d46138';

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
    expect(
      dfuDataPacket(0x00012345, [0xAA, 0xBB]),
      [0x45, 0x23, 0x01, 0x00, 0xAA, 0xBB],
    );
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
```

- [ ] **Step 3：執行，確認失敗**

執行：`flutter test test/dfu_protocol_test.dart`
預期：編譯失敗，訊息是 `Error: ... 'dfu_protocol.dart' ... not found` 或 `Method not found: 'dfuStartCommand'`。

- [ ] **Step 4：實作** `lib/core/ble/ota/dfu_protocol.dart`

```dart
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
    throw ArgumentError.value(signature.length, 'signature', 'must be 64 bytes');
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
```

- [ ] **Step 5：實作** `lib/core/ble/ota/dfu_failure.dart`

```dart
/// Why a firmware update stopped. Every one of them leaves the sole on its
/// old firmware, still working — the firmware guarantees that.
enum DfuFailure {
  notConnected,
  disconnected,
  timeout,
  tooManyRetries,
  cancelled,
  dfuUnsupported,
  unsupportedVersion,
  mtuTooSmall,
  lowBattery,
  batteryUnknown,
  badState,
  hashMismatch,
  flashError,
  badSignature,
  tooLarge,
  badCommand,
  manifestUnavailable,
  downloadFailed,
  imageInvalid;

  /// False where trying again cannot help: the image, its signature or the
  /// sole's firmware itself is the problem (the handoff's §3.5).
  bool get retryable => switch (this) {
    badSignature ||
    tooLarge ||
    badCommand ||
    unsupportedVersion ||
    dfuUnsupported ||
    imageInvalid => false,
    _ => true,
  };

  /// The strings.csv key of its message, e.g. `ota_fail_too_many_retries`.
  String get messageKey =>
      'ota_fail_${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}';
}

class DfuException implements Exception {
  const DfuException(this.failure, [this.detail]);

  final DfuFailure failure;

  /// What happened, for the log — never shown to the user.
  final String? detail;

  @override
  String toString() => detail == null
      ? 'DfuException(${failure.name})'
      : 'DfuException(${failure.name}: $detail)';
}
```

- [ ] **Step 6：執行，確認通過**

執行：`flutter test test/dfu_protocol_test.dart`
預期：全部 PASS。

- [ ] **Step 7：Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/ble/ota/dfu_protocol.dart lib/core/ble/ota/dfu_failure.dart test/dfu_protocol_test.dart
git commit -m "feat(ota): add the DFU protocol codec and failure kinds"
```

---

### Task 2：版本比較、manifest 模型、映像驗證與下載服務

**Files:**
- Create: `lib/core/utils/firmware_version.dart`
- Create: `lib/shared/models/firmware_manifest.dart`（另外由 build_runner 產生 `.freezed.dart` 和 `.g.dart`）
- Create: `lib/core/data/firmware_release_service.dart`
- Test: `test/firmware_version_test.dart`、`test/firmware_release_test.dart`

**Interfaces:**
- Consumes：Task 1 的 `DfuFailure`、`DfuException`、`dfuMaxImageSize`、`dfuSignatureLength`
- Produces:
  - `Version? parseFirmwareVersion(String?)`、`enum FirmwareComparison { upgrade, downgrade, same }`、`FirmwareComparison? compareFirmware(String? device, String? server)`
  - `FirmwareManifest({required int schema, required String channel, required String version, required int size, required String sha256, required String binPath, required String sigPath, String notes = '', DateTime? publishedAt})`，以及 `.fromJson`
  - 常數 `firmwareBucket = 'firmware'`、`firmwareManifestSchema = 1`
  - `enum FirmwareChannel { stable, beta }`、`String firmwareManifestPath(FirmwareChannel)`
  - `class FirmwareImage({required Uint8List bin, required Uint8List signature, required Uint8List sha256, String? version, String notes = ''})`
  - `String? validateImage({FirmwareManifest? manifest, required List<int> bin, required List<int> signature})`
  - `class FirmwareReleaseService({Dio? dio, String Function(String path)? publicUrl})`，方法有 `Future<Result<FirmwareManifest>> fetchManifest(FirmwareChannel)`、`Future<Result<FirmwareImage>> download(FirmwareManifest)`、`Result<FirmwareImage> localImage(Uint8List bin, Uint8List signature)`

- [ ] **Step 1：寫會失敗的測試** `test/firmware_version_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/firmware_version.dart';

void main() {
  test('a release candidate is older than its release', () {
    expect(compareFirmware('0.4.0-rc.1', '0.4.0'), FirmwareComparison.upgrade);
    expect(compareFirmware('0.4.0', '0.4.0-rc.1'), FirmwareComparison.downgrade);
  });

  test('versions compare numerically, not as text', () {
    expect(compareFirmware('0.9.0', '0.10.0'), FirmwareComparison.upgrade);
    expect(compareFirmware('0.4.0-rc.9', '0.4.0-rc.10'), FirmwareComparison.upgrade);
  });

  test('equal versions are the same', () {
    expect(compareFirmware('0.4.0', '0.4.0'), FirmwareComparison.same);
  });

  test('anything that is not semver compares as unknown', () {
    expect(compareFirmware('v0.4.0', '0.4.0'), isNull);
    expect(compareFirmware('0.4.0', 'latest'), isNull);
    expect(compareFirmware(null, '0.4.0'), isNull);
  });

  test('surrounding whitespace is tolerated', () {
    expect(parseFirmwareVersion(' 0.4.0 '), isNotNull);
  });
}
```

- [ ] **Step 2：寫會失敗的測試** `test/firmware_release_test.dart`

```dart
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';

final _bin = List<int>.generate(1000, (i) => i & 0xFF);
final _sig = List<int>.filled(64, 7);

FirmwareManifest _manifest({int? size, String? sha}) => FirmwareManifest(
  schema: 1,
  channel: 'stable',
  version: '0.4.0',
  size: size ?? _bin.length,
  sha256: sha ?? sha256.convert(_bin).toString(),
  binPath: 'releases/0.4.0/fw.bin',
  sigPath: 'releases/0.4.0/fw.bin.sig',
);

void main() {
  test('parses the manifest the handoff specifies', () {
    final m = FirmwareManifest.fromJson({
      'schema': 1,
      'channel': 'stable',
      'version': '0.4.0',
      'size': 69236,
      'sha256': '03828d993ac25c06342183424f8c58c8819c75d9fefef7fd79a93f7806d46138',
      'bin_path': 'releases/0.4.0/fw.bin',
      'sig_path': 'releases/0.4.0/fw.bin.sig',
      'notes': '修正 xxx',
      'published_at': '2026-10-10T12:00:00Z',
    });
    expect(m.binPath, 'releases/0.4.0/fw.bin');
    expect(m.sigPath, 'releases/0.4.0/fw.bin.sig');
    expect(m.size, 69236);
    expect(m.publishedAt, DateTime.utc(2026, 10, 10, 12));
  });

  test('notes may be missing or null', () {
    final m = FirmwareManifest.fromJson({
      'schema': 1,
      'channel': 'beta',
      'version': '0.4.0-rc.1',
      'size': 1,
      'sha256': '00',
      'bin_path': 'b',
      'sig_path': 's',
      'notes': null,
    });
    expect(m.notes, '');
  });

  test('each channel has its own manifest', () {
    expect(firmwareManifestPath(FirmwareChannel.stable), 'channels/stable/manifest.json');
    expect(firmwareManifestPath(FirmwareChannel.beta), 'channels/beta/manifest.json');
  });

  group('validateImage', () {
    test('a matching image passes', () {
      expect(validateImage(manifest: _manifest(), bin: _bin, signature: _sig), isNull);
    });

    test('an uppercase digest in the manifest still matches', () {
      final upper = sha256.convert(_bin).toString().toUpperCase();
      expect(
        validateImage(manifest: _manifest(sha: upper), bin: _bin, signature: _sig),
        isNull,
      );
    });

    test('rejects an empty or oversized image', () {
      expect(validateImage(manifest: _manifest(size: 0), bin: const [], signature: _sig), isNotNull);
      final huge = List<int>.filled(425985, 0);
      expect(validateImage(bin: huge, signature: _sig), isNotNull);
    });

    test('rejects a size that differs from the manifest', () {
      expect(
        validateImage(manifest: _manifest(size: 999), bin: _bin, signature: _sig),
        contains('size'),
      );
    });

    test('rejects a digest that differs from the manifest', () {
      expect(
        validateImage(manifest: _manifest(sha: 'ab' * 32), bin: _bin, signature: _sig),
        contains('sha256'),
      );
    });

    test('rejects a signature that is not 64 bytes', () {
      expect(
        validateImage(manifest: _manifest(), bin: _bin, signature: List.filled(63, 0)),
        contains('signature'),
      );
    });

    test('a local image without a manifest is checked for size and signature only', () {
      expect(validateImage(bin: _bin, signature: _sig), isNull);
      expect(validateImage(bin: _bin, signature: const [1]), isNotNull);
    });
  });
}
```

- [ ] **Step 3：執行，確認失敗**

執行：`flutter test test/firmware_version_test.dart test/firmware_release_test.dart`
預期：編譯失敗，原因是找不到 `firmware_version.dart`、`firmware_manifest.dart`、`firmware_release_service.dart`。

- [ ] **Step 4：實作** `lib/core/utils/firmware_version.dart`

```dart
import 'package:pub_semver/pub_semver.dart';

enum FirmwareComparison { upgrade, downgrade, same }

/// A firmware version as the sole reports it and the manifest writes it
/// (`0.4.0`, `0.4.0-rc.1`), or null when it is not semver.
Version? parseFirmwareVersion(String? raw) {
  if (raw == null) return null;
  try {
    return Version.parse(raw.trim());
  } on FormatException {
    return null;
  }
}

/// How [server] relates to the version on the [device], by semver rules —
/// `0.4.0-rc.1 < 0.4.0`, `0.10.0 > 0.9.0` — or null when either side is not
/// semver.
FirmwareComparison? compareFirmware(String? device, String? server) {
  final d = parseFirmwareVersion(device);
  final s = parseFirmwareVersion(server);
  if (d == null || s == null) return null;
  final c = s.compareTo(d);
  if (c > 0) return FirmwareComparison.upgrade;
  if (c < 0) return FirmwareComparison.downgrade;
  return FirmwareComparison.same;
}
```

- [ ] **Step 5：實作** `lib/shared/models/firmware_manifest.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_manifest.freezed.dart';
part 'firmware_manifest.g.dart';

/// One channel's current release (the firmware handoff's §2.2).
@freezed
abstract class FirmwareManifest with _$FirmwareManifest {
  const factory FirmwareManifest({
    /// Format version; anything but `firmwareManifestSchema` is not understood.
    required int schema,
    required String channel,
    required String version,
    required int size,

    /// SHA-256 of `fw.bin`, lowercase hex.
    required String sha256,
    @JsonKey(name: 'bin_path') required String binPath,
    @JsonKey(name: 'sig_path') required String sigPath,
    @Default('') String notes,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
  }) = _FirmwareManifest;

  factory FirmwareManifest.fromJson(Map<String, dynamic> json) =>
      _$FirmwareManifestFromJson(json);
}
```

執行：`dart run build_runner build --delete-conflicting-outputs`
預期：產生 `firmware_manifest.freezed.dart` 和 `firmware_manifest.g.dart`，`git status` 不應出現其他生成檔的變更。

- [ ] **Step 6：實作** `lib/core/data/firmware_release_service.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The public Supabase Storage bucket the firmware is published to (the
/// handoff's §2.1). It is public on purpose and must not get a SELECT policy
/// on storage.objects: the app only fetches known paths, and such a policy
/// would let anyone list the bucket.
const firmwareBucket = 'firmware';

/// The only manifest format this app understands.
const firmwareManifestSchema = 1;

enum FirmwareChannel { stable, beta }

String firmwareManifestPath(FirmwareChannel channel) =>
    'channels/${channel.name}/manifest.json';

/// An image ready to send: its bytes, its signature and their checks done.
@immutable
class FirmwareImage {
  const FirmwareImage({
    required this.bin,
    required this.signature,
    required this.sha256,
    this.version,
    this.notes = '',
  });

  final Uint8List bin;
  final Uint8List signature;

  /// SHA-256 of [bin], the 32 bytes START carries.
  final Uint8List sha256;

  /// The version it installs; null for a developer's own file, which comes
  /// without a manifest.
  final String? version;
  final String notes;
}

/// What is wrong with an image, or null when it may go to the sole (the
/// handoff's §2.3). Without a [manifest] — a developer's own file — only the
/// checks that need none are made.
String? validateImage({
  FirmwareManifest? manifest,
  required List<int> bin,
  required List<int> signature,
}) {
  if (bin.isEmpty || bin.length > dfuMaxImageSize) {
    return 'size ${bin.length} is outside 1..$dfuMaxImageSize';
  }
  if (manifest != null) {
    if (bin.length != manifest.size) {
      return 'size ${bin.length} != manifest ${manifest.size}';
    }
    final digest = sha256.convert(bin).toString();
    if (digest != manifest.sha256.toLowerCase()) {
      return 'sha256 $digest != manifest ${manifest.sha256}';
    }
  }
  if (signature.length != dfuSignatureLength) {
    return 'signature is ${signature.length} bytes, not $dfuSignatureLength';
  }
  return null;
}

/// Reads the firmware server: a channel's manifest, then the image and its
/// signature by the paths it names.
class FirmwareReleaseService {
  FirmwareReleaseService({Dio? dio, String Function(String path)? publicUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
            ),
          ),
      _publicUrl =
          publicUrl ??
          ((path) => Supabase.instance.client.storage
              .from(firmwareBucket)
              .getPublicUrl(path));

  final Dio _dio;
  final String Function(String path) _publicUrl;

  Future<Result<FirmwareManifest>> fetchManifest(FirmwareChannel channel) async {
    try {
      final res = await _dio.get<String>(
        _publicUrl(firmwareManifestPath(channel)),
        options: Options(responseType: ResponseType.plain),
      );
      final json = jsonDecode(res.data ?? '') as Map<String, dynamic>;
      return Result.ok(FirmwareManifest.fromJson(json));
    } catch (e) {
      // Network trouble, a missing manifest, or one that does not parse: in
      // every case there is nothing to offer.
      return Result.error(
        DfuException(DfuFailure.manifestUnavailable, '$e'),
      );
    }
  }

  Future<Result<FirmwareImage>> download(FirmwareManifest manifest) async {
    final Uint8List bin;
    final Uint8List signature;
    try {
      bin = await _bytes(manifest.binPath);
      signature = await _bytes(manifest.sigPath);
    } catch (e) {
      return Result.error(DfuException(DfuFailure.downloadFailed, '$e'));
    }
    final problem = validateImage(
      manifest: manifest,
      bin: bin,
      signature: signature,
    );
    if (problem != null) {
      return Result.error(DfuException(DfuFailure.imageInvalid, problem));
    }
    return Result.ok(
      FirmwareImage(
        bin: bin,
        signature: signature,
        sha256: Uint8List.fromList(sha256.convert(bin).bytes),
        version: manifest.version,
        notes: manifest.notes,
      ),
    );
  }

  /// A developer's own image (debug builds only), checked as far as possible
  /// without a manifest.
  Result<FirmwareImage> localImage(Uint8List bin, Uint8List signature) {
    final problem = validateImage(bin: bin, signature: signature);
    if (problem != null) {
      return Result.error(DfuException(DfuFailure.imageInvalid, problem));
    }
    return Result.ok(
      FirmwareImage(
        bin: bin,
        signature: signature,
        sha256: Uint8List.fromList(sha256.convert(bin).bytes),
      ),
    );
  }

  Future<Uint8List> _bytes(String path) async {
    final res = await _dio.get<List<int>>(
      _publicUrl(path),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}
```

- [ ] **Step 7：執行，確認通過**

執行：`flutter test test/firmware_version_test.dart test/firmware_release_test.dart`
預期：全部 PASS。

- [ ] **Step 8：Commit**

```bash
git add lib/core/utils/firmware_version.dart lib/shared/models/firmware_manifest.dart lib/shared/models/firmware_manifest.freezed.dart lib/shared/models/firmware_manifest.g.dart lib/core/data/firmware_release_service.dart test/firmware_version_test.dart test/firmware_release_test.dart
git commit -m "feat(ota): read and check firmware releases from Supabase Storage"
```

---

### Task 3：`DfuLink` 介面與傳送演算法

**Files:**
- Create: `lib/core/ble/ota/dfu_link.dart`
- Create: `lib/core/ble/ota/dfu_transfer.dart`
- Create: `test/helpers/fake_dfu_sole.dart`
- Test: `test/dfu_transfer_test.dart`

**Interfaces:**
- Consumes：Task 1 的全部 API
- Produces:
  - `abstract interface class DfuLink`：`int get mtu`、`bool get isConnected`、`Future<Stream<List<int>>> subscribeStatus()`、`Future<void> writeControl(List<int>)`、`Future<void> writeData(List<int>)`
  - `class DfuTransfer(DfuLink link, {Duration statusTimeout = 2s, Duration applyTimeout = 30s, Duration resendDelay = 100ms, Duration batteryRetryDelay = 10s, int batteryRetries = 3, int maxResends = 10, Duration packetGap = 10ms})`
    - `Future<Result<void>> run({required List<int> image, required List<int> sha256, required List<int> signature, void Function(int committed, int size)? onProgress})`
    - `Future<void> cancel()`
    - `bool get applySent`
  - 測試輔助 `FakeDfuSole implements DfuLink`（Task 8 也會用到），可以設定的欄位包括 `startAnswers`、`applyAnswers`、`verifyTime`、`drop`、`failWrite`、`onData`；可以觀察的欄位包括 `controlWrites`、`dataWrites`、`received`

- [ ] **Step 1：實作介面** `lib/core/ble/ota/dfu_link.dart`（測試要靠它才能編譯）

```dart
/// What [DfuTransfer] needs from a connection to the sole's DFU service.
///
/// `BleConnectionService.dfuLink()` provides it over BLE; tests use a fake
/// sole.
abstract interface class DfuLink {
  /// The negotiated ATT MTU. One write carries at most `mtu − 3` bytes.
  int get mtu;

  bool get isConnected;

  /// Enables `control` notifications and returns them as raw packets.
  Future<Stream<List<int>>> subscribeStatus();

  /// Writes a command to `control`, with response.
  Future<void> writeControl(List<int> bytes);

  /// Writes a data packet to `data`, without response.
  Future<void> writeData(List<int> bytes);
}
```

- [ ] **Step 2：寫測試輔助** `test/helpers/fake_dfu_sole.dart`

```dart
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
```

- [ ] **Step 3：寫會失敗的測試** `test/dfu_transfer_test.dart`

```dart
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
      ..startAnswers.addAll([DfuResult.batteryUnknown, DfuResult.batteryUnknown]);
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
    expect(sole.controlWrites, contains([0x03]));
  });
}
```

- [ ] **Step 4：執行，確認失敗**

執行：`flutter test test/dfu_transfer_test.dart`
預期：編譯失敗，訊息是 `Error: ... 'dfu_transfer.dart' ... not found`。

- [ ] **Step 5：實作** `lib/core/ble/ota/dfu_transfer.dart`

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/error/result.dart';

/// Sends one firmware image into the sole (the firmware handoff's §4).
///
/// Flow control is one flash page at a time: send `[committed, committed +
/// 4096)`, then wait for the sole to report `committed` moving on. A packet
/// lost in the air shows up as BAD_OFFSET — or, when it was the last of its
/// page, as nothing at all, which is why every page wait has a timeout. Either
/// way the page is sent again from `committed`.
class DfuTransfer {
  DfuTransfer(
    this._link, {
    this.statusTimeout = const Duration(seconds: 2),
    this.applyTimeout = const Duration(seconds: 30),
    this.resendDelay = const Duration(milliseconds: 100),
    this.batteryRetryDelay = const Duration(seconds: 10),
    this.batteryRetries = 3,
    this.maxResends = 10,
    this.packetGap = const Duration(milliseconds: 10),
  });

  final DfuLink _link;
  final Duration statusTimeout;

  /// Checking a 416 KiB image takes the sole several seconds.
  final Duration applyTimeout;

  /// Lets packets already on their way drain before a page is resent.
  final Duration resendDelay;
  final Duration batteryRetryDelay;
  final int batteryRetries;
  final int maxResends;

  /// Pause between data packets, so the phone's BLE buffer does not overflow
  /// and drop them. Tune on hardware.
  final Duration packetGap;

  _StatusQueue? _queue;
  Completer<void>? _sleeper;
  var _cancelled = false;
  var _applySent = false;

  /// Whether APPLY went out. From then on the sole may install the image even
  /// if its answer is lost, and only the version it boots with can tell.
  bool get applySent => _applySent;

  Future<Result<void>> run({
    required List<int> image,
    required List<int> sha256,
    required List<int> signature,
    void Function(int committed, int size)? onProgress,
  }) async {
    if (!_link.isConnected) {
      return const Result.error(DfuException(DfuFailure.notConnected));
    }
    if (_link.mtu < dfuMinMtu) {
      return Result.error(
        DfuException(DfuFailure.mtuTooSmall, 'mtu ${_link.mtu}'),
      );
    }
    final queue = _StatusQueue(await _link.subscribeStatus());
    _queue = queue;
    try {
      var restarted = false;
      while (true) {
        try {
          await _start(queue, image.length, sha256);
          await _sendImage(queue, image, dfuPayloadSize(_link.mtu), onProgress);
          await _apply(queue, signature);
          return const Result.ok(null);
        } on DfuException catch (e) {
          // The image went bad on the way or in flash: worth one clean resend
          // from START (the handoff's §3.5), not more.
          final resend =
              e.failure == DfuFailure.hashMismatch ||
              e.failure == DfuFailure.flashError;
          if (!resend || restarted || _cancelled) return Result.error(e);
          debugPrint('dfu: ${e.failure.name}, sending the image again');
          restarted = true;
          _applySent = false;
        }
      }
    } finally {
      _queue = null;
      await queue.close();
    }
  }

  /// Stops the transfer: the sole is told to ABORT, and [run] ends with
  /// [DfuFailure.cancelled]. Safe at any point — the sole keeps its firmware.
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _queue?.interrupt();
    final sleeper = _sleeper;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
    try {
      await _link.writeControl(dfuAbortCommand);
    } catch (e) {
      debugPrint('dfu: ABORT failed: $e');
    }
  }

  Future<void> _start(_StatusQueue queue, int size, List<int> sha256) async {
    for (var attempt = 0; ; attempt++) {
      final status = await _command(
        queue,
        dfuStartCommand(size, sha256),
        statusTimeout,
      );
      if (status.result == DfuResult.batteryUnknown &&
          attempt < batteryRetries) {
        // Just booted (e.g. right after an update): its first battery reading
        // takes about 10 s.
        await _sleep(batteryRetryDelay);
        continue;
      }
      if (status.state == DfuState.receiving &&
          status.result == DfuResult.ok) {
        return;
      }
      throw _failureOf(status);
    }
  }

  Future<void> _sendImage(
    _StatusQueue queue,
    List<int> image,
    int payload,
    void Function(int committed, int size)? onProgress,
  ) async {
    final size = image.length;
    var committed = 0;
    var resends = 0;
    onProgress?.call(0, size);
    while (committed < size) {
      _check();
      final pageEnd = math.min(committed + dfuPageSize, size);
      var lost = false;
      for (var offset = committed; offset < pageEnd; offset += payload) {
        final end = math.min(offset + payload, pageEnd);
        try {
          await _link.writeData(dfuDataPacket(offset, image.sublist(offset, end)));
        } catch (e) {
          if (!_link.isConnected) {
            throw const DfuException(DfuFailure.disconnected);
          }
          // A full BLE buffer (Android 13+ reports
          // ERROR_GATT_WRITE_REQUEST_BUSY): the packet never left, so the page
          // is resent like any other loss.
          debugPrint('dfu: data write at $offset failed: $e');
          lost = true;
          break;
        }
        if (packetGap > Duration.zero) await _sleep(packetGap);
        _check();
      }

      final status = lost ? null : await queue.next(statusTimeout);
      _check();
      if (status != null &&
          status.result == DfuResult.ok &&
          status.committed > committed) {
        committed = status.committed;
        resends = 0;
        onProgress?.call(committed, size);
        continue;
      }
      if (status != null &&
          status.result != DfuResult.ok &&
          status.result != DfuResult.badOffset) {
        throw _failureOf(status);
      }
      if (status == null && !_link.isConnected) {
        throw const DfuException(DfuFailure.disconnected);
      }

      // A lost packet: BAD_OFFSET, silence (the page's last packet went
      // missing) or a failed write. The sole now only takes `committed`,
      // which BAD_OFFSET carries — it may be ahead of ours when a STATUS was
      // missed.
      if (status != null && status.committed > committed) {
        committed = status.committed;
        onProgress?.call(committed, size);
      }
      resends++;
      if (resends > maxResends) {
        throw DfuException(DfuFailure.tooManyRetries, 'page at $committed');
      }
      debugPrint(
        'dfu: resending from $committed '
        '(${status?.result.name ?? 'no status'}, #$resends)',
      );
      await _sleep(resendDelay);
      _check();
      queue.clear();
    }
  }

  Future<void> _apply(_StatusQueue queue, List<int> signature) async {
    _check();
    queue.clear();
    await _writeControl(dfuApplyCommand(signature));
    _applySent = true;
    // Verifying can keep the sole from answering for seconds — even the
    // VERIFYING status may come late — so both waits are long.
    var status = await _next(queue, applyTimeout);
    if (status.state == DfuState.verifying && status.result == DfuResult.ok) {
      status = await _next(queue, applyTimeout);
    }
    if (status.state == DfuState.applied && status.result == DfuResult.ok) {
      return;
    }
    throw _failureOf(status);
  }

  Future<DfuStatus> _command(
    _StatusQueue queue,
    List<int> bytes,
    Duration timeout,
  ) async {
    _check();
    queue.clear();
    await _writeControl(bytes);
    return _next(queue, timeout);
  }

  Future<void> _writeControl(List<int> bytes) async {
    try {
      await _link.writeControl(bytes);
    } catch (e) {
      throw _linkFailure(e);
    }
  }

  Future<DfuStatus> _next(_StatusQueue queue, Duration timeout) async {
    final status = await queue.next(timeout);
    _check();
    if (status == null) {
      throw _linkFailure('no status within ${timeout.inSeconds} s');
    }
    return status;
  }

  DfuException _linkFailure(Object cause) => _link.isConnected
      ? DfuException(DfuFailure.timeout, '$cause')
      : const DfuException(DfuFailure.disconnected);

  void _check() {
    if (_cancelled) throw const DfuException(DfuFailure.cancelled);
  }

  /// A delay that [cancel] cuts short.
  Future<void> _sleep(Duration duration) {
    final sleeper = Completer<void>();
    _sleeper = sleeper;
    final timer = Timer(duration, () {
      if (!sleeper.isCompleted) sleeper.complete();
    });
    return sleeper.future.whenComplete(() {
      timer.cancel();
      if (identical(_sleeper, sleeper)) _sleeper = null;
    });
  }

  static DfuException _failureOf(DfuStatus status) => DfuException(
    switch (status.result) {
      DfuResult.badCommand => DfuFailure.badCommand,
      DfuResult.badState => DfuFailure.badState,
      DfuResult.unsupportedVersion => DfuFailure.unsupportedVersion,
      DfuResult.tooLarge => DfuFailure.tooLarge,
      DfuResult.lowBattery => DfuFailure.lowBattery,
      DfuResult.batteryUnknown => DfuFailure.batteryUnknown,
      DfuResult.hashMismatch => DfuFailure.hashMismatch,
      DfuResult.flashError => DfuFailure.flashError,
      DfuResult.badSignature => DfuFailure.badSignature,
      // OK in the wrong state, or BAD_OFFSET outside a page: the sole is not
      // where the protocol says it should be.
      DfuResult.ok || DfuResult.badOffset => DfuFailure.badState,
    },
    '$status',
  );
}

/// STATUS notifications in arrival order, so one that lands while a page is
/// still being sent is not lost before the transfer starts waiting for it.
class _StatusQueue {
  _StatusQueue(Stream<List<int>> raw) {
    _sub = raw.listen((bytes) {
      final status = DfuStatus.parse(bytes);
      if (status == null) return;
      final waiter = _waiter;
      if (waiter != null && !waiter.isCompleted) {
        _waiter = null;
        waiter.complete(status);
      } else {
        _buffer.add(status);
      }
    });
  }

  late final StreamSubscription<List<int>> _sub;
  final _buffer = <DfuStatus>[];
  Completer<DfuStatus?>? _waiter;

  /// The next status, or null when none arrives within [timeout].
  Future<DfuStatus?> next(Duration timeout) {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final waiter = Completer<DfuStatus?>();
    _waiter = waiter;
    final timer = Timer(timeout, () => _resolve(waiter));
    return waiter.future.whenComplete(timer.cancel);
  }

  /// Ends the current wait at once, with no status.
  void interrupt() {
    final waiter = _waiter;
    if (waiter != null) _resolve(waiter);
  }

  void _resolve(Completer<DfuStatus?> waiter) {
    if (identical(_waiter, waiter)) _waiter = null;
    if (!waiter.isCompleted) waiter.complete(null);
  }

  /// Drops statuses that arrived but are no longer the answer awaited.
  void clear() => _buffer.clear();

  Future<void> close() => _sub.cancel();
}
```

- [ ] **Step 6：執行，確認通過**

執行：`flutter test test/dfu_transfer_test.dart`
預期：16 個測試全部 PASS。如果「lost last packet」那一項失敗，先檢查 `FakeDfuSole._onData` 在 lostSync 狀態下是不是只接受 `offset == _committed` 的封包；這正是協定 §4 的規則。

- [ ] **Step 7：Commit**

```bash
git add lib/core/ble/ota/dfu_link.dart lib/core/ble/ota/dfu_transfer.dart test/helpers/fake_dfu_sole.dart test/dfu_transfer_test.dart
git commit -m "feat(ota): send firmware a page at a time and recover lost packets"
```

---

### Task 4：重開機後找回目標鞋墊（比對規則與長時間掃描）

**Files:**
- Create: `lib/core/ble/ota/reacquire_match.dart`
- Modify: `lib/core/ble/sole_scanner.dart`（新增 `SoleScanner.watch`）
- Test: `test/reacquire_match_test.dart`

**Interfaces:**
- Consumes：`SoleCandidate`（有 `remoteId`、`name`、`rssi`、`deviceId`）、`BlePairedDevice`（有 `identityKey`、`deviceId`、`remoteId`）
- Produces:
  - `enum ReacquireConfidence { certain, probable }`
  - `class ReacquireMatch(SoleCandidate candidate, ReacquireConfidence confidence)`
  - `bool isReacquireTarget(SoleCandidate candidate, BlePairedDevice target)`
  - `ReacquireMatch? matchReacquireTarget({required BlePairedDevice target, required List<SoleCandidate> seen, required List<BlePairedDevice> paired})`
  - `Future<List<SoleCandidate>> SoleScanner.watch({required Duration timeout, required bool Function(SoleCandidate) stopWhen})`

- [ ] **Step 1：寫會失敗的測試** `test/reacquire_match_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

SoleCandidate _seen(String remoteId, {String? id}) =>
    SoleCandidate(remoteId: remoteId, name: 'SilverSole', rssi: -60, deviceId: id);

BlePairedDevice _paired(String remoteId, {String? id}) =>
    BlePairedDevice(remoteId: remoteId, name: 'SilverSole', deviceId: id);

void main() {
  test('a sole that had an ID is found by that ID on any address', () {
    final m = matchReacquireTarget(
      target: _paired('OLD', id: 'A'),
      seen: [_seen('X', id: 'B'), _seen('NEW', id: 'A')],
      paired: const [],
    );
    expect(m?.candidate.remoteId, 'NEW');
    expect(m?.confidence, ReacquireConfidence.certain);
  });

  test('with an ID there is no guessing', () {
    expect(
      matchReacquireTarget(
        target: _paired('OLD', id: 'A'),
        seen: [_seen('OLD', id: 'B')],
        paired: const [],
      ),
      isNull,
    );
  });

  test('a sole that had no ID is found by its old address', () {
    final m = matchReacquireTarget(
      target: _paired('M1'),
      seen: [_seen('M9', id: 'X'), _seen('M1', id: 'NEW')],
      paired: const [],
    );
    expect(m?.candidate.remoteId, 'M1');
    expect(m?.confidence, ReacquireConfidence.certain);
  });

  test('otherwise a lone sole nobody else owns is the probable match', () {
    final target = _paired('M1');
    final m = matchReacquireTarget(
      target: target,
      seen: [_seen('M2', id: 'NEW')],
      paired: [target, _paired('M5', id: 'OTHER')],
    );
    expect(m?.candidate.remoteId, 'M2');
    expect(m?.confidence, ReacquireConfidence.probable);
  });

  test('a lone sole that is another paired one is not it', () {
    final target = _paired('M1');
    expect(
      matchReacquireTarget(
        target: target,
        seen: [_seen('M3', id: 'OTHER')],
        paired: [target, _paired('M5', id: 'OTHER')],
      ),
      isNull,
    );
  });

  test('two soles on the air are too ambiguous to guess', () {
    expect(
      matchReacquireTarget(
        target: _paired('M1'),
        seen: [_seen('M2', id: 'X'), _seen('M3', id: 'Y')],
        paired: const [],
      ),
      isNull,
    );
  });

  test('nothing seen is nothing found', () {
    expect(
      matchReacquireTarget(target: _paired('M1'), seen: const [], paired: const []),
      isNull,
    );
  });
}
```

- [ ] **Step 2：執行，確認失敗**

執行：`flutter test test/reacquire_match_test.dart`
預期：編譯失敗，訊息是 `'reacquire_match.dart' ... not found`。

- [ ] **Step 3：實作** `lib/core/ble/ota/reacquire_match.dart`

```dart
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

enum ReacquireConfidence {
  /// The same chip ID, or for a sole that had none, the same address.
  certain,

  /// The only sole on the air, and no other paired sole's ID.
  probable,
}

@immutable
class ReacquireMatch {
  const ReacquireMatch(this.candidate, this.confidence);

  final SoleCandidate candidate;
  final ReacquireConfidence confidence;
}

/// Whether [candidate] is certainly [target]: by chip ID, or by address for a
/// sole that reported no ID before its update.
bool isReacquireTarget(SoleCandidate candidate, BlePairedDevice target) {
  final id = target.deviceId;
  if (id != null) return candidate.deviceId == id;
  return candidate.remoteId == target.remoteId;
}

/// Picks the sole that was just updated out of everything a scan saw
/// (the OTA spec's §2.3). Only a sole on firmware too old to report an ID is
/// ever guessed at, and only when exactly one sole is on the air and it is
/// not another paired sole.
ReacquireMatch? matchReacquireTarget({
  required BlePairedDevice target,
  required List<SoleCandidate> seen,
  required List<BlePairedDevice> paired,
}) {
  final certain = seen.firstWhereOrNull((c) => isReacquireTarget(c, target));
  if (certain != null) {
    return ReacquireMatch(certain, ReacquireConfidence.certain);
  }
  if (target.deviceId != null || seen.length != 1) return null;
  final only = seen.single;
  final ownedElsewhere = paired.any(
    (d) =>
        d.identityKey != target.identityKey &&
        d.deviceId != null &&
        d.deviceId == only.deviceId,
  );
  return ownedElsewhere
      ? null
      : ReacquireMatch(only, ReacquireConfidence.probable);
}
```

- [ ] **Step 4：執行，確認通過**

執行：`flutter test test/reacquire_match_test.dart`
預期：全部 PASS。

- [ ] **Step 5：在 `lib/core/ble/sole_scanner.dart` 的 `SoleScanner` 類別裡、`scan()` 之後加入 `watch()`**

`watch()` 的掃描是 fbp 的 static API，沒辦法做單元測試，留到 Task 12 在實機上驗收。

```dart
  /// Scans until a sole matching [stopWhen] shows up or [timeout] passes, and
  /// returns every sole seen meanwhile.
  ///
  /// One continuous scan rather than repeated [scan] windows: Android refuses
  /// a sixth startScan within 30 s. And [FlutterBluePlus.onScanResults]
  /// rather than `scanResults`, so a sole seen before this call — one about
  /// to reboot into new firmware — is not replayed as if it were on the air
  /// now.
  Future<List<SoleCandidate>> watch({
    required Duration timeout,
    required bool Function(SoleCandidate sole) stopWhen,
  }) async {
    if (timeout <= Duration.zero) return const [];
    final found = <String, SoleCandidate>{};
    final matched = Completer<void>();
    StreamSubscription<List<ScanResult>>? sub;
    var startedHere = false;
    try {
      sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (!isSoleName(scanResultName(r))) continue;
          final sole = SoleCandidate.fromScanResult(r);
          found[sole.remoteId] = sole;
          if (stopWhen(sole) && !matched.isCompleted) matched.complete();
        }
      });
      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          androidScanMode: AndroidScanMode.lowLatency,
          timeout: timeout,
        );
        startedHere = true;
      }
      await matched.future.timeout(timeout, onTimeout: () {});
    } catch (e) {
      debugPrint('sole watch failed: $e');
    } finally {
      await sub?.cancel();
      if (startedHere && FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
    return found.values.toList();
  }
```

執行：`flutter analyze lib test`
預期：`No issues found!`

- [ ] **Step 6：Commit**

```bash
git add lib/core/ble/ota/reacquire_match.dart lib/core/ble/sole_scanner.dart test/reacquire_match_test.dart
git commit -m "feat(ota): find the updated sole again after it reboots"
```

---

### Task 5：`BleConnectionService`：MTU 247、DFU 服務、`DfuLink`、版本讀取

**Files:**
- Modify: `lib/core/ble/ble_uuids.dart`
- Modify: `lib/core/ble/ble_connection_service.dart`
- Modify: `lib/shared/providers/ble_foreground_controller.dart`（只改 `onReady` 的參數型別，讓專案能編譯）

**Interfaces:**
- Consumes：Task 3 的 `DfuLink`
- Produces:
  - 常數 `dfuServiceUuid`、`dfuControlCharUuid`、`dfuDataCharUuid`、`dfuVersionCharUuid`
  - `class SoleSessionInfo({String? deviceId, String? firmwareVersion, required bool dfuSupported})`
  - `BleSessionHandlers.onReady` 的型別改成 `void Function(SoleSessionInfo info)?`
  - `DfuLink? BleConnectionService.dfuLink()`

這個任務的程式碼都依賴 fbp 的實際 BLE 物件，沒辦法做單元測試。驗收方式是 analyze 加上完整測試都通過，實機驗證留到 Task 12。

- [ ] **Step 1：在 `lib/core/ble/ble_uuids.dart` 檔尾加上**

```dart

// SilverSole DFU service: OTA protocol v2, the firmware repo's
// docs/ota-ble-protocol.md. All four share one 128-bit base.
const dfuServiceUuid = '01E00001-71D9-44B3-840E-7F6C6478CC8C';
const dfuControlCharUuid = '01E00002-71D9-44B3-840E-7F6C6478CC8C';
const dfuDataCharUuid = '01E00003-71D9-44B3-840E-7F6C6478CC8C';
const dfuVersionCharUuid = '01E00004-71D9-44B3-840E-7F6C6478CC8C';
```

- [ ] **Step 2：在 `ble_connection_service.dart` 的 `typedef BleNotifyHandler` 之後加入 `SoleSessionInfo`，並修改 `onReady`**

在 `typedef BleNotifyHandler ...;` 那一行之後插入：

```dart

/// What one connection's handshake learned about the sole.
@immutable
class SoleSessionInfo {
  const SoleSessionInfo({
    this.deviceId,
    this.firmwareVersion,
    required this.dfuSupported,
  });

  /// The chip ID, or null on firmware from before the ID existed.
  final String? deviceId;

  /// The DFU `version` string as the sole reports it, e.g. `0.4.0-rc.1`.
  final String? firmwareVersion;

  /// False on firmware without the DFU service: it can only be updated by
  /// wire.
  final bool dfuSupported;
}
```

把 `BleSessionHandlers` 裡的

```dart
  /// [deviceId] is the sole's chip ID, or null when it reported none (firmware
  /// from before the ID existed, or a failed read).
  final void Function(String? deviceId)? onReady;
```

改成：

```dart
  /// [SoleSessionInfo.deviceId] is null when the sole reported no chip ID
  /// (firmware from before the ID existed, or a failed read).
  final void Function(SoleSessionInfo info)? onReady;
```

- [ ] **Step 3：MTU 改成 247，並加上 `_dfuService` 欄位**

把

```dart
  /// Matches the firmware's `conn_gatt.att_mtu`; the negotiated value is
  /// `min(request, firmware)` anyway, so asking for more just wastes a
  /// round-trip.
  static const _preferredMtu = 64;
```

改成：

```dart
  /// The firmware's `conn_gatt.att_mtu`. OTA needs at least 68 (APPLY is 65
  /// bytes plus the 3-byte ATT header) and fills each data packet up to
  /// `mtu − 3`; the negotiated value is `min(request, firmware)` anyway.
  static const _preferredMtu = 247;
```

在 `BluetoothService? _service;` 之後加一行：

```dart
  BluetoothService? _dfuService;
```

在 `connectionState` 監聽的 `case BluetoothConnectionState.disconnected:` 裡、`_service = null;` 之後，以及 `detach()` 裡的 `_service = null;` 之後，都加上：

```dart
            _dfuService = null;
```

（縮排比照該處的 `_service = null;`）

- [ ] **Step 4：握手時讀版本，並把 `_readChipId` 一般化**

在 `_runHandshake()` 裡，把

```dart
      final deviceId = await _readChipId(services);
```

改成：

```dart
      // The chip ID comes from the Device Information Service's Serial
      // Number — deliberately not the main service's old device-id
      // characteristic, which the firmware declares but never fills in.
      final deviceId = await _readText(
        services,
        deviceInfoServiceUuid,
        serialNumberCharUuid,
      );
      // Firmware without the DFU service can only be updated by wire, which
      // is worth knowing before offering an update.
      final dfu = services.firstWhereOrNull(
        (s) => s.uuid == Guid(dfuServiceUuid),
      );
      _dfuService = dfu;
      final firmwareVersion = dfu == null
          ? null
          : await _readText(services, dfuServiceUuid, dfuVersionCharUuid);
```

把 `handlers.onReady?.call(deviceId);` 改成：

```dart
      handlers.onReady?.call(
        SoleSessionInfo(
          deviceId: deviceId,
          firmwareVersion: firmwareVersion,
          dfuSupported: dfu != null,
        ),
      );
```

把整個 `_readChipId` 方法（含上方的 doc comment）換成：

```dart
  /// Reads a UTF-8 characteristic out of this connection's one discovery, or
  /// null when the sole does not have it (older firmware) or the read fails.
  Future<String?> _readText(
    List<BluetoothService> services,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final char = services
        .firstWhereOrNull((s) => s.uuid == Guid(serviceUuid))
        ?.characteristics
        .firstWhereOrNull((c) => c.uuid == Guid(characteristicUuid));
    if (char == null) {
      debugPrint('no $characteristicUuid — the firmware predates it');
      return null;
    }
    try {
      final text = utf8.decode(await char.read()).trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('read $characteristicUuid failed: $e');
      return null;
    }
  }
```

- [ ] **Step 5：加入 `dfuLink()` 和 `_BleDfuLink`**

在 `BleConnectionService` 裡、`writeString` 方法之後加入：

```dart
  /// The connected sole's DFU service as a [DfuLink], or null when nothing is
  /// connected or the firmware has no DFU service.
  DfuLink? dfuLink() {
    final device = _device;
    final dfu = _dfuService;
    if (device == null || dfu == null || !device.isConnected) return null;
    BluetoothCharacteristic? find(String uuid) =>
        dfu.characteristics.firstWhereOrNull((c) => c.uuid == Guid(uuid));
    final control = find(dfuControlCharUuid);
    final data = find(dfuDataCharUuid);
    if (control == null || data == null) return null;
    return _BleDfuLink(device, control, data);
  }
```

在檔案最後（`BleConnectionService` 類別結束之後）加入：

```dart

class _BleDfuLink implements DfuLink {
  _BleDfuLink(this._device, this._control, this._data);

  final BluetoothDevice _device;
  final BluetoothCharacteristic _control;
  final BluetoothCharacteristic _data;

  @override
  int get mtu => _device.mtuNow;

  @override
  bool get isConnected => _device.isConnected;

  @override
  Future<Stream<List<int>>> subscribeStatus() async {
    await _control.setNotifyValue(true);
    // onValueReceived, not lastValueStream: a stale STATUS must not be
    // replayed into a new transfer.
    return _control.onValueReceived;
  }

  @override
  Future<void> writeControl(List<int> bytes) =>
      _write(_control, bytes, withoutResponse: false);

  @override
  Future<void> writeData(List<int> bytes) =>
      _write(_data, bytes, withoutResponse: true);

  /// One ATT packet per write, always: the sole cannot take long writes (it
  /// stalls for ~30 s, then drops the link).
  Future<void> _write(
    BluetoothCharacteristic char,
    List<int> bytes, {
    required bool withoutResponse,
  }) async {
    final max = _device.mtuNow - 3;
    if (bytes.length > max) {
      throw ArgumentError('${bytes.length} bytes exceed one ATT write ($max)');
    }
    await char.write(
      bytes,
      withoutResponse: withoutResponse,
      allowLongWrite: false,
    );
  }
}
```

在 `ble_connection_service.dart` 開頭的 imports 加上：

```dart
import 'package:silversole/core/ble/ota/dfu_link.dart';
```

- [ ] **Step 6：讓 foreground controller 配合新的型別**

在 `lib/shared/providers/ble_foreground_controller.dart` 裡，把

```dart
          onReady: (deviceId) {
```

改成

```dart
          onReady: (info) {
            final deviceId = info.deviceId;
```

（下面的程式碼原本就用 `deviceId`，不用再改。）

- [ ] **Step 7：驗證**

執行：`flutter analyze lib test`，預期 `No issues found!`
執行：`flutter test`，預期 `All tests passed!`

- [ ] **Step 8：Commit**

```bash
git add lib/core/ble/ble_uuids.dart lib/core/ble/ble_connection_service.dart lib/shared/providers/ble_foreground_controller.dart
git commit -m "feat(ble): raise the MTU to 247 and expose the sole's DFU service"
```

---

### Task 6：`connectedSoleProvider` 與 `SoleConnectionController`

**Files:**
- Create: `lib/shared/models/connected_sole.dart`（另外由 build_runner 產生 `.freezed.dart`）
- Create: `lib/shared/providers/connected_sole_provider.dart`
- Create: `lib/shared/providers/sole_connection_controller.dart`
- Modify: `lib/shared/providers/ble_foreground_controller.dart`

**Interfaces:**
- Consumes：Task 4 的 `isReacquireTarget`、`matchReacquireTarget`、`ReacquireConfidence`、`SoleScanner.watch`；Task 5 的 `SoleSessionInfo`、`BleConnectionService.dfuLink()`
- Produces:
  - `ConnectedSole({required BlePairedDevice device, String? firmwareVersion, required bool dfuSupported})`（freezed）
  - `connectedSoleProvider: NotifierProvider<ConnectedSoleNotifier, ConnectedSole?>`，方法有 `set(ConnectedSole)`、`clear()`
  - `abstract interface class SoleConnectionController`：`void hold()`、`void release()`、`DfuLink? dfuLink()`、`Future<ReacquiredSole?> reacquire(BlePairedDevice target, {required Duration timeout})`
  - `class ReacquiredSole(SoleSessionInfo session, ReacquireConfidence confidence)`、`class NoSoleConnection implements SoleConnectionController`
  - `bleForegroundControlProvider` 的型別改成 `Provider<SoleConnectionController>`

這個任務同樣依賴 fbp 和權限 plugin，沒辦法做單元測試。Task 8 會用 fake 的 `SoleConnectionController` 測試使用它的那一方；這裡的實作要到 Task 12 實機驗收。

- [ ] **Step 1：建立模型** `lib/shared/models/connected_sole.dart`

```dart
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
```

執行：`dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2：建立** `lib/shared/providers/connected_sole_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/connected_sole.dart';

/// Set by the BLE foreground controller on every handshake, cleared on every
/// link loss.
class ConnectedSoleNotifier extends Notifier<ConnectedSole?> {
  @override
  ConnectedSole? build() => null;

  void set(ConnectedSole sole) => state = sole;

  void clear() => state = null;
}

final connectedSoleProvider =
    NotifierProvider<ConnectedSoleNotifier, ConnectedSole?>(
      ConnectedSoleNotifier.new,
    );
```

- [ ] **Step 3：建立** `lib/shared/providers/sole_connection_controller.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// What a firmware update needs from the auto-connect loop: keep it from
/// swapping soles mid-transfer, and bring the same sole back after it reboots.
abstract interface class SoleConnectionController {
  /// Stops searching and the watchdog until [release]; a manual primary-device
  /// pick is ignored meanwhile.
  void hold();

  /// Resumes normal auto-connect.
  void release();

  /// The connected sole's DFU link, or null when none is connected or its
  /// firmware has no DFU service.
  DfuLink? dfuLink();

  /// Finds [target] again after it rebooted, connects with the app's usual
  /// handlers and returns the new session — or null after [timeout].
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  });
}

@immutable
class ReacquiredSole {
  const ReacquiredSole(this.session, this.confidence);

  final SoleSessionInfo session;
  final ReacquireConfidence confidence;
}

/// Where the BLE pipeline does not run (anything but Android).
class NoSoleConnection implements SoleConnectionController {
  const NoSoleConnection();

  @override
  void hold() {}

  @override
  void release() {}

  @override
  DfuLink? dfuLink() => null;

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) async => null;
}
```

- [ ] **Step 4：修改 `ble_foreground_controller.dart`：imports、provider 型別與狀態變數**

在 imports 加上（依字母順序插入）：

```dart
import 'package:clock/clock.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
```

把

```dart
final bleForegroundControlProvider = Provider<void>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) return;
```

改成：

```dart
/// Lets an OTA wait for a rebooting sole without it being mistaken for the
/// last advertisements of the old firmware on its way down.
const _reacquireSettle = Duration(seconds: 3);

/// A found sole still needs to connect and handshake, however little of the
/// reacquire timeout is left.
const _minHandshakeWait = Duration(seconds: 20);

final bleForegroundControlProvider = Provider<SoleConnectionController>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const NoSoleConnection();
  }
```

在 `final live = ref.read(liveTelemetryProvider.notifier);` 之後加上：

```dart
  final connectedSole = ref.read(connectedSoleProvider.notifier);
```

在 `var searchAttempt = 0;` 之後加上：

```dart
  // An OTA owns the link between hold() and release(): nothing may search,
  // swap soles or chase a reboot meanwhile.
  var held = false;
  // Completed by onReady while reacquire() waits for the rebooted sole.
  Completer<SoleSessionInfo?>? readyWaiter;
```

- [ ] **Step 5：用下面的程式碼取代從 `// searchAndAttach and the two timers below call each other` 到檔案結尾（含最後的 `});`）的所有內容**

```dart
  // searchAndAttach and the two timers below call each other, and Dart has no
  // forward references for local functions — so one of them has to be a
  // variable.
  late final Future<void> Function({bool force}) searchAndAttach;

  /// 15, 30, then 60 s between searches, so a sole that is simply switched off
  /// does not keep a low-latency scan running every 15 s all day. Reset once a
  /// session is ready.
  void scheduleSearch() {
    const delays = [15, 30, 60];
    retryTimer?.cancel();
    final seconds =
        delays[searchAttempt < delays.length
            ? searchAttempt
            : delays.length - 1];
    searchAttempt++;
    debugPrint('sole search again in ${seconds}s');
    retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(searchAndAttach()),
    );
  }

  /// Gives [BleConnectionService]'s own fast reconnect a window to bring the
  /// same MAC back. When it cannot, the sole has most likely rebooted — it
  /// advertises a different MAC then, and only a fresh scan can find it.
  void armWatchdog([Duration delay = const Duration(seconds: 30)]) {
    watchdogTimer?.cancel();
    watchdogTimer = Timer(delay, () {
      if (bleConnectionService.isConnected) return;
      debugPrint('sole did not connect — searching again');
      unawaited(searchAndAttach());
    });
  }

  /// Connects to [pick] with the app's handlers, reusing its paired entry.
  /// False when the session could not even be armed.
  Future<bool> attachTo(
    SoleCandidate pick,
    List<BlePairedDevice> paired,
  ) async {
    // Reuse the stored entry for this sole, so its name and primary flag
    // survive; it only moves to the address the sole is on now, and picks up
    // the advertised ID if it was paired before the firmware sent one.
    final known = paired.firstWhereOrNull((d) => isSameSole(pick, d));
    final device =
        known?.copyWith(
          remoteId: pick.remoteId,
          deviceId: pick.deviceId ?? known.deviceId,
        ) ??
        BlePairedDevice(
          remoteId: pick.remoteId,
          name: pick.name,
          deviceId: pick.deviceId,
          lastRssi: pick.rssi,
        );
    boundDevice = device;

    final result = await bleConnectionService.attach(
      device,
      handlers: BleSessionHandlers(
        onImu: onImu,
        onRecordImu: onRecordImu,
        onFallDetect: onFallDetect,
        onDeviceStatus: (value) => unawaited(onDeviceStatus(value)),
        onReady: (info) {
          final deviceId = info.deviceId;
          // Connected and handshaked: the watchdog has nothing to rescue and
          // the next search starts from the short delay again.
          watchdogTimer?.cancel();
          searchAttempt = 0;
          // The Serial Number read and the advertisement carry the same ID;
          // a mismatch means one of them is being parsed wrong.
          if (deviceId != null &&
              pick.deviceId != null &&
              deviceId != pick.deviceId) {
            debugPrint(
              'device ID mismatch: advertised ${pick.deviceId}, '
              'read $deviceId',
            );
          }
          // Persist the moment we (re)connected so the status card can show a
          // real "last connected" time. The listener below ignores timestamp
          // changes, so this does not restart the search.
          final updated = (boundDevice ?? device).copyWith(
            deviceId: deviceId ?? boundDevice?.deviceId,
            lastConnectedAt: DateTime.now(),
          );
          boundDevice = updated;
          unawaited(settings.addOrUpdatePairedDevice(updated));
          connectedSole.set(
            ConnectedSole(
              device: updated,
              firmwareVersion: info.firmwareVersion,
              dfuSupported: info.dfuSupported,
            ),
          );
          final waiter = readyWaiter;
          if (waiter != null && !waiter.isCompleted) waiter.complete(info);
          debugPrint(
            'sole session ready: deviceId=${updated.deviceId} '
            'firmware=${info.firmwareVersion}',
          );
        },
        onDisconnected: (reason) {
          debugPrint('sole disconnected: $reason');
          connectedSole.clear();
          // During an update the reboot is expected, and reacquire() — not the
          // watchdog — brings the sole back.
          if (!held) armWatchdog();
        },
      ),
    );

    if (result case Error(:final error)) {
      debugPrint('sole attach failed: $error');
      return false;
    }
    debugPrint('sole session attached');
    return true;
  }

  /// Finds a paired sole that is actually advertising and connects to it.
  ///
  /// Soles are recognised by the chip ID in their advertisement, so a sole is
  /// found again whatever address it comes back on; firmware too old to send
  /// the ID falls back to the address, which is what [pickSole] spells out.
  /// [force] is the manual primary-device pick asking us to look even though a
  /// session is already up.
  searchAndAttach = ({bool force = false}) async {
    // An update owns the link until it releases it.
    if (searching || held) return;
    if (!force && bleConnectionService.isConnected) return;

    searching = true;
    retryTimer?.cancel();
    watchdogTimer?.cancel();
    try {
      final current = ref.read(settingsProvider);
      // Never reach for a stranger's sole: auto-connect starts only once the
      // user has paired one by hand.
      if (current.pairedDevicesList.isEmpty) {
        boundDevice = null;
        await bleConnectionService.detach();
        await stopBleService();
        return;
      }

      if (!await ensureConnectPermission() || !await ensureScanPermission()) {
        debugPrint('ble permission denied');
        scheduleSearch();
        return;
      }

      await startBleService();

      final pick = pickSole(
        await scanner.scan(),
        paired: current.pairedDevicesList,
      );
      if (pick == null) {
        debugPrint('no paired sole advertising');
        scheduleSearch();
        return;
      }
      debugPrint('sole found: $pick');

      if (await attachTo(pick, current.pairedDevicesList)) {
        armWatchdog();
      } else {
        scheduleSearch();
      }
    } finally {
      searching = false;
    }
  };

  /// Brings [target] back after it rebooted into new firmware and returns its
  /// fresh session, or null when it does not show up within [timeout].
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target,
    Duration timeout,
  ) async {
    final deadline = clock.now().add(timeout);
    // The old session's own reconnect would chase the address the sole had
    // before it rebooted.
    await bleConnectionService.detach();
    connectedSole.clear();
    await Future<void>.delayed(_reacquireSettle);

    final paired = ref.read(settingsProvider).pairedDevicesList;
    final seen = await scanner.watch(
      timeout: deadline.difference(clock.now()),
      stopWhen: (c) => isReacquireTarget(c, target),
    );
    final match = matchReacquireTarget(
      target: target,
      seen: seen,
      paired: paired,
    );
    if (match == null) {
      debugPrint('updated sole not found among ${seen.length} soles');
      return null;
    }

    final waiter = Completer<SoleSessionInfo?>();
    readyWaiter = waiter;
    try {
      if (!await attachTo(match.candidate, paired)) return null;
      final left = deadline.difference(clock.now());
      final info = await waiter.future.timeout(
        left > _minHandshakeWait ? left : _minHandshakeWait,
        onTimeout: () => null,
      );
      return info == null ? null : ReacquiredSole(info, match.confidence);
    } finally {
      readyWaiter = null;
    }
  }

  // The primary-device pick and "is anything paired at all" are the only
  // settings that change what we should be connected to. Every reconnect
  // rewrites the paired entry's timestamp, which this selector ignores on
  // purpose — otherwise each reconnect would kick off another search.
  ref.listen<
    ({String? preferredKey, String? preferredAddress, int pairedCount})
  >(
    settingsProvider.select(
      (s) => (
        preferredKey: s.preferredDevice?.identityKey,
        preferredAddress: s.preferredDevice?.remoteId,
        pairedCount: s.pairedDevicesList.length,
      ),
    ),
    (prev, next) {
      if (next.pairedCount == 0) {
        retryTimer?.cancel();
        watchdogTimer?.cancel();
        boundDevice = null;
        connectedSole.clear();
        unawaited(
          bleConnectionService.detach().whenComplete(() => stopBleService()),
        );
        return;
      }
      // A manual pick goes looking even while another sole is connected;
      // anything else only searches when nothing is connected. A pick changes
      // both the identity and the address. The connected sole changes only
      // one of them, and that must not force a reconnect: on a new address its
      // identity stays the same, and when an old entry picks up its ID its
      // address stays the same.
      final picked =
          prev?.preferredKey != next.preferredKey &&
          prev?.preferredAddress != next.preferredAddress;
      unawaited(searchAndAttach(force: picked));
    },
    fireImmediately: true,
  );

  return _ForegroundSoleConnection(
    onHold: () {
      held = true;
      retryTimer?.cancel();
      watchdogTimer?.cancel();
    },
    onRelease: () {
      if (!held) return;
      held = false;
      unawaited(searchAndAttach());
    },
    onDfuLink: bleConnectionService.dfuLink,
    onReacquire: reacquire,
  );
});

class _ForegroundSoleConnection implements SoleConnectionController {
  _ForegroundSoleConnection({
    required this.onHold,
    required this.onRelease,
    required this.onDfuLink,
    required this.onReacquire,
  });

  final void Function() onHold;
  final void Function() onRelease;
  final DfuLink? Function() onDfuLink;
  final Future<ReacquiredSole?> Function(BlePairedDevice, Duration) onReacquire;

  @override
  void hold() => onHold();

  @override
  void release() => onRelease();

  @override
  DfuLink? dfuLink() => onDfuLink();

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) => onReacquire(target, timeout);
}
```

再在 imports 加上 `import 'package:silversole/core/ble/ota/dfu_link.dart';`（`_ForegroundSoleConnection` 會用到）。

- [ ] **Step 6：驗證**

執行：`flutter analyze lib test`，預期 `No issues found!`。`lib/app.dart` 裡的 `ref.watch(bleForegroundControlProvider);` 不用修改，它只是為了觸發 provider 的副作用。
執行：`flutter test`，預期 `All tests passed!`

- [ ] **Step 7：Commit**

```bash
git add lib/shared/models/connected_sole.dart lib/shared/models/connected_sole.freezed.dart lib/shared/providers/connected_sole_provider.dart lib/shared/providers/sole_connection_controller.dart lib/shared/providers/ble_foreground_controller.dart
git commit -m "feat(ble): let an update hold the link and reacquire the rebooted sole"
```

---

### Task 7：開發者模式設定與「有沒有新版」判斷

**Files:**
- Modify: `lib/shared/models/app_settings.dart`（另外由 build_runner 重新產生 `.freezed.dart`）
- Modify: `lib/core/data/save_service.dart`
- Modify: `lib/shared/providers/settings_provider.dart`
- Create: `lib/shared/providers/firmware_check_provider.dart`
- Test: `test/firmware_check_test.dart`、`test/firmware_dev_mode_setting_test.dart`

**Interfaces:**
- Consumes：Task 2 的 `FirmwareReleaseService`、`FirmwareChannel`、`firmwareManifestSchema`、`compareFirmware`、`parseFirmwareVersion`；Task 6 的 `ConnectedSole`、`connectedSoleProvider`
- Produces:
  - `AppSettings.firmwareDevMode`（`bool`，預設 false）、`LocalSavableKey.firmwareDevMode`、`SettingsNotifier.setFirmwareDevMode(bool)`
  - `enum FirmwareCheckStatus { notConnected, needsWiredUpdate, versionUnreadable, checkFailed, manifestUnsupported, upToDate, updateAvailable, downgradeAvailable }`
  - `class FirmwareCheck(FirmwareCheckStatus status, {ConnectedSole? sole, FirmwareManifest? manifest})`
  - `FirmwareCheck? firmwarePrecheck(ConnectedSole? sole)`
  - `FirmwareCheck evaluateManifest(ConnectedSole sole, Result<FirmwareManifest> fetched, {required bool devMode})`
  - `firmwareReleaseServiceProvider: Provider<FirmwareReleaseService>`
  - `firmwareCheckProvider: FutureProvider<FirmwareCheck>`

- [ ] **Step 1：寫會失敗的測試** `test/firmware_check_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';

ConnectedSole _sole({String? version = '0.4.0', bool dfu = true}) => ConnectedSole(
  device: const BlePairedDevice(remoteId: 'M', name: 'SilverSole', deviceId: 'ID'),
  firmwareVersion: version,
  dfuSupported: dfu,
);

Result<FirmwareManifest> _server(String version, {int schema = 1}) => Result.ok(
  FirmwareManifest(
    schema: schema,
    channel: 'stable',
    version: version,
    size: 1,
    sha256: '00',
    binPath: 'b',
    sigPath: 's',
  ),
);

FirmwareCheckStatus _status(String server, {String device = '0.4.0', bool devMode = false}) =>
    evaluateManifest(_sole(version: device), _server(server), devMode: devMode).status;

void main() {
  group('firmwarePrecheck', () {
    test('nothing to check without a connected sole', () {
      expect(firmwarePrecheck(null)?.status, FirmwareCheckStatus.notConnected);
    });

    test('firmware without the DFU service needs a wired update', () {
      expect(firmwarePrecheck(_sole(dfu: false))?.status, FirmwareCheckStatus.needsWiredUpdate);
    });

    test('a version that is not semver is never offered an update', () {
      expect(firmwarePrecheck(_sole(version: 'abc'))?.status, FirmwareCheckStatus.versionUnreadable);
      expect(firmwarePrecheck(_sole(version: null))?.status, FirmwareCheckStatus.versionUnreadable);
    });

    test('a readable version goes on to the server', () {
      expect(firmwarePrecheck(_sole()), isNull);
    });
  });

  group('evaluateManifest', () {
    test('a newer release is offered, with its manifest', () {
      final check = evaluateManifest(_sole(), _server('0.5.0'), devMode: false);
      expect(check.status, FirmwareCheckStatus.updateAvailable);
      expect(check.manifest?.version, '0.5.0');
    });

    test('a release outranks its own release candidate', () {
      expect(_status('0.4.0', device: '0.4.0-rc.1'), FirmwareCheckStatus.updateAvailable);
    });

    test('the same version is up to date', () {
      expect(_status('0.4.0'), FirmwareCheckStatus.upToDate);
    });

    test('an older release is never offered outside developer mode', () {
      expect(_status('0.3.0'), FirmwareCheckStatus.upToDate);
      expect(_status('0.3.0', devMode: true), FirmwareCheckStatus.downgradeAvailable);
    });

    test('a manifest schema this app does not know is not trusted', () {
      final check = evaluateManifest(_sole(), _server('0.5.0', schema: 2), devMode: false);
      expect(check.status, FirmwareCheckStatus.manifestUnsupported);
    });

    test('a server version that is not semver is not trusted', () {
      expect(_status('latest'), FirmwareCheckStatus.manifestUnsupported);
    });

    test('a failed fetch can be retried', () {
      final check = evaluateManifest(
        _sole(),
        const Result.error(DfuException(DfuFailure.manifestUnavailable)),
        devMode: false,
      );
      expect(check.status, FirmwareCheckStatus.checkFailed);
    });
  });
}
```

- [ ] **Step 2：寫會失敗的測試** `test/firmware_dev_mode_setting_test.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('developer mode survives a restart and can be switched off', () async {
    SharedPreferences.setMockInitialValues({'firmware_dev_mode': 'true'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(settingsProvider);
    await _settle();
    expect(container.read(settingsProvider).firmwareDevMode, isTrue);

    await container.read(settingsProvider.notifier).setFirmwareDevMode(false);
    expect(container.read(settingsProvider).firmwareDevMode, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('firmware_dev_mode'), 'false');
  });
}
```

- [ ] **Step 3：執行，確認失敗**

執行：`flutter test test/firmware_check_test.dart test/firmware_dev_mode_setting_test.dart`
預期：編譯失敗，原因是找不到 `firmware_check_provider.dart` 和 `firmwareDevMode`。

- [ ] **Step 4：開發者模式設定**

`lib/shared/models/app_settings.dart`：在 `@Default(<BlePairedDevice>[]) List<BlePairedDevice> pairedDevicesList,` 之後加上：

```dart
    /// Hidden developer mode (seven taps on the firmware version): reads the
    /// beta firmware channel and allows a warned downgrade.
    @Default(false) bool firmwareDevMode,
```

`lib/core/data/save_service.dart`：把 enum 的最後兩項

```dart
  transmissionMethod('transmission_method'),
  pairedDevices('paired_devices');
```

改成：

```dart
  transmissionMethod('transmission_method'),
  pairedDevices('paired_devices'),
  firmwareDevMode('firmware_dev_mode');
```

`lib/shared/providers/settings_provider.dart`：在 `_load()` 裡的 `final pairedDevicesList = await loadLocalPairedDevices() ?? [];` 之後加上：

```dart
    final firmwareDevMode =
        await loadLocalValue(LocalSavableKey.firmwareDevMode) == 'true';
```

在同一個方法的 `state = state.copyWith(` 參數最後加上 `firmwareDevMode: firmwareDevMode,`，然後在 `setTransmissionMethod` 之後加入：

```dart
  Future<void> setFirmwareDevMode(bool value) async {
    await saveLocalValue(
      LocalSavableKey.firmwareDevMode,
      value ? 'true' : 'false',
    );
    state = state.copyWith(firmwareDevMode: value);
  }
```

執行：`dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5：實作** `lib/shared/providers/firmware_check_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/firmware_version.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

enum FirmwareCheckStatus {
  notConnected,
  needsWiredUpdate,
  versionUnreadable,
  checkFailed,
  manifestUnsupported,
  upToDate,
  updateAvailable,
  downgradeAvailable,
}

/// Whether the connected sole has firmware to install, and which.
@immutable
class FirmwareCheck {
  const FirmwareCheck(this.status, {this.sole, this.manifest});

  final FirmwareCheckStatus status;
  final ConnectedSole? sole;

  /// The release on offer — set for updateAvailable and downgradeAvailable.
  final FirmwareManifest? manifest;
}

/// The verdicts that need no server: no sole, no DFU service, or a version
/// that cannot be compared. Null when the server should be asked.
FirmwareCheck? firmwarePrecheck(ConnectedSole? sole) {
  if (sole == null) return const FirmwareCheck(FirmwareCheckStatus.notConnected);
  if (!sole.dfuSupported) {
    return FirmwareCheck(FirmwareCheckStatus.needsWiredUpdate, sole: sole);
  }
  if (parseFirmwareVersion(sole.firmwareVersion) == null) {
    debugPrint('sole firmware version is not semver: ${sole.firmwareVersion}');
    return FirmwareCheck(FirmwareCheckStatus.versionUnreadable, sole: sole);
  }
  return null;
}

/// Compares the sole with the channel's manifest. The sole does not refuse
/// older firmware, so the app must never offer it — except to a developer who
/// turned developer mode on.
FirmwareCheck evaluateManifest(
  ConnectedSole sole,
  Result<FirmwareManifest> fetched, {
  required bool devMode,
}) {
  if (fetched case Error(:final error)) {
    debugPrint('firmware manifest unavailable: $error');
    return FirmwareCheck(FirmwareCheckStatus.checkFailed, sole: sole);
  }
  final manifest = (fetched as Ok<FirmwareManifest>).value;
  if (manifest.schema != firmwareManifestSchema) {
    debugPrint('firmware manifest schema ${manifest.schema} is not understood');
    return FirmwareCheck(FirmwareCheckStatus.manifestUnsupported, sole: sole);
  }
  return switch (compareFirmware(sole.firmwareVersion, manifest.version)) {
    FirmwareComparison.upgrade => FirmwareCheck(
      FirmwareCheckStatus.updateAvailable,
      sole: sole,
      manifest: manifest,
    ),
    FirmwareComparison.downgrade when devMode => FirmwareCheck(
      FirmwareCheckStatus.downgradeAvailable,
      sole: sole,
      manifest: manifest,
    ),
    FirmwareComparison.downgrade || FirmwareComparison.same => FirmwareCheck(
      FirmwareCheckStatus.upToDate,
      sole: sole,
    ),
    // The sole's version passed the precheck, so it is the server's that is
    // not semver.
    null => FirmwareCheck(FirmwareCheckStatus.manifestUnsupported, sole: sole),
  };
}

final firmwareReleaseServiceProvider = Provider<FirmwareReleaseService>(
  (_) => FirmwareReleaseService(),
);

/// Re-checked on every handshake (the connected sole changes) and whenever
/// developer mode switches channel; the devices page's firmware card shows it.
final firmwareCheckProvider = FutureProvider<FirmwareCheck>((ref) async {
  final sole = ref.watch(connectedSoleProvider);
  final devMode = ref.watch(settingsProvider.select((s) => s.firmwareDevMode));
  final early = firmwarePrecheck(sole);
  if (early != null) return early;
  final fetched = await ref
      .read(firmwareReleaseServiceProvider)
      .fetchManifest(devMode ? FirmwareChannel.beta : FirmwareChannel.stable);
  return evaluateManifest(sole!, fetched, devMode: devMode);
});
```

- [ ] **Step 6：執行，確認通過**

執行：`flutter test test/firmware_check_test.dart test/firmware_dev_mode_setting_test.dart`
預期：全部 PASS。

- [ ] **Step 7：Commit**

```bash
git add lib/shared/models/app_settings.dart lib/shared/models/app_settings.freezed.dart lib/core/data/save_service.dart lib/shared/providers/settings_provider.dart lib/shared/providers/firmware_check_provider.dart test/firmware_check_test.dart test/firmware_dev_mode_setting_test.dart
git commit -m "feat(ota): decide whether the connected sole has firmware to install"
```

---

### Task 8：OTA 狀態機，以及更新期間維持「在線」

**Files:**
- Create: `lib/shared/models/ota_state.dart`（另外由 build_runner 產生 `.freezed.dart`）
- Create: `lib/shared/providers/firmware_update_provider.dart`
- Modify: `lib/shared/providers/telemetry_process_providers/device_online_provider.dart`
- Test: `test/firmware_update_provider_test.dart`
- Modify test: `test/device_online_provider_test.dart`

**Interfaces:**
- Consumes：Task 2 的 `FirmwareImage`、`FirmwareManifest`、`compareFirmware`；Task 3 的 `DfuTransfer` 和 `FakeDfuSole`；Task 6 的 `SoleConnectionController`、`ReacquiredSole`、`connectedSoleProvider`、`bleForegroundControlProvider`；Task 7 的 `firmwareReleaseServiceProvider`
- Produces:
  - `enum OtaPhase { idle, downloading, transferring, verifying, rebooting, succeeded, notUpdated, unconfirmed, localFinished, failed }`
  - `OtaState({phase, committed, size, fromVersion, toVersion, readVersion, probable, failure})`，有 `bool get busy` 和 `double get progress`
  - 常數 `otaMinBatteryPercent = 30`、`otaReacquireTimeout = 90s`、`otaBytesPerSecond = 7 * 1024`
  - `keepScreenOnProvider: Provider<Future<void> Function(bool on)>`
  - `firmwareUpdateProvider: NotifierProvider<FirmwareUpdateNotifier, OtaState>`，方法有 `installRelease(FirmwareManifest)`、`installLocal(FirmwareImage)`、`cancel()`、`reset()`

- [ ] **Step 1：建立模型** `lib/shared/models/ota_state.dart`

```dart
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
```

執行：`dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2：寫會失敗的測試** `test/firmware_update_provider_test.dart`

```dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

import 'helpers/fake_dfu_sole.dart';

final _bin = Uint8List.fromList(List<int>.generate(6000, (i) => i * 13 & 0xFF));

FirmwareImage _image({String? version = '0.5.0'}) => FirmwareImage(
  bin: _bin,
  signature: Uint8List(64),
  sha256: Uint8List.fromList(sha256.convert(_bin).bytes),
  version: version,
);

const _manifest = FirmwareManifest(
  schema: 1,
  channel: 'stable',
  version: '0.5.0',
  size: 6000,
  sha256: '-',
  binPath: 'b',
  sigPath: 's',
);

const _sole = ConnectedSole(
  device: BlePairedDevice(remoteId: 'M', name: 'SilverSole', deviceId: 'ID'),
  firmwareVersion: '0.4.0',
  dfuSupported: true,
);

class _FakeConnection implements SoleConnectionController {
  _FakeConnection(this.sole);

  final FakeDfuSole sole;

  /// The session the sole comes back with; null when it never does.
  SoleSessionInfo? comesBackWith = const SoleSessionInfo(
    deviceId: 'ID',
    firmwareVersion: '0.5.0',
    dfuSupported: true,
  );
  var holds = 0;
  var releases = 0;

  @override
  void hold() => holds++;

  @override
  void release() => releases++;

  @override
  DfuLink? dfuLink() => sole;

  @override
  Future<ReacquiredSole?> reacquire(BlePairedDevice target, {required Duration timeout}) async {
    final session = comesBackWith;
    return session == null ? null : ReacquiredSole(session, ReacquireConfidence.certain);
  }
}

class _FakeRelease extends FirmwareReleaseService {
  _FakeRelease(this.image);

  final FirmwareImage image;

  @override
  Future<Result<FirmwareImage>> download(FirmwareManifest manifest) async => Result.ok(image);
}

/// Builds a container with [connection] and the sole connected, runs [body]
/// and lets fake time run out, then returns the final state.
OtaState _run(
  _FakeConnection connection,
  void Function(ProviderContainer c) body, {
  ConnectedSole? sole = _sole,
}) {
  late OtaState state;
  fakeAsync((async) {
    final container = ProviderContainer(
      overrides: [
        bleForegroundControlProvider.overrideWithValue(connection),
        keepScreenOnProvider.overrideWithValue((_) async {}),
        firmwareReleaseServiceProvider.overrideWithValue(_FakeRelease(_image())),
      ],
    );
    if (sole != null) container.read(connectedSoleProvider.notifier).set(sole);
    body(container);
    async.elapse(const Duration(minutes: 5));
    state = container.read(firmwareUpdateProvider);
    container.dispose();
  });
  return state;
}

void main() {
  test('an update that comes back on the new version succeeds', () {
    final connection = _FakeConnection(FakeDfuSole());
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.succeeded);
    expect(state.readVersion, '0.5.0');
    expect(connection.holds, 1);
    expect(connection.releases, 1);
  });

  test('coming back on the old version is not updated', () {
    final connection = _FakeConnection(FakeDfuSole())
      ..comesBackWith = const SoleSessionInfo(firmwareVersion: '0.4.0', dfuSupported: true);
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.notUpdated);
  });

  test('a sole that never comes back is unconfirmed', () {
    final connection = _FakeConnection(FakeDfuSole())..comesBackWith = null;
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.unconfirmed);
    expect(connection.releases, 1);
  });

  test('a low battery is refused before anything reaches the sole', () {
    final sole = FakeDfuSole();
    final connection = _FakeConnection(sole);
    final state = _run(connection, (c) {
      c.read(liveTelemetryProvider.notifier).updateImuNotifyData(
        const ImuNotifyDataModel(
          ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0,
          pressure: [0, 0, 0], batteryPercent: 20, isCharging: false,
        ),
      );
      c.read(firmwareUpdateProvider.notifier).installRelease(_manifest);
    });
    expect(state.failure, DfuFailure.lowBattery);
    expect(sole.controlWrites, isEmpty);
    expect(connection.holds, 0);
  });

  test('BAD_SIGNATURE is final, and the link is released', () {
    final connection = _FakeConnection(
      FakeDfuSole()..applyAnswers.add(DfuResult.badSignature),
    );
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.failed);
    expect(state.failure, DfuFailure.badSignature);
    expect(state.failure!.retryable, isFalse);
    expect(connection.releases, 1);
  });

  test('a local image reports the version the sole booted with', () {
    final connection = _FakeConnection(FakeDfuSole())
      ..comesBackWith = const SoleSessionInfo(firmwareVersion: '0.6.0-dev.1', dfuSupported: true);
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installLocal(_image(version: null)),
    );
    expect(state.phase, OtaPhase.localFinished);
    expect(state.fromVersion, '0.4.0');
    expect(state.readVersion, '0.6.0-dev.1');
  });

  test('without a connected sole nothing starts', () {
    final connection = _FakeConnection(FakeDfuSole());
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
      sole: null,
    );
    expect(state.failure, DfuFailure.notConnected);
    expect(connection.holds, 0);
  });
}
```

- [ ] **Step 3：執行，確認失敗**

執行：`flutter test test/firmware_update_provider_test.dart`
預期：編譯失敗，原因是找不到 `firmware_update_provider.dart`。

- [ ] **Step 4：實作** `lib/shared/providers/firmware_update_provider.dart`

```dart
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_transfer.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/firmware_version.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Below this the sole refuses an update (LOW_BATTERY), so the app refuses
/// first.
const otaMinBatteryPercent = 30;

/// How long a rebooting sole gets to come back on its new firmware.
const otaReacquireTimeout = Duration(seconds: 90);

/// Measured throughput at MTU 247 (the handoff's §4), for the estimate shown
/// before an update.
const otaBytesPerSecond = 7 * 1024;

/// Keeps the screen on while an update runs, so the phone does not doze off
/// in the middle of the transfer.
final keepScreenOnProvider = Provider<Future<void> Function(bool on)>(
  (_) => (on) => WakelockPlus.toggle(enable: on),
);

/// One firmware update, from download to verdict (the OTA spec's §2.4).
class FirmwareUpdateNotifier extends Notifier<OtaState> {
  DfuTransfer? _transfer;
  var _cancelRequested = false;

  @override
  OtaState build() => const OtaState();

  /// Downloads [manifest]'s image, checks it and installs it.
  Future<void> installRelease(FirmwareManifest manifest) async {
    if (state.busy) return;
    final sole = ref.read(connectedSoleProvider);
    if (_refused(sole)) return;
    _cancelRequested = false;
    state = OtaState(
      phase: OtaPhase.downloading,
      fromVersion: sole!.firmwareVersion,
      toVersion: manifest.version,
    );
    final downloaded = await ref
        .read(firmwareReleaseServiceProvider)
        .download(manifest);
    if (_cancelRequested) {
      _fail(DfuFailure.cancelled);
      return;
    }
    switch (downloaded) {
      case Error(:final error):
        _failWith(error);
      case Ok(:final value):
        await _install(sole, value);
    }
  }

  /// Installs a developer's own image (debug builds only).
  Future<void> installLocal(FirmwareImage image) async {
    if (state.busy) return;
    final sole = ref.read(connectedSoleProvider);
    if (_refused(sole)) return;
    _cancelRequested = false;
    state = OtaState(
      phase: OtaPhase.transferring,
      fromVersion: sole!.firmwareVersion,
      size: image.bin.length,
    );
    await _install(sole, image);
  }

  /// Stops a download or transfer. The sole keeps its old firmware.
  Future<void> cancel() async {
    _cancelRequested = true;
    await _transfer?.cancel();
  }

  /// Back to the confirmation, once the last update has an outcome.
  void reset() {
    if (!state.busy) state = const OtaState();
  }

  bool _refused(ConnectedSole? sole) {
    final failure = _preflight(sole);
    if (failure == null) return false;
    state = OtaState(
      phase: OtaPhase.failed,
      failure: failure,
      fromVersion: sole?.firmwareVersion,
    );
    return true;
  }

  DfuFailure? _preflight(ConnectedSole? sole) {
    if (sole == null) return DfuFailure.notConnected;
    if (!sole.dfuSupported) return DfuFailure.dfuUnsupported;
    // 255 (unknown) is let through: the sole checks its own battery on START.
    final battery = ref
        .read(liveTelemetryProvider)
        .recentImu
        .lastOrNull
        ?.batteryPercent
        .validBatteryPercent;
    if (battery != null && battery < otaMinBatteryPercent) {
      return DfuFailure.lowBattery;
    }
    return null;
  }

  Future<void> _install(ConnectedSole sole, FirmwareImage image) async {
    final connection = ref.read(bleForegroundControlProvider);
    final link = connection.dfuLink();
    if (link == null) {
      _fail(DfuFailure.notConnected);
      return;
    }
    final keepScreenOn = ref.read(keepScreenOnProvider);
    connection.hold();
    await _quietly(() => keepScreenOn(true));
    try {
      if (_cancelRequested) {
        _fail(DfuFailure.cancelled);
        return;
      }
      final size = image.bin.length;
      state = state.copyWith(
        phase: OtaPhase.transferring,
        committed: 0,
        size: size,
      );
      final transfer = DfuTransfer(link);
      _transfer = transfer;
      final result = await transfer.run(
        image: image.bin,
        sha256: image.sha256,
        signature: image.signature,
        onProgress: (committed, total) => state = state.copyWith(
          committed: committed,
          phase: committed == total
              ? OtaPhase.verifying
              : OtaPhase.transferring,
        ),
      );
      _transfer = null;
      if (result case Error(:final error)) {
        final failure = error is DfuException
            ? error.failure
            : DfuFailure.disconnected;
        // Once APPLY is out the sole may have installed the image even though
        // its answer was lost; only the version it boots with can tell.
        final mayHaveApplied =
            transfer.applySent &&
            (failure == DfuFailure.disconnected ||
                failure == DfuFailure.timeout);
        if (!mayHaveApplied) {
          _failWith(error);
          return;
        }
      }
      state = state.copyWith(phase: OtaPhase.rebooting);
      final back = await connection.reacquire(
        sole.device,
        timeout: otaReacquireTimeout,
      );
      state = _verdict(back, expected: image.version);
    } finally {
      _transfer = null;
      connection.release();
      await _quietly(() => keepScreenOn(false));
    }
  }

  OtaState _verdict(ReacquiredSole? back, {required String? expected}) {
    final read = back?.session.firmwareVersion;
    if (back == null || read == null) {
      return state.copyWith(phase: OtaPhase.unconfirmed);
    }
    final next = state.copyWith(
      readVersion: read,
      probable: back.confidence == ReacquireConfidence.probable,
    );
    if (expected == null) return next.copyWith(phase: OtaPhase.localFinished);
    if (compareFirmware(read, expected) == FirmwareComparison.same) {
      return next.copyWith(phase: OtaPhase.succeeded);
    }
    if (compareFirmware(read, state.fromVersion) == FirmwareComparison.same) {
      return next.copyWith(phase: OtaPhase.notUpdated);
    }
    return next.copyWith(phase: OtaPhase.unconfirmed);
  }

  void _fail(DfuFailure failure) =>
      state = state.copyWith(phase: OtaPhase.failed, failure: failure);

  void _failWith(Exception error) {
    debugPrint('ota failed: $error');
    _fail(error is DfuException ? error.failure : DfuFailure.disconnected);
  }

  /// Screen-on is a nicety: its failure must not fail the update.
  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('ota: keep screen on failed: $e');
    }
  }
}

final firmwareUpdateProvider =
    NotifierProvider<FirmwareUpdateNotifier, OtaState>(
      FirmwareUpdateNotifier.new,
    );
```

如果 analyze 回報 `firmware_manifest.dart` 或 `sole_connection_controller.dart` 的 import 沒用到，就把那一行刪掉。`ReacquiredSole` 型別出現在 `_verdict` 的參數裡，所以 `sole_connection_controller.dart` 會用到；`FirmwareManifest` 出現在 `installRelease` 的參數裡，所以 `firmware_manifest.dart` 也會用到。

- [ ] **Step 5：執行，確認通過**

執行：`flutter test test/firmware_update_provider_test.dart`
預期：7 個測試全部 PASS。

- [ ] **Step 6：在既有的 `test/device_online_provider_test.dart` 的 `main()` 裡追加會失敗的測試**

在檔案開頭加上 imports：

```dart
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
```

在 `main()` 最後追加：

```dart
  test('a sole being updated stays online while its stream is paused', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [firmwareUpdateProvider.overrideWith(_UpdatingNotifier.new)],
      );
      addTearDown(container.dispose);

      expect(container.read(deviceOnlineProvider), isTrue);
      async.elapse(TelemetryFacade.onlineWindow * 3);
      expect(container.read(deviceOnlineProvider), isTrue);
    });
  });
```

在檔尾（`main()` 之外）加入：

```dart
class _UpdatingNotifier extends FirmwareUpdateNotifier {
  @override
  OtaState build() => const OtaState(phase: OtaPhase.transferring);
}
```

執行：`flutter test test/device_online_provider_test.dart`
預期：新的測試 FAIL，因為沒有遙測資料時 `deviceOnlineProvider` 是 false。

- [ ] **Step 7：修改** `lib/shared/providers/telemetry_process_providers/device_online_provider.dart`

加上 import：

```dart
import 'package:silversole/shared/providers/firmware_update_provider.dart';
```

把 class 主體改成：

```dart
class DeviceOnlineNotifier extends Notifier<bool> {
  Timer? _timer;

  /// A sole being updated pauses its 50 Hz stream and then reboots; it is
  /// busy, not gone, so it stays online until the update has an outcome.
  var _updating = false;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _updating = ref.watch(firmwareUpdateProvider.select((s) => s.busy));
    ref.listen(
      liveTelemetryProvider.select((s) => s.updatedAt),
      (_, next) => _reschedule(next),
    );
    final updatedAt = ref.read(liveTelemetryProvider).updatedAt;
    _arm(updatedAt); // build() must not write `state`; only schedule the timer.
    return _updating ||
        ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
  }

  void _reschedule(DateTime? updatedAt) {
    state =
        _updating ||
        ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
    _arm(updatedAt);
  }

  /// Schedules the exact moment the device falls outside the online window.
  void _arm(DateTime? updatedAt) {
    _timer?.cancel();
    if (updatedAt == null) return;
    final remaining =
        TelemetryFacade.onlineWindow - clock.now().difference(updatedAt);
    if (remaining <= Duration.zero) return; // already stale
    _timer = Timer(remaining, () => state = _updating);
  }
}
```

（class 上方的 doc comment 保持原樣。）

- [ ] **Step 8：執行，確認全部通過**

執行：`flutter test test/device_online_provider_test.dart test/firmware_update_provider_test.dart`
預期：全部 PASS。
執行：`flutter analyze lib test`
預期：`No issues found!`

- [ ] **Step 9：Commit**

```bash
git add lib/shared/models/ota_state.dart lib/shared/models/ota_state.freezed.dart lib/shared/providers/firmware_update_provider.dart lib/shared/providers/telemetry_process_providers/device_online_provider.dart test/firmware_update_provider_test.dart test/device_online_provider_test.dart
git commit -m "feat(ota): run an update from download to verdict"
```

---

### Task 9：裝置頁的韌體卡片（兩個主題）、開發者模式、本機選檔

**Files:**
- Create: `lib/shared/widgets/firmware_card_parts.dart`
- Modify: `lib/shared/pages/devices_page.dart`（`_FirmwareCard`、class 的 doc comment、imports）
- Modify: `lib/shared/pages/theme_two/devices_page_t2.dart`（`_FirmwareCard`、class 的 doc comment、imports）
- Modify: `lib/shared/models/device_view_data.dart`（刪除 `MockFirmware`）
- Modify: `assets/translations/strings.csv`
- Test: `test/firmware_card_parts_test.dart`

**Interfaces:**
- Consumes：Task 7 的 `FirmwareCheck`、`FirmwareCheckStatus`、`firmwareCheckProvider`、`firmwareReleaseServiceProvider`、`setFirmwareDevMode`；Task 2 的 `FirmwareReleaseService.localImage`
- Produces:
  - `class DevModeTapTarget({required Widget child})`
  - `String soleLabel(BlePairedDevice device)`、`String? firmwareCardDetail(FirmwareCheck? check)`
  - `enum FirmwareCardAction { none, upToDate, update, downgrade, needsWiredUpdate, versionUnreadable, retry, appTooOld }`、`FirmwareCardAction firmwareCardAction(FirmwareCheck)`
  - `void openFirmwareUpdate(BuildContext, FirmwareCheck)`、`Future<void> confirmDowngrade(BuildContext, FirmwareCheck)`、`Future<void> pickLocalFirmware(BuildContext, WidgetRef)`
  - 路由 `/firmware-update` 的 `extra` 是 `FirmwareManifest` 或 `FirmwareImage`（Task 10 會實作這個路由）

- [ ] **Step 1：寫會失敗的測試** `test/firmware_card_parts_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';

const _device = BlePairedDevice(remoteId: 'M', name: 'SilverSole', deviceId: '1A2B3C4D5E6F7081');

void main() {
  test('the card names the sole by its ID suffix, then its version', () {
    const check = FirmwareCheck(
      FirmwareCheckStatus.upToDate,
      sole: ConnectedSole(device: _device, firmwareVersion: '0.4.0', dfuSupported: true),
    );
    expect(firmwareCardDetail(check), 'SilverSole ••••7081 · v0.4.0');
  });

  test('a sole without an ID is named alone', () {
    expect(
      soleLabel(const BlePairedDevice(remoteId: 'M', name: '左腳')),
      '左腳',
    );
  });

  test('nothing to describe without a sole', () {
    expect(firmwareCardDetail(null), isNull);
    expect(firmwareCardDetail(const FirmwareCheck(FirmwareCheckStatus.notConnected)), isNull);
  });

  test('each check maps to one card action', () {
    FirmwareCardAction of(FirmwareCheckStatus s) => firmwareCardAction(FirmwareCheck(s));
    expect(of(FirmwareCheckStatus.notConnected), FirmwareCardAction.none);
    expect(of(FirmwareCheckStatus.upToDate), FirmwareCardAction.upToDate);
    expect(of(FirmwareCheckStatus.updateAvailable), FirmwareCardAction.update);
    expect(of(FirmwareCheckStatus.downgradeAvailable), FirmwareCardAction.downgrade);
    expect(of(FirmwareCheckStatus.needsWiredUpdate), FirmwareCardAction.needsWiredUpdate);
    expect(of(FirmwareCheckStatus.versionUnreadable), FirmwareCardAction.versionUnreadable);
    expect(of(FirmwareCheckStatus.checkFailed), FirmwareCardAction.retry);
    expect(of(FirmwareCheckStatus.manifestUnsupported), FirmwareCardAction.appTooOld);
  });
}
```

- [ ] **Step 2：執行，確認失敗**

執行：`flutter test test/firmware_card_parts_test.dart`
預期：編譯失敗，原因是找不到 `firmware_card_parts.dart`。

- [ ] **Step 3：實作** `lib/shared/widgets/firmware_card_parts.dart`

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

// What both themes' firmware cards share. Each theme only draws it.

enum FirmwareCardAction {
  none,
  upToDate,
  update,
  downgrade,
  needsWiredUpdate,
  versionUnreadable,
  retry,
  appTooOld,
}

FirmwareCardAction firmwareCardAction(FirmwareCheck check) =>
    switch (check.status) {
      FirmwareCheckStatus.notConnected => FirmwareCardAction.none,
      FirmwareCheckStatus.upToDate => FirmwareCardAction.upToDate,
      FirmwareCheckStatus.updateAvailable => FirmwareCardAction.update,
      FirmwareCheckStatus.downgradeAvailable => FirmwareCardAction.downgrade,
      FirmwareCheckStatus.needsWiredUpdate =>
        FirmwareCardAction.needsWiredUpdate,
      FirmwareCheckStatus.versionUnreadable =>
        FirmwareCardAction.versionUnreadable,
      FirmwareCheckStatus.checkFailed => FirmwareCardAction.retry,
      FirmwareCheckStatus.manifestUnsupported => FirmwareCardAction.appTooOld,
    };

/// The sole's name plus its ID suffix — every sole is called "SilverSole".
String soleLabel(BlePairedDevice device) {
  final shortId = device.shortId;
  return shortId == null ? device.name : '${device.name} ••••$shortId';
}

/// `SilverSole ••••7081 · v0.4.0`, or null with no sole connected.
String? firmwareCardDetail(FirmwareCheck? check) {
  final sole = check?.sole;
  if (sole == null) return null;
  final version = sole.firmwareVersion;
  final label = soleLabel(sole.device);
  return version == null ? label : '$label · v$version';
}

void openFirmwareUpdate(BuildContext context, FirmwareCheck check) {
  final manifest = check.manifest;
  if (manifest == null) return;
  context.push('/firmware-update', extra: manifest);
}

/// The sole does not refuse older firmware, so a downgrade (developer mode
/// only) asks first.
Future<void> confirmDowngrade(BuildContext context, FirmwareCheck check) async {
  final manifest = check.manifest;
  if (manifest == null) return;
  await showConfirmLeaveDialog(
    context,
    title: 'firmware_downgrade_title'.tr(),
    text: 'firmware_downgrade_content'.tr(
      args: [manifest.version, check.sole?.firmwareVersion ?? '-'],
    ),
    confirmText: 'firmware_downgrade_to'.tr(args: [manifest.version]),
    confirmType: ConfirmType.delete,
    onConfirm: () {
      if (context.mounted) context.push('/firmware-update', extra: manifest);
    },
  );
}

/// Debug builds only: installs a developer's own signed image, bypassing the
/// server. Release builds compile this out — kDebugMode is a constant and the
/// only button that calls it sits behind it too.
Future<void> pickLocalFirmware(BuildContext context, WidgetRef ref) async {
  if (!kDebugMode) return;
  final bin = await _pickBytes('firmware_pick_bin'.tr());
  if (bin == null) return;
  final signature = await _pickBytes('firmware_pick_sig'.tr());
  if (signature == null) return;
  switch (ref.read(firmwareReleaseServiceProvider).localImage(bin, signature)) {
    case Error(:final error):
      showErrorSnakeBar('firmware_local_invalid'.tr(args: ['$error']));
    case Ok(:final value):
      if (context.mounted) context.push('/firmware-update', extra: value);
  }
}

Future<Uint8List?> _pickBytes(String title) async {
  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: title,
    withData: true,
  );
  return picked?.files.single.bytes;
}

/// Seven quick taps toggle the hidden developer mode: the beta firmware
/// channel and warned downgrades (the firmware handoff's §6.2).
class DevModeTapTarget extends ConsumerStatefulWidget {
  const DevModeTapTarget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DevModeTapTarget> createState() => _DevModeTapTargetState();
}

class _DevModeTapTargetState extends ConsumerState<DevModeTapTarget> {
  static const _taps = 7;
  static const _window = Duration(seconds: 3);

  var _count = 0;
  DateTime? _first;

  void _onTap() {
    final now = DateTime.now();
    final first = _first;
    if (first == null || now.difference(first) > _window) {
      _first = now;
      _count = 0;
    }
    if (++_count < _taps) return;
    _count = 0;
    _first = null;
    final on = !ref.read(settingsProvider).firmwareDevMode;
    unawaited(ref.read(settingsProvider.notifier).setFirmwareDevMode(on));
    showMessage((on ? 'firmware_dev_mode_on' : 'firmware_dev_mode_off').tr());
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _onTap,
    child: widget.child,
  );
}
```

- [ ] **Step 4：執行，確認通過**

執行：`flutter test test/firmware_card_parts_test.dart`
預期：全部 PASS。

- [ ] **Step 5：classic 主題的卡片：把 `lib/shared/pages/devices_page.dart` 整個 `_FirmwareCard` class 換成**

```dart
class _FirmwareCard extends ConsumerWidget {
  const _FirmwareCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(firmwareCheckProvider);
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );
    final value = check.value;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    DevModeTapTarget(
                      child: Row(
                        spacing: AppSpacing.sm,
                        children: [
                          Text(
                            'firmware_version'.tr(),
                            style: context.textTheme.titleMedium,
                          ),
                          if (devMode)
                            Text(
                              'firmware_beta'.tr(),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: context.colorScheme.tertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      firmwareCardDetail(value) ??
                          'firmware_not_connected'.tr(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (check.isLoading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (value != null)
                _FirmwareStatus(check: value),
            ],
          ),
          if (kDebugMode && (value?.sole?.dfuSupported ?? false))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => pickLocalFirmware(context, ref),
                icon: const Icon(Icons.upload_file),
                label: Text('firmware_update_from_file'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FirmwareStatus extends ConsumerWidget {
  const _FirmwareStatus({required this.check});

  final FirmwareCheck check;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget flag(IconData icon, Color color, String label) => Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
    final version = check.manifest?.version ?? '';
    return switch (firmwareCardAction(check)) {
      FirmwareCardAction.none => const SizedBox.shrink(),
      FirmwareCardAction.upToDate => flag(
        LucideIcons.check,
        context.tokens.success,
        'firmware_up_to_date'.tr(),
      ),
      FirmwareCardAction.update => FilledButton(
        onPressed: () => openFirmwareUpdate(context, check),
        child: Text('firmware_update_to'.tr(args: [version])),
      ),
      FirmwareCardAction.downgrade => OutlinedButton(
        onPressed: () => confirmDowngrade(context, check),
        child: Text('firmware_downgrade_to'.tr(args: [version])),
      ),
      FirmwareCardAction.needsWiredUpdate => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_needs_wired_update'.tr(),
      ),
      FirmwareCardAction.versionUnreadable => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_version_unreadable'.tr(),
      ),
      FirmwareCardAction.appTooOld => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_manifest_unsupported'.tr(),
      ),
      FirmwareCardAction.retry => TextButton(
        onPressed: () => ref.invalidate(firmwareCheckProvider),
        child: Text('firmware_check_failed'.tr()),
      ),
    };
  }
}
```

`devices_page.dart` 的 imports 加上：

```dart
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';
```

（`flutter/foundation.dart` 本來就有 import，`kDebugMode` 從那裡來。）`DevicesPage` 的 doc comment 要修改：

```dart
/// The paired rows and their battery levels are real; the firmware block is
/// [MockFirmware] — the sole does not report a version yet.
```

改成：

```dart
/// The paired rows and their battery levels are real, and the firmware block
/// shows the connected sole's version and offers updates
/// ([firmwareCheckProvider]).
```

- [ ] **Step 6：mascot 主題的卡片：把 `lib/shared/pages/theme_two/devices_page_t2.dart` 整個 `_FirmwareCard` class 換成**

```dart
class _FirmwareCard extends ConsumerWidget {
  const _FirmwareCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(firmwareCheckProvider);
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );
    final value = check.value;
    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    DevModeTapTarget(
                      child: Row(
                        spacing: 6,
                        children: [
                          Text(
                            'firmware_version'.tr(),
                            style: context.textTheme.titleMedium,
                          ),
                          if (devMode)
                            Text(
                              'firmware_beta'.tr(),
                              style: context.textTheme.labelLarge?.copyWith(
                                color: AppPaletteT2.flame,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      firmwareCardDetail(value) ??
                          'firmware_not_connected'.tr(),
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (check.isLoading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (value != null)
                _FirmwareStatus(check: value),
            ],
          ),
          if (kDebugMode && (value?.sole?.dfuSupported ?? false))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => pickLocalFirmware(context, ref),
                icon: const Icon(Icons.upload_file),
                label: Text('firmware_update_from_file'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FirmwareStatus extends ConsumerWidget {
  const _FirmwareStatus({required this.check});

  final FirmwareCheck check;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget pill(Color fill, Color ink, String label) => MascotPill(
      color: fill,
      child: Text(
        label,
        style: context.textTheme.labelLarge?.copyWith(color: ink),
      ),
    );
    Widget alert(String label) =>
        pill(AppPaletteT2.cardWarm, AppPaletteT2.danger, label);
    final version = check.manifest?.version ?? '';
    return switch (firmwareCardAction(check)) {
      FirmwareCardAction.none => const SizedBox.shrink(),
      FirmwareCardAction.upToDate => pill(
        AppPaletteT2.safeSoft,
        AppPaletteT2.safe,
        'firmware_up_to_date'.tr(),
      ),
      FirmwareCardAction.update => FilledButton(
        onPressed: () => openFirmwareUpdate(context, check),
        child: Text('firmware_update_to'.tr(args: [version])),
      ),
      FirmwareCardAction.downgrade => OutlinedButton(
        onPressed: () => confirmDowngrade(context, check),
        child: Text('firmware_downgrade_to'.tr(args: [version])),
      ),
      FirmwareCardAction.needsWiredUpdate => alert(
        'firmware_needs_wired_update'.tr(),
      ),
      FirmwareCardAction.versionUnreadable => alert(
        'firmware_version_unreadable'.tr(),
      ),
      FirmwareCardAction.appTooOld => alert(
        'firmware_manifest_unsupported'.tr(),
      ),
      FirmwareCardAction.retry => TextButton(
        onPressed: () => ref.invalidate(firmwareCheckProvider),
        child: Text('firmware_check_failed'.tr()),
      ),
    };
  }
}
```

`devices_page_t2.dart` 的 imports 加上：

```dart
import 'package:flutter/foundation.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';
```

`DevicesPageT2` 的 doc comment 裡「The firmware block is [MockFirmware] — the sole does not report a version yet.」這兩行改成：「The firmware block shows the connected sole's version and offers updates ([firmwareCheckProvider]).」

- [ ] **Step 7：刪除 `MockFirmware`**

刪除 `lib/shared/models/device_view_data.dart` 開頭的 `MockFirmware` 整段（從 `/// Firmware facts the devices panel shows but the app cannot read yet` 開始，到 `abstract final class MockFirmware { ... }` 的結尾 `}` 為止）。

執行：`grep -rn "MockFirmware" lib test`
預期：沒有任何結果。

- [ ] **Step 8：字串。先刪掉已經用不到的 `firmware_detail` 那一行，再在 `assets/translations/strings.csv` 檔尾加入：**

```csv
firmware_not_connected,Connect an insole to see its firmware,連上鞋墊後顯示韌體版本
firmware_beta,beta,beta
firmware_update_to,Update to v{},更新到 v{}
firmware_downgrade_to,Install v{},安裝 v{}
firmware_needs_wired_update,Needs a wired update,需要接線更新
firmware_version_unreadable,Unknown version,版本無法辨識
firmware_check_failed,Check again,重新檢查
firmware_manifest_unsupported,Update the app first,請先更新 App
firmware_update_from_file,Update from file,從檔案更新
firmware_pick_bin,Choose fw.bin,選擇 fw.bin
firmware_pick_sig,Choose fw.bin.sig,選擇 fw.bin.sig
firmware_local_invalid,These files cannot be installed: {},這些檔案無法安裝：{}
firmware_dev_mode_on,Developer mode on: beta firmware,開發者模式已開啟：beta 韌體
firmware_dev_mode_off,Developer mode off,開發者模式已關閉
firmware_downgrade_title,Install older firmware?,要安裝較舊的韌體嗎？
firmware_downgrade_content,v{} is older than v{} on the insole. Only do this for testing.,v{} 比鞋墊目前的 v{} 舊。只在測試時這樣做。
```

執行：`grep -n "firmware_detail" -r lib assets`
預期：沒有任何結果。

- [ ] **Step 9：驗證**

執行：`flutter analyze lib test`，預期 `No issues found!`
執行：`flutter test`，預期 `All tests passed!`

- [ ] **Step 10：Commit**（先檢查 `git diff assets/translations/strings.csv`，確認沒有別人的 hunk）

```bash
git add lib/shared/widgets/firmware_card_parts.dart lib/shared/pages/devices_page.dart lib/shared/pages/theme_two/devices_page_t2.dart lib/shared/models/device_view_data.dart assets/translations/strings.csv test/firmware_card_parts_test.dart
git commit -m "feat(ota): show the sole's real firmware and offer updates on the devices page"
```

---

### Task 10：`/firmware-update` 頁面與路由

**Files:**
- Create: `lib/shared/pages/firmware_update_page.dart`
- Modify: `lib/core/routing/router.dart`
- Modify: `assets/translations/strings.csv`

**Interfaces:**
- Consumes：Task 8 的 `firmwareUpdateProvider`、`OtaState`、`OtaPhase`、`otaBytesPerSecond`；Task 1 的 `DfuFailure.messageKey` 和 `retryable`；Task 9 的 `soleLabel`；Task 6 的 `connectedSoleProvider`
- Produces：`FirmwareUpdatePage({required Object? source})`，以及路由 `/firmware-update`（`state.extra` 是 `FirmwareManifest` 或 `FirmwareImage`）

這一頁全部由狀態驅動，狀態機的行為在 Task 8 已經測過。依照 memory 的經驗，EasyLocalization 的 widget test 很容易卡住，所以這裡不寫 widget test，畫面留到 Task 12 在實機上驗收。

- [ ] **Step 1：實作** `lib/shared/pages/firmware_update_page.dart`

```dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';

/// Installs one firmware image into the connected sole: the confirmation, the
/// progress and the outcome. Shared by both themes — stock Material widgets,
/// styled by whichever theme is on.
class FirmwareUpdatePage extends ConsumerStatefulWidget {
  const FirmwareUpdatePage({super.key, required this.source});

  /// A [FirmwareManifest] from the server, or — debug builds only — a
  /// [FirmwareImage] a developer picked.
  final Object? source;

  @override
  ConsumerState<FirmwareUpdatePage> createState() =>
      _FirmwareUpdatePageState();
}

class _FirmwareUpdatePageState extends ConsumerState<FirmwareUpdatePage> {
  @override
  void initState() {
    super.initState();
    // Open on the confirmation, not on the last update's outcome. Deferred: a
    // provider may not change while the tree is building.
    Future.microtask(() => ref.read(firmwareUpdateProvider.notifier).reset());
  }

  void _start() {
    final ota = ref.read(firmwareUpdateProvider.notifier);
    switch (widget.source) {
      case final FirmwareManifest manifest:
        unawaited(ota.installRelease(manifest));
      case final FirmwareImage image:
        unawaited(ota.installLocal(image));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ota = ref.watch(firmwareUpdateProvider);
    final notifier = ref.read(firmwareUpdateProvider.notifier);
    final cancellable =
        ota.phase == OtaPhase.downloading ||
        ota.phase == OtaPhase.transferring;
    return PopScope(
      // Leaving would not hurt the sole, but would hide how the update ended:
      // cancel is the way out while it runs.
      canPop: !ota.busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !ota.busy,
          title: Text('ota_title'.tr(), style: context.textTheme.titleLarge),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: switch (ota.phase) {
              OtaPhase.idle => _Confirm(
                source: widget.source,
                sole: ref.watch(connectedSoleProvider),
                onStart: _start,
              ),
              OtaPhase.downloading ||
              OtaPhase.transferring ||
              OtaPhase.verifying ||
              OtaPhase.rebooting => _Progress(
                state: ota,
                onCancel: cancellable
                    ? () => unawaited(notifier.cancel())
                    : null,
              ),
              _ => _Outcome(
                state: ota,
                onRetry: notifier.reset,
                onDone: () => context.pop(),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.source,
    required this.sole,
    required this.onStart,
  });

  final Object? source;
  final ConnectedSole? sole;
  final VoidCallback onStart;

  static const _tips = [
    'ota_tip_foreground',
    'ota_tip_nearby',
    'ota_tip_paused',
    'ota_tip_safe',
  ];

  @override
  Widget build(BuildContext context) {
    final (String? target, String notes, int size) = switch (source) {
      final FirmwareManifest m => ('v${m.version}', m.notes, m.size),
      final FirmwareImage i => ('ota_local_file'.tr(), '', i.bin.length),
      _ => (null, '', 0),
    };
    if (target == null) return Text('ota_nothing_to_install'.tr());
    final sole = this.sole;
    final installed = sole?.firmwareVersion;
    final seconds = (size / otaBytesPerSecond).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Text(
              'ota_version_change'.tr(
                args: [installed == null ? '-' : 'v$installed', target],
              ),
              style: context.textTheme.titleLarge,
            ),
            if (sole != null)
              Text(
                soleLabel(sole.device),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              'ota_estimate'.tr(args: ['$seconds', '${(size / 1024).ceil()}']),
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
        if (notes.isNotEmpty)
          _Panel(
            children: [
              Text('ota_notes'.tr(), style: context.textTheme.titleMedium),
              Text(notes, style: context.textTheme.bodyMedium),
            ],
          ),
        _Panel(
          children: [
            Text(
              'ota_before_you_start'.tr(),
              style: context.textTheme.titleMedium,
            ),
            for (final tip in _tips)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Icon(
                    Icons.check,
                    size: 18,
                    color: context.colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(tip.tr(), style: context.textTheme.bodyMedium),
                  ),
                ],
              ),
          ],
        ),
        FilledButton(
          onPressed: sole == null ? null : onStart,
          child: Text('ota_start'.tr()),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.onCancel});

  final OtaState state;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.phase) {
      OtaPhase.downloading => 'ota_downloading'.tr(),
      OtaPhase.transferring => 'ota_transferring'.tr(
        args: ['${state.committed ~/ 1024}', '${state.size ~/ 1024}'],
      ),
      OtaPhase.verifying => 'ota_verifying'.tr(),
      _ => 'ota_rebooting'.tr(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Text(label, style: context.textTheme.titleMedium),
            LinearProgressIndicator(
              value: state.phase == OtaPhase.transferring
                  ? state.progress
                  : null,
            ),
            Text(
              'ota_keep_close'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (onCancel != null)
          OutlinedButton(onPressed: onCancel, child: Text('cancel'.tr())),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.state,
    required this.onRetry,
    required this.onDone,
  });

  final OtaState state;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  static String _v(String? version) => version == null ? '-' : 'v$version';

  @override
  Widget build(BuildContext context) {
    final installed =
        state.phase == OtaPhase.succeeded ||
        state.phase == OtaPhase.localFinished;
    final (IconData icon, Color color, String title) = switch (state.phase) {
      OtaPhase.succeeded => (
        Icons.check_circle_outline,
        context.tokens.success,
        'ota_succeeded'.tr(args: [_v(state.readVersion)]),
      ),
      OtaPhase.localFinished => (
        Icons.check_circle_outline,
        context.tokens.success,
        'ota_local_finished'.tr(
          args: [_v(state.fromVersion), _v(state.readVersion)],
        ),
      ),
      OtaPhase.notUpdated => (
        Icons.error_outline,
        context.tokens.alert,
        'ota_not_updated'.tr(),
      ),
      OtaPhase.unconfirmed => (
        Icons.help_outline,
        context.colorScheme.onSurfaceVariant,
        'ota_unconfirmed'.tr(),
      ),
      _ => (
        Icons.cancel_outlined,
        context.colorScheme.error,
        (state.failure ?? DfuFailure.disconnected).messageKey.tr(),
      ),
    };
    final canRetry = switch (state.phase) {
      OtaPhase.notUpdated => true,
      OtaPhase.failed => state.failure?.retryable ?? true,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Panel(
          children: [
            Icon(icon, size: 48, color: color),
            Text(title, style: context.textTheme.titleLarge),
            if (installed && state.probable)
              Text(
                'ota_probable_note'.tr(),
                style: context.textTheme.bodyMedium,
              ),
            // Every way an update can end short of success leaves the sole on
            // its old firmware, working (the firmware guarantees it).
            if (!installed)
              Text(
                'ota_sole_still_works'.tr(),
                style: context.textTheme.bodyMedium,
              ),
          ],
        ),
        if (canRetry)
          FilledButton(onPressed: onRetry, child: Text('ota_retry'.tr())),
        OutlinedButton(onPressed: onDone, child: Text('ota_done'.tr())),
      ],
    );
  }
}

/// One card section; the theme styles it in both designs.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: children,
      ),
    ),
  );
}
```

- [ ] **Step 2：路由。在 `lib/core/routing/router.dart` 的 `/my-devices` 那一條之後加入：**

```dart
      GoRoute(
        path: '/firmware-update',
        builder: (_, state) => FirmwareUpdatePage(source: state.extra),
      ),
```

並加上 import `import 'package:silversole/shared/pages/firmware_update_page.dart';`。

- [ ] **Step 3：字串，加在 `assets/translations/strings.csv` 檔尾**

```csv
ota_title,Firmware update,韌體更新
ota_version_change,{} → {},{} → {}
ota_estimate,About {} s · {} KB,約 {} 秒 · {} KB
ota_notes,What's new,更新內容
ota_before_you_start,Before you start,開始前請注意
ota_tip_foreground,Keep the app open on screen until it finishes.,更新完成前請讓 App 保持在畫面上。
ota_tip_nearby,Keep the phone close to the insole.,手機請靠近鞋墊。
ota_tip_paused,Live data pauses during the update.,更新期間即時資料會暫停。
ota_tip_safe,If it is interrupted the insole keeps its current firmware and keeps working.,如果中途中斷，鞋墊會保留目前的韌體並正常運作。
ota_start,Start update,開始更新
ota_local_file,local file,本機檔案
ota_nothing_to_install,Nothing to install.,沒有可安裝的韌體。
ota_downloading,Downloading firmware…,正在下載韌體…
ota_transferring,Sending to the insole · {} / {} KB,正在傳送到鞋墊 · {} / {} KB
ota_verifying,The insole is checking the firmware…,鞋墊正在驗證韌體…
ota_rebooting,The insole is restarting on the new firmware. This can take up to 90 s.,鞋墊正在重新開機換版，最多約 90 秒。
ota_keep_close,Keep the app open and the phone close to the insole.,請讓 App 保持開啟，手機靠近鞋墊。
ota_succeeded,Updated to {},已更新到 {}
ota_local_finished,{} → {} after the update,更新前 {} → 更新後 {}
ota_not_updated,The update did not finish.,更新未完成。
ota_unconfirmed,Could not confirm the update. Check the version on the devices page later.,無法確認更新結果，請稍後到裝置頁查看版本。
ota_probable_note,This insole was identified by elimination. Check its ID on the devices page.,這隻鞋墊是推測出來的，請到裝置頁核對它的 ID。
ota_sole_still_works,Your insole still works as before.,鞋墊仍可正常使用。
ota_retry,Try again,重試
ota_done,Done,完成
ota_fail_not_connected,No insole is connected.,目前沒有連線的鞋墊。
ota_fail_disconnected,The connection was lost. Move closer and keep the app open.,連線中斷了。請靠近鞋墊並保持 App 開啟後再試。
ota_fail_timeout,The insole stopped answering.,鞋墊沒有回應。
ota_fail_too_many_retries,The connection is too weak. Move closer and try again.,連線品質太差，請靠近鞋墊再試。
ota_fail_cancelled,The update was cancelled.,已取消更新。
ota_fail_dfu_unsupported,This insole's firmware is too old to update over Bluetooth. Please contact support.,這隻鞋墊的韌體太舊，無法無線更新，請聯絡客服。
ota_fail_unsupported_version,This insole needs a wired update. Please contact support.,這隻鞋墊需要接線更新，請聯絡客服。
ota_fail_mtu_too_small,This phone could not set up a fast enough Bluetooth link.,這支手機無法建立足夠的藍牙傳輸速度。
ota_fail_low_battery,The insole battery is below 30%. Charge it and try again.,鞋墊電量低於 30%，請充電後再試。
ota_fail_battery_unknown,The insole just started. Try again in a moment.,鞋墊剛開機，請稍後再試。
ota_fail_bad_state,The insole was just updated. Try again in 30 seconds.,鞋墊剛更新過，請 30 秒後再試。
ota_fail_hash_mismatch,The firmware was damaged on the way twice.,韌體在傳送過程中連續兩次損壞。
ota_fail_flash_error,The insole could not store the firmware.,鞋墊無法寫入韌體。
ota_fail_bad_signature,The insole rejected this firmware's signature. Please report this.,鞋墊拒絕了這個韌體的簽章，請回報這個問題。
ota_fail_too_large,This firmware is too large for the insole. Please report this.,這個韌體超過鞋墊的容量，請回報這個問題。
ota_fail_bad_command,The app sent a command the insole did not understand. Please report this.,App 送出了鞋墊看不懂的指令，請回報這個問題。
ota_fail_manifest_unavailable,Could not check for firmware. Check the internet connection.,無法取得韌體資訊，請確認網路連線。
ota_fail_download_failed,The download failed. Check the internet connection.,下載失敗，請確認網路連線。
ota_fail_image_invalid,The downloaded firmware failed its check and was not sent.,下載的韌體沒有通過檢查，沒有送進鞋墊。
```

接著確認 `DfuFailure` 的每個成員都有對應的字串：

```bash
for f in not_connected disconnected timeout too_many_retries cancelled dfu_unsupported unsupported_version mtu_too_small low_battery battery_unknown bad_state hash_mismatch flash_error bad_signature too_large bad_command manifest_unavailable download_failed image_invalid; do grep -q "^ota_fail_$f," assets/translations/strings.csv || echo "missing ota_fail_$f"; done
```

預期：沒有任何輸出。

- [ ] **Step 4：驗證**

執行：`flutter analyze lib test`，預期 `No issues found!`
執行：`flutter test`，預期 `All tests passed!`

- [ ] **Step 5：Commit**（先檢查 `git diff assets/translations/strings.csv`）

```bash
git add lib/shared/pages/firmware_update_page.dart lib/core/routing/router.dart assets/translations/strings.csv
git commit -m "feat(ota): add the firmware update page"
```

---

### Task 11：文件與整體驗證

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1：更新 CLAUDE.md**
  - 在 BLE pipeline 段落裡，把握手順序那句的 `requestMtu (kept here so MTU and setup live in one place)` 改成 `requestMtu(247 — the firmware's att_mtu; OTA needs ≥ 68; kept here so MTU and setup live in one place)`。
  - 在「6. **Fall detection**」那一項之後加入第 7 項：

```markdown
7. **Firmware OTA** — design: `docs/superpowers/specs/2026-10-11-firmware-ota-design.md`; protocol: the firmware repo's `docs/ota-ble-protocol.md` (v2). Pure parts live in `lib/core/ble/ota/` (codec, `DfuTransfer` — one 4096-byte page per STATUS, a 2 s wait per page because a lost last packet produces no BAD_OFFSET, never a long write) and are tested against `test/helpers/fake_dfu_sole.dart`. The handshake reads the DFU `version` into `connectedSoleProvider`; `firmwareCheckProvider` compares it (semver) with `firmware/channels/{stable|beta}/manifest.json` in the public Supabase bucket (no SELECT policy on purpose; manifests uploaded with `cacheControl: 60`). `firmwareUpdateProvider` runs the update: `SoleConnectionController.hold()` stops auto-connect from swapping soles mid-transfer, and `reacquire()` finds the rebooted sole again by its advertised chip ID. While an update runs, `deviceOnlineProvider` reports online even though the 50 Hz stream pauses. Developer mode (7 taps on the firmware title) reads the beta channel and allows warned downgrades; updating from a local file exists only under `kDebugMode`.
```

- [ ] **Step 2：完整驗證**

執行：`flutter analyze lib test`，預期 `No issues found!`
執行：`flutter test`，預期 `All tests passed!`
執行：`flutter build apk --debug`，預期 `✓ Built build/app/outputs/flutter-apk/app-debug.apk`。
- 如果是本機 Flutter 版本（3.35.1）跟 CI 指定的版本（3.47.6）、Gradle 或 AGP 不相容造成的錯誤，不要修改 Android 建置設定。記錄錯誤訊息，改由 CI 驗證，並回報給使用者。
- 如果錯誤來自 `wakelock_plus` 的 Android 需求，例如 minSdk，就照錯誤訊息處理，並回報給使用者。

- [ ] **Step 3：Commit**（先看 `git diff CLAUDE.md`；如果有別的 session 的 hunk，用「HEAD 版本 + 只套用自己修改」的方式 commit，之後把工作目錄還原回原本的狀態）

```bash
git add CLAUDE.md
git commit -m "docs: describe the firmware OTA flow"
```

---

### Task 12：伺服器準備與實機驗收（每一步都要先問使用者）

這個任務會寫入正式的 Supabase 後端，也需要真的鞋墊和已簽章的韌體檔。**每一步動手前都要先取得使用者同意。**

- [ ] **Step 1：建立 bucket（MCP，需要使用者同意）**
  1. 用 Supabase MCP 的 `list_projects` 找出 URL 跟 `.env` 裡 `PUBLIC_SUPABASE_URL` 相同的專案。不要把金鑰印出來。
  2. 用 `execute_sql` 執行，執行前先把 SQL 拿給使用者確認：

```sql
insert into storage.buckets (id, name, public)
values ('firmware', 'firmware', true)
on conflict (id) do nothing;
```

  3. 執行 `get_advisors`，確認沒有新的 storage 警告，也**沒有**對 `firmware` 加任何 `storage.objects` 的 SELECT policy。

- [ ] **Step 2：上傳測試檔（使用者提供兩個版本的 `fw.bin` 和 `fw.bin.sig`）**
  1. 用下面的指令產生 manifest：

```bash
python3 - <<'EOF' fw.bin 0.x.y-rc.1
import hashlib, json, sys, datetime, pathlib
path, version = sys.argv[1], sys.argv[2]
data = pathlib.Path(path).read_bytes()
print(json.dumps({
  "schema": 1, "channel": "beta", "version": version, "size": len(data),
  "sha256": hashlib.sha256(data).hexdigest(),
  "bin_path": f"releases/{version}/fw.bin", "sig_path": f"releases/{version}/fw.bin.sig",
  "notes": "", "published_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}, ensure_ascii=False, indent=2))
EOF
```

  2. 上傳方式二選一：
     - 使用者先執行 `! supabase login` 和 `! supabase link --project-ref <ref>`，再用 `supabase storage cp --experimental --linked` 上傳到 `ss:///firmware/releases/<version>/` 和 `ss:///firmware/channels/beta/manifest.json`。旗標以 `supabase storage cp --help` 實際顯示的為準，manifest 要設 cache-control `max-age=60`。
     - 使用者從 Supabase Dashboard 手動上傳。

- [ ] **Step 3：實機驗收（交接文件 §8，用 debug APK 測）**

逐條確認並記錄結果：
1. 有新版時正確提示；沒有新版或伺服器版本比較舊時不提示；semver 比較正確（包含 `-rc`）。
2. 完整更新成功：傳送 → APPLIED → 重新連線 → 讀到新版號 → 顯示成功。
3. Android 實測 MTU：看 log 裡的 `dfu`、`mtuNow`，確認 ≥ 68（應該是 247），而且每包 payload 都用滿 240。
4. 傳輸中途關掉藍牙：App 顯示中斷，鞋墊仍是舊版、照常運作，重試可以成功。
5. 傳輸中途按取消：鞋墊維持舊版。
6. SHA-256 不符：把 manifest 的 `sha256` 改錯一個字元，App 應該顯示「下載的韌體沒有通過檢查」，而且沒有送進鞋墊。
7. 錯誤的 `.sig`（64 bytes 亂數，用 debug 版的「從檔案更新」）：鞋墊回 BAD_SIGNATURE，App 停止、不重試。
8. 鞋墊電量 < 30%：App 事先擋下。
9. 換版後 30 秒內再更新一次：顯示「請 30 秒後再試」（BAD_STATE）。
10. 掉包恢復：把 `DfuTransfer.packetGap` 暫時調成 0 來製造掉包，log 裡應該看得到 resend，最後仍然成功。測完要把這個改動還原，**不要 commit**。
11. 更新期間首頁和即時資料畫面不會 crash，裝置不會顯示離線。
12. 兩隻鞋墊同時開著時，更新其中一隻；重新連線時連回的是同一隻（ID 後 4 碼一致）。
```
