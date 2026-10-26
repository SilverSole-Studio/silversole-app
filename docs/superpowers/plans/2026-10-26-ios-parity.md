# iOS Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS build do what the Android build does today. The headline is the BLE pipeline: pair, auto-connect, live telemetry, fall detection, OTA. Next come the flows that are wrong on iOS: the APK update sheet, a Google button that always fails, and account info leaking to other sites from the plaza WebView.

**Architecture:** Flutter's Dart code is shared. Android-only behaviour hides behind `defaultTargetPlatform` checks and an Android-only `MethodChannel`. We make each of those platform-aware rather than adding iOS native code:
- iOS has no foreground service. Background BLE comes from `UIBackgroundModes: bluetooth-central` instead, and the service channel becomes a no-op off Android.
- iOS asks for one Bluetooth permission instead of Android's scan/connect/location trio.

**Tech Stack:** Flutter 3.47.6 (CI-pinned), Riverpod v3, flutter_blue_plus 2.1.1, permission_handler 12, flutter_inappwebview 6, CocoaPods.

**Spec:** No separate spec. The requirements are the iOS-vs-Android inventory summarised under "Background" below, produced by a read-only code review on 2026-10-26.

## Background (what is broken on iOS today, with evidence)

1. `lib/shared/providers/ble_foreground_controller.dart:48` returns `NoSoleConnection()` off Android. Nothing ever connects on iOS: no live IMU, fall detection, heartbeat, OTA, calibration or game input.
2. permission_handler on iOS has no case for `Permission.bluetoothScan` or `Permission.bluetoothConnect`, and returns `permanentlyDenied` for them. So the pairing sheet (`lib/shared/pages/device_connect_bottom_modal.dart:81-97`) always shows "Bluetooth scan permission is required." and never scans.
3. `lib/core/ble/ble_service_channel.dart` calls a channel that only `MainActivity.kt` handles. On iOS `startBleService()` throws `MissingPluginException`. It is awaited uncaught inside `searchAndAttach` (`ble_foreground_controller.dart:474`), which would abort every search once (1) is lifted.
4. `ios/Runner/Info.plist` has no `UIBackgroundModes`, so BLE stops when the app is backgrounded.
5. The deployment target is 13.0 (`project.pbxproj`, `ios/Flutter/AppFrameworkInfo.plist`), but the Podfile says 14.0 and GoogleMaps needs 14.0. WebView `onPermissionRequest` (game camera) only fires on iOS 15+.
6. `lib/shared/pages/home_page.dart:34-44` shows the GitHub **APK** update sheet on iOS, because "not installed from Play" is treated as sideloaded.
7. The Google sign-in button (`sign_in_page.dart:168`, `sign_up_page.dart:208`) always fails on iOS with `google_sign_in_unsupported`.
8. `allowedOriginRules` on the plaza `UserScript` (`plaza_tab_page.dart:88-93`) is Android-only. On iOS `window.silversoleApp`, which holds `accountId` and `accountEmail`, is injected into every origin the plaza WebView visits.
9. Config polish:
   - No `CFBundleLocalizations`.
   - Permission prompts are Chinese-only.
   - `NSLocationAlwaysAndWhenInUseUsageDescription` is declared but never requested.
   - iPad is a target, and `SharePlus.share` throws there without `sharePositionOrigin`.
   - `#include "Secrets.xcconfig"` is not optional, so a fresh clone cannot build.

## Out of scope (needs the user, not code)

- **Full Google sign-in on iOS.** Needs an iOS OAuth client created in the `silversole` GCP project, with its ID added to Supabase's Google provider. App Store guideline 4.8 then also requires Sign in with Apple. Task 5 only hides the button.
- **Background reconnect after a link loss while the app is suspended.** iOS will not deliver unfiltered scan results in the background. Whether the firmware advertises the main service UUID (`83BFF893-…`) has not been checked. Until a sole is tested on a real iPhone, background behaviour is whatever `bluetooth-central` gives: an already-connected sole keeps streaming.
- **In-app account deletion (guideline 5.1.1(v)).** Needed for App Store review, not for TestFlight or parity.

## Global Constraints

- Android behaviour must not change. Every new branch is keyed on `defaultTargetPlatform`, and every existing test must still pass.
- Follow `CLAUDE.md` and `AGENTS.md`:
  - service methods return `Result<T>`;
  - theme comes through `context.colorScheme` / `context.textTheme` / `context.tokens`;
  - new user-facing strings go in `assets/translations/strings.csv` with `en` and `zh-TW` columns.
