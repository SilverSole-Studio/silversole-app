# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SilverSole is a Flutter client for a "smart sole" wearable. The phone connects to the sole over BLE, streams live IMU/pressure telemetry and device status, and syncs to a Supabase backend. Primary target is Android (the background BLE pipeline is Android-only).

See also `AGENTS.md` for coding-style, commit, and PR conventions — they are not repeated here.

## Commands

```bash
flutter pub get                       # install dependencies
flutter run                           # run on connected device/emulator
flutter analyze                       # static analysis (CI runs with --no-fatal-warnings --no-fatal-infos)
flutter test                          # all tests
flutter test test/simply_test.dart    # a single test file
flutter build apk --debug             # debug APK; --release for a signed release build

# REQUIRED after editing any freezed / json_serializable model (regenerates *.freezed.dart / *.g.dart):
dart run build_runner build --delete-conflicting-outputs
```

### Required local config (not committed)

- `.env` at repo root with `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` (keys defined in `lib/constants.dart`, loaded by `flutter_dotenv`, registered as an asset in `pubspec.yaml`). The app will not start without it.
- `android/local.properties` with `MAPS_API_KEY` for Google Maps.

## Architecture

### Layering

- `lib/core/` — pure logic, no UI: services (`auth/`, `ble/`, `data/`), `error/` (the `Result` type + logger), `routing/`, `theme/`, `utils/`.
- `lib/shared/` — UI (`pages/`, `widgets/`, `dialogs/`), Riverpod `providers/`, and freezed `models/`.
- `lib/main.dart` → `lib/app.dart`: `main()` initializes EasyLocalization, dotenv, and Supabase, then wraps `App` in a `ProviderScope`. `App` is a `ConsumerWidget` using `MaterialApp.router`.

State management is **Riverpod v3**. The pattern throughout is: a `Provider` exposes a plain service class from `lib/core/`, and UI/notifiers consume it. E.g. `soleProvider → SilverSoleService(supabase)`, `bleConnectProvider → BleConnectionService()`.

### `Result<T>` instead of exceptions

`lib/core/error/result.dart` defines a sealed `Result<T>` (`Ok` / `Error`). Service methods return `Result` and callers `switch` over it rather than try/catch. Follow this convention for new service methods.

### The BLE → telemetry pipeline (the core flow)

This spans several files; read them together:

1. **GATT contract** — `lib/core/ble/ble_uuids.dart` lists one service UUID and its characteristics: live IMU notify, record notify, device-id (read), base-timestamp (write), device-status notify, record-request, fall-detect notify.
2. **Connection orchestration** — `bleForegroundControlProvider` (`lib/shared/providers/ble_foreground_controller.dart`) is `ref.watch`ed once in `App`. It is **Android-only** (early-returns otherwise). It listens to `settingsProvider.preferredDevice`; when that changes it auto-connects, subscribes to all characteristics, writes the base timestamp, and runs a 6-second reconnect timer. `BleConnectionService` (`lib/core/ble/ble_connection_service.dart`) caches notify subscriptions per `remoteId|service|char` key.
3. **Android foreground service** — `startBleService()`/`stopBleService()` in `ble_service_channel.dart` call a `MethodChannel` (`com.andongni.silversole/ble_service`) handled by `MainActivity.kt`, which runs `BleForegroundService.kt` (a sticky foreground service with an ongoing notification) so BLE survives backgrounding.
4. **Live telemetry** — incoming IMU JSON → `LiveTelemetryNotifier` (`telemetry_process_providers/live_telemetry_notifier.dart`), which keeps a rolling window of the last 100 samples. Chart widgets read it via `telemetryViewProvider`.
5. **Device status / heartbeat** — status notifications → `DeviceStatusIngestService` → Supabase **Edge Function `heartbeat`** (not a direct table write) to persist battery/heartbeat. Stale payloads (timestamp >10 min off) are dropped.
6. **Fall detection** — fall-detect notifications are emitted on `fallEventBusProvider` (an event bus), decoupled from the connection logic.

> Note: `TelemetryIngestService` and `TelemetryUploadBuffer` are currently **stubs** (`enqueue`/`flushQueue`/`uploadOne` are empty, contain `TODO`s). The live-telemetry path above is what actually runs. Don't assume the queue/upload layer is functional.

### Backend (Supabase)

- **Auth**: `AuthService` (`core/auth`) wraps Supabase email/password. `authUserProvider` exposes the current `UserData?` and listens to `onAuthStateChange`. The router (`core/routing/router.dart`) redirects guests to `/sign-in` and signed-in users away from auth pages.
- **Queries**: `SilverSoleService` and `TelemetryQueryService` (`core/data`) read tables `devices`, `silversole_record_data`, `device_locations`, `user_devices`. They guard on `currentUser`/empty deviceId and map `PostgrestException` codes to localized messages — notably RLS denials (`42501` → `'rls_denied'.tr()`). Do not change RLS-related handling without understanding these mappings.

### Local persistence

Settings and paired BLE devices persist via **`shared_preferences`**, wrapped in `lib/core/data/save_service.dart` (keys in the `LocalSavableKey` enum). `settingsProvider` (`AppSettings` via freezed) holds identity, deviceId, darkMode, transmission method, the paired-devices list, and the preferred device. (`hive` is in `pubspec.yaml` but is **not** used in `lib/` — persistence goes through shared_preferences.)

### Models & codegen

Models use **freezed + json_serializable**. Each lives as `foo.dart` + generated `foo.freezed.dart` + `foo.g.dart`. After editing any model, run the `build_runner` command above; the generated files are committed. JSON field names from the device firmware use snake_case via `@JsonKey(name: ...)` (e.g. `battery_percent`).

### Internationalization

Strings live in `assets/translations/strings.csv` (CSV, loaded by `easy_localization` + `CsvAssetLoader`). Supported locales: `en` and `zh-TW` (fallback `en`). `.tr()` is used pervasively — **including for user-facing error messages and some error codes**, so new error strings need CSV entries.

## CI / Release

- `.github/workflows/flutter-ci.yml`: on PRs/pushes to `main`, synthesizes `.env` from GitHub Secrets, then runs analyze + test + debug APK build.
- `.github/workflows/flutter-release.yml`: pushing a `v*.*.*` tag builds a signed `--split-per-abi` arm64 release APK, extracts that version's section from `CHANGELOG.md` as release notes, creates a GitHub Release, and posts to Discord. The in-app `update_checker.dart` checks the GitHub releases API. **When releasing, add a matching `## vX.Y.Z` section to `CHANGELOG.md`** (the workflow greps for it).
