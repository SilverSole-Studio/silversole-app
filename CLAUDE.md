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

### Theme & design system

The UI design system lives in `lib/core/theme/` (barrel: `theme.dart`). **Build UI with stock Material widgets — the theme styles them.** Don't write `TextStyle`/`.copyWith(fontFamily/fontWeight)` chains or hardcode hex.

- **One color knob.** `app_palette.dart` holds every raw color. Re-theme the whole app by changing `AppPalette.brandSeed` (royal blue `#2F6BFF`). Accent drives `primary/secondary/tertiary`; all neutral surfaces/outlines stay grayscale (light surface `#FCFCFC`, `surfaceTint` transparent) — enforced by `test/theme_test.dart`.
- **`app_theme.dart`** builds light/dark `ThemeData`: `ColorScheme.fromSeed` + grayscale-neutral lock + a full `textTheme` + **every component theme** (Card, Filled/Elevated/Outlined buttons, Chip, NavigationBar, AppBar, FAB, Input, Divider, SegmentedButton, BottomSheet, Dialog) + registers `AppTokens`.
- **Access via `context` helpers** (`core/utils/useful_extension.dart`): `context.cs` (ColorScheme), `context.tt` (TextTheme — every slot pre-sized/weighted in Oxanium; pick the slot instead of `copyWith`), `context.tokens` (`AppTokens`: `rewardGold`, `onReward`, `dataOrange`, `alert`, `success`, `brandCyan`, `brandGradient`). Scales: `AppSpacing.*`, `AppRadius.*` (+ ready-made `.cardR`/`.pillShape`/etc.).
- **Custom (non-ColorScheme) colors** go on the `AppTokens` `ThemeExtension` (`app_tokens.dart`); functional hues are theme-independent. Domain data-viz ramps (`AppPalette.pressureJet/pressureGradient/chartSeries`) carry clinical meaning — reuse them, don't recolor.
- **Composites** for recurring DESIGN.md patterns: `SectionCard` (titled card + optional trailing `→`), `StatRow`, `BrandGradientText`. Chip selection uses Material `inverseSurface` → dark-in-light / white-in-dark automatically.
- Selected-chip, FAB squircle, blue-active nav, and soft card shadow all come from the theme — don't re-style per widget. Visual language reference: `DESIGN.md`.

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

#### Pipeline implementation status (reviewed 2026-06)

After `bleForegroundControlProvider` the flow fans out into five branches. Their actual state (verified by code review — don't assume more is wired up than this):

- **Live IMU — working end-to-end.** notify → `parseImuNotify` → `ImuNotifyDataModel` → `LiveTelemetryNotifier.updateImuNotifyData` (rolling window, last 100) → `telemetryViewProvider` → `ImuChartSection`, `PressureVisualizationPage`, `HomeDeviceStatusSection`.
- **Record — works device↔app, no cloud.** `AnalyticsDetailPage` writes `record-request=1` to start; record notify accumulates via `updateRecordImuNotifyData` (**unbounded — the trim to a max length is commented out**); shown in `RecordImuChartSection` and exported only as a shareable JSON file (`buildRecordJson` → `createFileAndShare`). Recordings are never uploaded.
- **Device status / heartbeat — upload works, read-back disabled.** notify → timestamp validation (>10 min drift dropped) → `DeviceStatusIngestService` → Edge Function `heartbeat` → `devices` table. However the UI read-back is dead: `DeviceStatusCard.refreshDeviceStatus()` is fully commented out, `HomeDeviceStatusSection` fabricates the battery/heartbeat detail from the last live IMU sample, and "online" is judged from live-telemetry freshness (`TelemetryFacade.checkDeviceOnline`, 35 s window) — not from the DB heartbeat the app just uploaded.
- **Fall detection — in-memory only.** notify `"1"` → `FallEventBus` → `WarningCard` increments an in-memory counter that resets on app restart. No history persistence, no per-device separation, no upload (`TODO` in `warning_card.dart`).
- **Upload queue — not implemented.** `TelemetryIngestService` is an **orphan**: no provider wraps it and nothing in the app calls it. `enqueue()` is empty, `flushQueue()`/`uploadOne()` return `Ok` without doing anything, `scheduleRetry()` is empty, and `TelemetryUploadBuffer` is an empty class. The `QueuedTelemetry` freezed model is already defined and ready to reuse when this gets built. Consequently **the app never writes `silversole_record_data`** — `RecentDataList` and the analytics pages read a table only external tooling can populate.

Known gaps / dead code related to this flow:

- `SilverSoleService.bindingDevice` only checks the device exists in `devices` — the `user_devices` insert is commented out, so binding is never persisted.
- `TelemetryQueryService` is entirely unused and duplicates `SilverSoleService`'s queries.
- `LiveTelemetryNotifier._load()` is empty (no local restore), and `TelemetrySource.supabase` is never assigned — only `bleLive`.

### Backend (Supabase)

- **Auth**: `AuthService` (`core/auth`) wraps Supabase email/password. `authUserProvider` exposes the current `UserData?` and listens to `onAuthStateChange`. The router (`core/routing/router.dart`) redirects guests to `/sign-in` and signed-in users away from auth pages.
- **Queries**: `SilverSoleService` (`core/data`) reads tables `devices`, `silversole_record_data`, `device_locations`, `user_devices`. It guards on `currentUser`/empty deviceId and maps `PostgrestException` codes to localized messages — notably RLS denials (`42501` → `'rls_denied'.tr()`). Do not change RLS-related handling without understanding these mappings. (`TelemetryQueryService` duplicates these queries and is unused — see pipeline status above.)

### Local persistence

Settings and paired BLE devices persist via **`shared_preferences`**, wrapped in `lib/core/data/save_service.dart` (keys in the `LocalSavableKey` enum). `settingsProvider` (`AppSettings` via freezed) holds identity, deviceId, darkMode, transmission method, the paired-devices list, and the preferred device. (`hive` is in `pubspec.yaml` but is **not** used in `lib/` — persistence goes through shared_preferences.)

### Models & codegen

Models use **freezed + json_serializable**. Each lives as `foo.dart` + generated `foo.freezed.dart` + `foo.g.dart`. After editing any model, run the `build_runner` command above; the generated files are committed. JSON field names from the device firmware use snake_case via `@JsonKey(name: ...)` (e.g. `battery_percent`).

### Internationalization

Strings live in `assets/translations/strings.csv` (CSV, loaded by `easy_localization` + `CsvAssetLoader`). Supported locales: `en` and `zh-TW` (fallback `en`). `.tr()` is used pervasively — **including for user-facing error messages and some error codes**, so new error strings need CSV entries.

## CI / Release

- `.github/workflows/flutter-ci.yml`: on PRs/pushes to `main`, synthesizes `.env` from GitHub Secrets, then runs analyze + test + debug APK build.
- `.github/workflows/flutter-release.yml`: pushing a `v*.*.*` tag builds a signed `--split-per-abi` arm64 release APK, extracts that version's section from `CHANGELOG.md` as release notes, creates a GitHub Release, and posts to Discord. The in-app `update_checker.dart` checks the GitHub releases API. **When releasing, add a matching `## vX.Y.Z` section to `CHANGELOG.md`** (the workflow greps for it).