- Do **not** reintroduce `autoConnect: true`, per-operation `connect()` / `discoverServices()`, or an `isConnected` polling timer (see CLAUDE.md, "BLE → telemetry pipeline").
- Toolchain: the user's local Flutter (`~/Documents/Myself_Folder/_Other/flutter`) is 3.35.1 and **cannot resolve this pubspec**. Use the Flutter 3.47.6 from Task 0. Do not upgrade or modify the user's SDK.
- Git:
  - Work on branch `ios-parity` from `main`.
  - Stage only the files a task names: never `git add -A`, `.` or `-a`, because the tree has unrelated untracked assets.
  - Commit messages are in Traditional Chinese like the history, and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - **Do not push.**
- Minimum iOS: **15.0**.

## Review Focus

1. **Android unchanged.** On Android the permission set requested, the foreground-service calls and the update flow must be byte-for-byte the same calls as before. Tasks 2 and 4 pin this with Android-platform tests.
2. **Bluetooth refused on iOS.** The pairing sheet shows the permission message and stops. The controller backs off through `scheduleSearch()`, with no tight loop and no crash. Task 2 tests that a denied `Permission.bluetooth` gives `false`.
3. **Bluetooth switched off on iOS.** `SoleScanner.scan()` already catches, so `searchAndAttach` must reach `scheduleSearch()` rather than throw. Task 3 checks that no new uncaught await is added on that path.
4. **Platforms that are neither Android nor iOS** (macOS desktop, tests): the controller stays `NoSoleConnection` and the channel stays silent. Tasks 2 and 3 test this.
5. **Plaza navigates to a non-game origin on iOS.** `window.silversoleApp` must stay undefined there. Task 6 tests that the generated script is origin-guarded.

---

### Task 0: Toolchain (no commit)

**Files:** none in the repo.

- [ ] **Step 1: Install Flutter 3.47.6 beside the user's SDK**

```bash
SCRATCH=/private/tmp/claude-501/-Users-andongni-Documents-Myself-Folder-16-Big-Project-SilverSole-silversole-app/d69cee22-57a4-4018-82c2-3e793a1c21a5/scratchpad
[ -d "$SCRATCH/flutter-3.47.6" ] || git clone --depth 1 -b 3.47.6 https://github.com/flutter/flutter.git "$SCRATCH/flutter-3.47.6"
export PATH="$SCRATCH/flutter-3.47.6/bin:$PATH"
flutter --version   # expect: Flutter 3.47.6
```

Every later command in this plan assumes this `PATH`.

- [ ] **Step 2: Baseline**

```bash
cd /Users/andongni/Documents/Myself_Folder/16_Big_Project/SilverSole/silversole-app
git checkout -b ios-parity
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
```

Expected: all tests pass. Record the pass count. If anything fails here, stop and report it: it is pre-existing, not ours.

---

### Task 1: iOS 15 deployment target, CocoaPods state, Bluetooth permission macro

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (three `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`)
- Modify: `ios/Flutter/AppFrameworkInfo.plist` (`MinimumOSVersion`)
- Modify: `ios/Podfile` (platform line and `post_install` macros)
- Modify: `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig` (`#include?` for Secrets)
- Create (generated, commit them): `ios/Podfile.lock`, plus whatever `pod install` changes in `project.pbxproj` and `ios/Runner.xcworkspace/contents.xcworkspacedata`

**Interfaces:**
- Produces: `Permission.bluetooth` is compiled in on iOS (macro `PERMISSION_BLUETOOTH=1`). Task 2 relies on it.

- [ ] **Step 1: Raise the deployment target to 15.0**

```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' ios/Runner.xcodeproj/project.pbxproj
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 15.0;" ios/Runner.xcodeproj/project.pbxproj   # expect 3
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 15.0" ios/Flutter/AppFrameworkInfo.plist
```

In `ios/Podfile` change `platform :ios, '14.0'` to `platform :ios, '15.0'`.

- [ ] **Step 2: Compile Bluetooth into permission_handler**

Replace the `post_install` block's macro array in `ios/Podfile` with:

```ruby
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1', # the H5 games' camera mode
        'PERMISSION_LOCATION_WHENINUSE=1', # Permission.locationWhenInUse (maps, main.dart)
        'PERMISSION_BLUETOOTH=1', # Permission.bluetooth (iOS BLE, ble_permissions.dart)
      ]
```

Also add, inside the same `target.build_configurations.each` loop, so pods built for an older minimum do not warn or fail:

```ruby
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0' if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
```

- [ ] **Step 3: Let a fresh clone build without Secrets.xcconfig**

In both `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`, change `#include "Secrets.xcconfig"` to `#include? "Secrets.xcconfig"`. `AppDelegate.swift` already skips `provideAPIKey` for an empty key.

- [ ] **Step 4: Build unsigned (this runs pod install)**

```bash
flutter build ios --release --no-codesign --build-name=1.11.0 --build-number=1
```

Expected: `✓ Built build/ios/iphoneos/Runner.app`. If a pod complains about a minimum version, fix it here. Do not lower the target.

- [ ] **Step 5: Commit**

```bash
git add ios/Runner.xcodeproj/project.pbxproj ios/Flutter/AppFrameworkInfo.plist ios/Podfile ios/Podfile.lock ios/Flutter/Debug.xcconfig ios/Flutter/Release.xcconfig ios/Runner.xcworkspace/contents.xcworkspacedata
git status --short ios   # nothing else under ios/ should be staged by accident; Pods/ must be ignored
git commit -m "build(ios): 最低版本升到 iOS 15、補 Podfile.lock、編入藍牙權限"
```

If `ios/Pods/` shows up untracked, check `ios/.gitignore` has `Pods/`, and add it there if not.

---

### Task 2: Platform-aware BLE permissions and a silent service channel off Android

**Files:**
- Create: `lib/core/ble/ble_permissions.dart`
- Modify: `lib/core/ble/ble_service_channel.dart`
- Modify: `lib/shared/providers/ble_foreground_controller.dart:249-274` (`ensureConnectPermission`, `ensureScanPermission`, `ensureNotificationPermission`)
- Modify: `lib/shared/pages/device_connect_bottom_modal.dart:81-97` (`ensureScanPermission`)
- Test: `test/ble_permissions_test.dart`, `test/ble_service_channel_test.dart`

**Interfaces:**
- Consumes: `Permission.bluetooth` compiled in (Task 1).
- Produces:
  - `List<Permission> bleScanPermissions(TargetPlatform platform)`
  - `List<Permission> bleConnectPermissions(TargetPlatform platform)`
  - `typedef PermissionRequester = Future<Map<Permission, PermissionStatus>> Function(List<Permission> permissions);`
  - `Future<bool> requestBleScanPermission({PermissionRequester? request})`
  - `Future<bool> requestBleConnectPermission({PermissionRequester? request})`
  - `bool get bleNeedsNotificationPermission`
  - `startBleService()`, `stopBleService()` and `updateBleNotification()` complete normally without touching the channel when `defaultTargetPlatform != TargetPlatform.android`.

- [ ] **Step 1: Write the failing tests**

`test/ble_permissions_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_permissions.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android keeps the scan/connect/location set it always asked for', () {
    expect(bleScanPermissions(TargetPlatform.android),
        [Permission.bluetoothScan, Permission.locationWhenInUse]);
    expect(bleConnectPermissions(TargetPlatform.android),
        [Permission.bluetoothConnect]);
  });

  test('iOS asks for Bluetooth alone — no location, no Android-only scan/connect', () {
    expect(bleScanPermissions(TargetPlatform.iOS), [Permission.bluetooth]);
    expect(bleConnectPermissions(TargetPlatform.iOS), [Permission.bluetooth]);
  });

  test('the verdict is the first (Bluetooth) permission, not location', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    List<Permission>? asked;
    final granted = await requestBleScanPermission(request: (ps) async {
      asked = ps;
      return {
        Permission.bluetoothScan: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.denied,
      };
    });
    expect(asked, [Permission.bluetoothScan, Permission.locationWhenInUse]);
    expect(granted, isTrue);
  });

  test('a refused Bluetooth permission on iOS is false, not a throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      await requestBleScanPermission(
          request: (_) async => {Permission.bluetooth: PermissionStatus.permanentlyDenied}),
      isFalse,
    );
    expect(
      await requestBleConnectPermission(
          request: (_) async => {Permission.bluetooth: PermissionStatus.denied}),
      isFalse,
    );
  });

  test('only Android asks for the notification permission', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(bleNeedsNotificationPermission, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(bleNeedsNotificationPermission, isFalse);
  });
}
```

`test/ble_service_channel_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.dongyutech.silversole/ble_service');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android drives the foreground service exactly as before', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await startBleService();
    await updateBleNotification(title: 't', text: 'x');
    await stopBleService();
    expect(calls, ['startBleService', 'updateNotification', 'stopBleService']);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('$platform has no foreground service: no channel call, no throw', () async {
      debugDefaultTargetPlatformOverride = platform;
      messenger.setMockMethodCallHandler(channel, null); // like the real iOS app
      await startBleService();
      await updateBleNotification(title: 't', text: 'x');
      await stopBleService();
    });
  }
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/ble_permissions_test.dart test/ble_service_channel_test.dart`
Expected:
- `ble_permissions_test` fails to compile (`ble_permissions.dart` does not exist).
- The iOS and macOS channel tests fail with `MissingPluginException`.

- [ ] **Step 3: Implement**

`lib/core/ble/ble_permissions.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests [permissions] and reports each one's status. Injectable for tests.
typedef PermissionRequester = Future<Map<Permission, PermissionStatus>>
    Function(List<Permission> permissions);

Future<Map<Permission, PermissionStatus>> _requestAll(
  List<Permission> permissions,
) => permissions.request();

/// What scanning for soles needs. The first entry decides the verdict.
///
/// Android 12+ splits Bluetooth into scan and connect, and the pairing sheet
/// has always asked for location alongside. iOS has one Bluetooth
/// permission: permission_handler answers the Android-only scan/connect
/// permissions with `permanentlyDenied` there, and CoreBluetooth needs no
/// location.
List<Permission> bleScanPermissions(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
        ? const [Permission.bluetooth]
        : const [Permission.bluetoothScan, Permission.locationWhenInUse];

/// What connecting to a sole needs. The first entry decides the verdict.
List<Permission> bleConnectPermissions(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
        ? const [Permission.bluetooth]
        : const [Permission.bluetoothConnect];

Future<bool> requestBleScanPermission({PermissionRequester? request}) =>
    _granted(bleScanPermissions(defaultTargetPlatform), request ?? _requestAll);

Future<bool> requestBleConnectPermission({PermissionRequester? request}) =>
    _granted(bleConnectPermissions(defaultTargetPlatform), request ?? _requestAll);

Future<bool> _granted(
  List<Permission> permissions,
  PermissionRequester request,
) async {
  final statuses = await request(permissions);
  return statuses[permissions.first]?.isGranted ?? false;
}

/// Only Android shows the foreground service's ongoing notification, which is
/// what the notification permission is for.
bool get bleNeedsNotificationPermission =>
    defaultTargetPlatform == TargetPlatform.android;
```

`lib/core/ble/ble_service_channel.dart` becomes:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.dongyutech.silversole/ble_service');

/// Only Android has the foreground service (MainActivity.kt). iOS keeps BLE
/// alive through the `bluetooth-central` background mode instead, so off
/// Android every call here is a no-op rather than a MissingPluginException.
bool get _hasService => defaultTargetPlatform == TargetPlatform.android;

Future<void> startBleService() async {
  if (_hasService) await _channel.invokeMethod('startBleService');
}

Future<void> stopBleService() async {
  if (_hasService) await _channel.invokeMethod('stopBleService');
}

/// Rewrites the service's ongoing notification. Safe to call while the service
/// is stopped: the text is kept for its next start.
Future<void> updateBleNotification({
  required String title,
  required String text,
}) async {
  if (_hasService) {
    await _channel.invokeMethod('updateNotification', {
      'title': title,
      'text': text,
    });
  }
}
```

In `ble_foreground_controller.dart`, replace the three permission functions with the versions below, add `import 'package:silversole/core/ble/ble_permissions.dart';`, and drop the `permission_handler` import if nothing else uses it:

```dart
  Future<bool> ensureConnectPermission() => requestBleConnectPermission();

  /// Mirrors the pairing sheet's request. This only ever runs once the user has
  /// paired a sole by hand, so the prompts have already been seen by then.
  Future<bool> ensureScanPermission() => requestBleScanPermission();

  // (keep the existing comment block above notificationAsked)
  var notificationAsked = false;
  Future<void> ensureNotificationPermission() async {
    if (notificationAsked || !bleNeedsNotificationPermission) return;
    notificationAsked = true;
    await Permission.notification.request();
  }
```

(Keep the `permission_handler` import if `Permission.notification` stays here.)

In `device_connect_bottom_modal.dart`, replace the body of `ensureScanPermission`:

```dart
  Future<bool> ensureScanPermission() async {
    try {
      if (await requestBleScanPermission()) return true;
      showErrorSnakeBar('Bluetooth scan permission is required.');
      return false;
    } on MissingPluginException {
      // Desktop (macOS) has no permission_handler implementation; CoreBluetooth
      // prompts for Bluetooth on the first scan, so just proceed.
      return true;
    }
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ble_permissions_test.dart test/ble_service_channel_test.dart && flutter test`
Expected: all pass, with the Task 0 count + 8.

- [ ] **Step 5: Commit**

```bash
git add lib/core/ble/ble_permissions.dart lib/core/ble/ble_service_channel.dart lib/shared/providers/ble_foreground_controller.dart lib/shared/pages/device_connect_bottom_modal.dart test/ble_permissions_test.dart test/ble_service_channel_test.dart
git commit -m "feat(ble): iOS 改要藍牙權限、前景服務 channel 在 Android 以外不呼叫"
```

---

### Task 3: Run the connection controller on iOS, with background BLE

**Files:**
- Modify: `lib/shared/providers/ble_foreground_controller.dart:46-50`
- Modify: `lib/core/ble/sole_scanner.dart` (`watch()`'s `startScan` call)
- Modify: `lib/core/ble/ble_connection_service.dart:313-316` (comment only)
- Modify: `ios/Runner/Info.plist` (`UIBackgroundModes`)
- Test: `test/ble_foreground_platform_test.dart`

**Interfaces:**
- Consumes: Task 2's no-op channel and permissions. Without them, lifting this gate aborts every search on iOS.
- Produces: `bool bleOrchestrationSupported(TargetPlatform platform)`, exported from `ble_foreground_controller.dart`.

- [ ] **Step 1: Write the failing test**

`test/ble_foreground_platform_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';

void main() {
  test('BLE runs on both phones and nowhere else', () {
    expect(bleOrchestrationSupported(TargetPlatform.android), isTrue);
    expect(bleOrchestrationSupported(TargetPlatform.iOS), isTrue);
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(bleOrchestrationSupported(p), isFalse, reason: '$p');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ble_foreground_platform_test.dart`
Expected: compile error, `bleOrchestrationSupported` is not defined.

- [ ] **Step 3: Implement**

In `ble_foreground_controller.dart`, above the provider:

```dart
/// Where the scan-driven connection orchestration runs. Both phones: Android
/// keeps it alive with its foreground service, iOS with the
/// `bluetooth-central` background mode (Info.plist). Desktop and tests get
/// [NoSoleConnection].
bool bleOrchestrationSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;
```

and change the gate to:

```dart
  if (!bleOrchestrationSupported(defaultTargetPlatform)) {
    return const NoSoleConnection();
  }
```

Then read `searchAndAttach` from top to bottom and confirm that on iOS **no** awaited call between the permission check and `scanner.scan()` can throw uncaught:
- `startBleService` is a no-op now;
- `ensureNotificationPermission` returns early;
- `scanner.scan()` catches internally.

Do not add try/catch unless you find a real uncaught throw. If you do find one, report it.

In `sole_scanner.dart` `watch()`, change the `startScan` call to:

```dart
        await FlutterBluePlus.startScan(
          androidScanMode: AndroidScanMode.lowLatency,
          timeout: timeout,
          // iOS reports a peripheral once per scan unless asked for every
          // advertisement; the rebooted sole must be seen after `since`.
          continuousUpdates: true,
        );
```

(Android already reports every advertisement in `lowLatency` mode, so this is a no-op there. fbp 2.1.1 accepts `continuousUpdates`.)

In `ble_connection_service.dart` around line 314, fix the comment over the `defaultTargetPlatform == TargetPlatform.android` MTU check so it gives the real reason: "fbp's requestMtu is Android-only; iOS negotiates the MTU itself and `mtuNow` reports it (maximumWriteValueLength + 3)." Do not change the code.

In `ios/Runner/Info.plist`, add before `</dict>`:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>bluetooth-central</string>
	</array>
```

Run `plutil -lint ios/Runner/Info.plist`. Expected: `OK`.

- [ ] **Step 4: Run the tests and build**

```bash
flutter test
flutter build ios --release --no-codesign --build-name=1.11.0 --build-number=1
```

Expected: all pass, and the build succeeds.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/providers/ble_foreground_controller.dart lib/core/ble/sole_scanner.dart lib/core/ble/ble_connection_service.dart ios/Runner/Info.plist test/ble_foreground_platform_test.dart
git commit -m "feat(ble): iOS 也跑自動連線（背景藍牙 bluetooth-central）"
```

---

### Task 4: The GitHub APK update sheet is Android-only

**Files:**
- Modify: `lib/core/utils/play_in_app_update.dart` (add a pure helper)
- Modify: `lib/shared/pages/home_page.dart:34-44`
- Test: `test/play_in_app_update_test.dart` (append)

**Interfaces:**
- Produces: `enum UpdateRoute { play, github, none }` and `UpdateRoute updateRoute(TargetPlatform platform, {required bool installedFromPlay})` in `play_in_app_update.dart`.

- [ ] **Step 1: Write the failing test**

Append to `test/play_in_app_update_test.dart`, inside `main()`:

```dart
  test('only a sideloaded Android copy gets the GitHub APK prompt', () {
    expect(updateRoute(TargetPlatform.android, installedFromPlay: true), UpdateRoute.play);
    expect(updateRoute(TargetPlatform.android, installedFromPlay: false), UpdateRoute.github);
    // TestFlight and the App Store update iOS themselves; an APK link is wrong there.
    expect(updateRoute(TargetPlatform.iOS, installedFromPlay: false), UpdateRoute.none);
    expect(updateRoute(TargetPlatform.macOS, installedFromPlay: false), UpdateRoute.none);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/play_in_app_update_test.dart`
Expected: compile error, `updateRoute` / `UpdateRoute` are not defined.

- [ ] **Step 3: Implement**

Append to `play_in_app_update.dart`:

```dart
/// How this install should look for a newer version.
enum UpdateRoute { play, github, none }

/// Play installs update through Play only (Play policy). Sideloaded Android
/// copies use the GitHub release. Everything else, iOS included (TestFlight /
/// App Store), updates through its own store and is never offered an APK.
UpdateRoute updateRoute(
  TargetPlatform platform, {
  required bool installedFromPlay,
}) {
  if (platform != TargetPlatform.android) return UpdateRoute.none;
  return installedFromPlay ? UpdateRoute.play : UpdateRoute.github;
}
```

In `home_page.dart` `initState`, replace the `if / else if` with:

```dart
      final route = updateRoute(
        defaultTargetPlatform,
        installedFromPlay: await PlayInAppUpdate.isInstalledFromPlay(),
      );
      if (!mounted) return;
      switch (route) {
        case UpdateRoute.play:
          await PlayInAppUpdate.checkForUpdate();
        case UpdateRoute.github:
          showUpdateVersionDialog(context);
        case UpdateRoute.none:
          break;
      }
```

Keep the existing comment, and add a line: "iOS updates through TestFlight / the App Store." Add `import 'package:flutter/foundation.dart';` if needed.

- [ ] **Step 4: Run the tests**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/play_in_app_update.dart lib/shared/pages/home_page.dart test/play_in_app_update_test.dart
git commit -m "fix(update): iOS 不再跳 GitHub APK 更新提示"
```

---

### Task 5: Hide the Google sign-in button where it cannot work

**Files:**
- Modify: `lib/core/auth/auth_service.dart` (add a getter next to `supabaseSignInWithGoogle`)
- Modify: `lib/shared/pages/sign_in_page.dart:~164-168`, `lib/shared/pages/sign_up_page.dart:~204-208`
- Test: `test/google_sign_in_availability_test.dart`

**Interfaces:**
- Produces: `bool get googleSignInAvailable` (top-level in `auth_service.dart`). It is `true` only on Android, and it is the same condition the service already enforces at `auth_service.dart:43`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/auth/auth_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Google sign-in is offered only where it is wired up (Android)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(googleSignInAvailable, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(googleSignInAvailable, isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/google_sign_in_availability_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

In `auth_service.dart` (top level):

```dart
/// iOS has no OAuth client yet (see `Constants.googleWebClientId`), and App
/// Store guideline 4.8 would also require Sign in with Apple. Until both
/// exist, the button is hidden there rather than always failing.
bool get googleSignInAvailable =>
    defaultTargetPlatform == TargetPlatform.android;
```

Change the guard in `supabaseSignInWithGoogle` to `if (!googleSignInAvailable) {`, so the check lives in one place.

In both pages, wrap the "or" divider `Padding` and `googleSignInButton(...)` so that neither renders when it is unavailable:

```dart
                  if (googleSignInAvailable) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: textOnDivider(context, 'or'.tr()),
                    ),
                    googleSignInButton(context, onPressed: signInGoogle),
                  ],
```

If removing the divider leaves the sign-up link touching the button above it on iOS, add `const SizedBox(height: AppSpacing.<nearest existing step to 16>)` in the hidden branch. Check `lib/core/theme/` for the spacing names. Do not hardcode a number.

- [ ] **Step 4: Run the tests**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth/auth_service.dart lib/shared/pages/sign_in_page.dart lib/shared/pages/sign_up_page.dart test/google_sign_in_availability_test.dart
git commit -m "fix(auth): iOS 先隱藏 Google 登入按鈕（尚未設定 iOS OAuth client）"
```

---

### Task 6: Plaza account info stays on the game origin on iOS

**Files:**
- Modify: `lib/shared/providers/plaza_bridge.dart` (add `guardedPublishScript`)
- Modify: `lib/shared/pages/plaza_tab_page.dart:~86-93` (`_infoUserScript`)
- Test: `test/plaza_bridge_test.dart` (append)

**Interfaces:**
- Consumes: `PlazaBridge.publishScript(Map<String, Object>)` and `PlazaBridge.originOf(String url)`. Both already exist; read their exact signatures first.
- Produces: `static String guardedPublishScript(Map<String, Object> info, String origin)`.

- [ ] **Step 1: Write the failing test**

Append to `test/plaza_bridge_test.dart`. Reuse its existing imports and any info-map helper it already has, otherwise build the map inline:

```dart
  test('the document-start script only publishes on the game origin', () {
    final info = <String, Object>{'accountId': 'u-1', 'accountEmail': 'a@b.c'};
    final js = PlazaBridge.guardedPublishScript(info, 'https://games.example.com');
    expect(js, startsWith('if(location.origin==="https://games.example.com"){'));
    expect(js, endsWith('}'));
    expect(js, contains(PlazaBridge.publishScript(info)));
  });

  test('a quote in the origin cannot break out of the guard', () {
    final js = PlazaBridge.guardedPublishScript(const {}, 'https://x.com"};alert(1);//');
    // jsonEncode escapes the quote, so the whole origin stays one string literal.
    expect(js, startsWith(r'if(location.origin==="https://x.com\"};alert(1);//"){'));
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/plaza_bridge_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

In `PlazaBridge`:

```dart
  /// [publishScript] guarded by the page's origin. `allowedOriginRules` on a
  /// UserScript is honoured only on Android, so on iOS this guard is what keeps
  /// the account fields off every other site the plaza navigates to.
  static String guardedPublishScript(Map<String, Object> info, String origin) =>
      'if(location.origin===${jsonEncode(origin)}){${publishScript(info)}}';
```

In `plaza_tab_page.dart` `_infoUserScript()`, use it for `source:` with `PlazaBridge.originOf(Constants.gameUrl)`, and keep `allowedOriginRules` for Android. Check every other place that injects `publishScript` into the page (grep `publishScript` in `lib/`). Calls that run only after `_onGamePage(...)` returned true are already origin-checked and stay as they are. Any unguarded one must switch to the guarded form.

- [ ] **Step 4: Run the tests**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/providers/plaza_bridge.dart lib/shared/pages/plaza_tab_page.dart test/plaza_bridge_test.dart
git commit -m "fix(plaza): iOS 上帳號資訊只給遊戲網域（allowedOriginRules 只在 Android 生效）"
```

---

### Task 7: iOS project polish (localisation, iPhone-only, unused location key) and docs

**Files:**
- Modify: `ios/Runner/Info.plist`
- Create: `ios/Runner/en.lproj/InfoPlist.strings`, `ios/Runner/zh-Hant.lproj/InfoPlist.strings`, and register both in `ios/Runner.xcodeproj/project.pbxproj` as a variant group (see Step 2)
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (`TARGETED_DEVICE_FAMILY`)
- Modify: `CLAUDE.md`

- [ ] **Step 1: Info.plist**
  - Add `CFBundleLocalizations` = array [`en`, `zh_TW`]. easy_localization requires this on iOS.
  - **Remove** `NSLocationAlwaysAndWhenInUseUsageDescription`. Nothing requests always-on location; grep `locationAlways` in `lib/` to confirm before removing.
  - Run `plutil -lint`.

- [ ] **Step 2: Localised permission prompts**

`ios/Runner/en.lproj/InfoPlist.strings`:

```
"NSBluetoothAlwaysUsageDescription" = "SilverSole uses Bluetooth to connect to your insoles for foot pressure, gait and fall detection data, and to update their firmware.";
"NSCameraUsageDescription" = "The camera scans friends' and venues' QR codes, takes profile photos, and detects movement in camera-mode games. Game video is processed on the phone only, never recorded or uploaded.";
"NSLocationWhenInUseUsageDescription" = "Your location is used to show where the device is.";
"NSPhotoLibraryUsageDescription" = "Photo access lets you pick a profile picture.";
```

`ios/Runner/zh-Hant.lproj/InfoPlist.strings` carries the same four keys with the exact Chinese strings now in `Info.plist`. Copy them verbatim.

Registering them in the Xcode project is the fiddly part. Add a `PBXVariantGroup` named `InfoPlist.strings`, with two `PBXFileReference` children (`en`, `zh-Hant`), add it to the Runner group and to the Runner target's Resources build phase, and add `zh-Hant` to `knownRegions`. Model it exactly on how `Main.storyboard` / `LaunchScreen.storyboard` (`Base.lproj`) are wired in the same file, with new 24-hex-character IDs that do not collide (`grep` each before use). Then:

```bash
flutter build ios --release --no-codesign --build-name=1.11.0 --build-number=1
ls build/ios/iphoneos/Runner.app/en.lproj/InfoPlist.strings build/ios/iphoneos/Runner.app/zh-Hant.lproj/InfoPlist.strings
```

Expected: both files are in the built app. If the variant group gets unworkable, stop and report. Do not ship a half-wired `project.pbxproj`.

- [ ] **Step 3: iPhone only**

`sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/g' ios/Runner.xcodeproj/project.pbxproj`. This is a portrait phone app, and on iPad `SharePlus.share` without `sharePositionOrigin` throws and the portrait lock is ignored. Confirm `grep -c 'TARGETED_DEVICE_FAMILY = 1;'` equals the number of Runner configurations.

- [ ] **Step 4: CLAUDE.md**

Edit only these spots. Check `git diff CLAUDE.md` first for hunks from other sessions; if any are there, commit only your own hunks (see the user's git memory).
- "Required local config": add `ios/Flutter/Secrets.xcconfig` with `MAPS_API_KEY=` (the iOS Maps key, which differs from Android's). The build still compiles without it, but maps will not load.
- Opening paragraph: "Primary target is Android (the background BLE pipeline is Android-only)." → "Android and iOS. Android keeps BLE alive in a foreground service, iOS through the `bluetooth-central` background mode. iOS cannot re-find a lost sole while suspended."
- Pipeline step 2: "It is **Android-only** (early-returns otherwise)" → "It runs on Android and iOS (`bleOrchestrationSupported`); permissions go through `ble_permissions.dart` (iOS: `Permission.bluetooth`)".
- Pipeline step 3: note that the service channel is a no-op off Android.
- CI / Release, in-app updates: "the GitHub prompt … runs only for sideloaded copies" → "… only for sideloaded **Android** copies (`updateRoute`); iOS updates through TestFlight / the App Store."

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build ios --release --no-codesign --build-name=1.11.0 --build-number=1
git add ios/Runner/Info.plist ios/Runner/en.lproj/InfoPlist.strings ios/Runner/zh-Hant.lproj/InfoPlist.strings ios/Runner.xcodeproj/project.pbxproj CLAUDE.md
git commit -m "chore(ios): 權限說明加英文、只支援 iPhone、移除未使用的背景定位說明；更新 CLAUDE.md"
```

---

## Hand-back checklist (for the executor's final report)

- Test count before and after (Task 0 baseline vs. final).
- `flutter build ios --release --no-codesign` output from the final commit.
- Anything in "Review Focus" you could not verify without a phone. On-device checks are for the user:
  - pair a sole on an iPhone;
  - background the app while connected, and fall alerts still arrive;
  - OTA end to end;
  - the plaza on a non-game page.
- Commits on `ios-parity`, not pushed and not merged.
