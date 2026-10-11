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
- **Access via `context` helpers** (`core/utils/useful_extension.dart`): `context.colorScheme` (ColorScheme), `context.textTheme` (TextTheme — every slot pre-sized/weighted; pick the slot instead of `copyWith`), `context.tokens` (`AppTokens`: `rewardGold`, `onReward`, `dataOrange`, `alert`, `success`, `brandCyan`, `brandGradient`). Scales: `AppSpacing.*`, `AppRadius.*` (+ ready-made `.cardR`/`.pillShape`/etc.).
- **Always reach theme data through these `context` getters** — `context.colorScheme` / `context.textTheme` / `context.tokens` referenced inline. Do **not** call `Theme.of(context).colorScheme` / `.textTheme` directly, and do **not** introduce local `final cs = Theme.of(context).colorScheme` / `final tt = Theme.of(context).textTheme` variables.
- **Custom (non-ColorScheme) colors** go on the `AppTokens` `ThemeExtension` (`app_tokens.dart`); functional hues are theme-independent. Domain data-viz ramps (`AppPalette.pressureJet/pressureGradient/chartSeries`) carry clinical meaning — reuse them, don't recolor.
- **Composites** for recurring DESIGN.md patterns: `SectionCard` (titled card + optional trailing `→`), `StatRow`, `BrandGradientText`. Chip selection uses Material `inverseSurface` → dark-in-light / white-in-dark automatically.
- Selected-chip, FAB squircle, blue-active nav, and soft card shadow all come from the theme — don't re-style per widget. Visual language reference: `DESIGN.md`.

### `Result<T>` instead of exceptions

`lib/core/error/result.dart` defines a sealed `Result<T>` (`Ok` / `Error`). Service methods return `Result` and callers `switch` over it rather than try/catch. Follow this convention for new service methods.

### The BLE → telemetry pipeline (the core flow)

This spans several files; read them together:

1. **GATT contract** — `lib/core/ble/ble_uuids.dart` lists one service UUID and its characteristics: live IMU notify, record notify, base-timestamp (write), device-status notify, record-request, fall-detect notify — plus the standard Device Information Service (`0x180A`), whose Serial Number (`0x2A25`) is the sole's chip ID. (The main service also declares a device-id characteristic that the firmware never fills in; the app does not read it.)

   **Sole identity** — every sole reports a permanent **chip ID** (the nRF52840 FICR DEVICEID as 16 uppercase hex characters) in two places: its advertisement's Manufacturer Specific Data (company code `soleManufacturerId`, currently the SIG test value `0xFFFF` and due to change before production — keep it to that one constant), and the DIS Serial Number after connecting. Every sole advertises the same name, so this ID — not the name and not the address — is what identifies a sole. Firmware from before the ID existed reports none, and some soles in users' hands still run it, so such a sole falls back to its `remoteId`: `BlePairedDevice.identityKey` is `deviceId ?? remoteId`, `isSameSole()` compares IDs when both sides have one and addresses otherwise, and `upsertPairedDevice()` (`save_service.dart`) merges entries for the same sole — including an address-only entry picking up its ID once its sole reports one. `remoteId` is only where the sole was last seen.
2. **Connection orchestration** — `bleForegroundControlProvider` (`lib/shared/providers/ble_foreground_controller.dart`) is `ref.watch`ed once in `App`. It is **Android-only** (early-returns otherwise). It is **scan-driven, not remoteId-driven**: a remembered address is not a reliable way back to a sole, so it scans and recognises soles by the chip ID they advertise. `searchAndAttach()` scans (`SoleScanner` in `lib/core/ble/sole_scanner.dart`, matching `silversole` in the advertised name), picks with `pickSole()` — the primary device when it is on the air, then any other paired sole by signal strength, then (last resort) a sole that cannot be identified: one advertising no ID, or any sole while some paired entry still has no ID. A sole advertising an ID nobody paired is never auto-connected. The pick goes to `BleConnectionService.attach()` with a `BleSessionHandlers` bundle. Auto-connect only starts once the user has paired a sole by hand. Two timers back it: a search backoff (15/30/60 s) while nothing is advertising, and a 30 s watchdog that re-scans when a session never connects or does not come back after a link loss — the "give up on this MAC" path. Only the primary device (its `identityKey` and address) and whether anything is paired at all are watched, so the `lastConnectedAt` write on every reconnect does not restart the search. A manual primary-device pick changes both the identity and the address, and only that forces a search while another sole is connected. A sole moving to a new address, or an old entry picking up its ID, changes just one of the two and does not force one.

   `BleConnectionService` (`lib/core/ble/ble_connection_service.dart`) owns the single live session and is **connection-state driven, not polled**. `attach()` subscribes to `BluetoothDevice.connectionState` and connects with **`autoConnect: false`** (a direct connection); every `connected` event re-runs the handshake, and every `disconnected` event arms an internal backoff reconnect (1/2/4/8/16/30 s). Do **not** switch this to `autoConnect: true`: fbp passes it straight to Android's `connectGatt(context, autoConnect, …)`, and that background acceptlist connection routinely never completes for a device the Bluetooth stack has not connected to before — a freshly added sole then silently never connects. The handshake order is deliberate: `requestMtu` (kept here so MTU and setup live in one place) → **one** `discoverServices()` whose result backs every characteristic lookup → reads/writes (chip ID from the DIS Serial Number, base timestamp) → `onReady` → notify subscriptions **last**, because the live IMU characteristic streams at 50 Hz and would otherwise starve the remaining round-trips. Notify subscriptions are retired by `device.cancelWhenDisconnected()` rather than a manual cache, and `onValueReceived` (not `lastValueStream`) is used so a `read()` elsewhere does not replay a packet into the telemetry pipeline. Do not reintroduce per-operation `connect()`/`discoverServices()` calls or an `isConnected` polling timer — that combination produced a reconnect loop that re-wrote the base timestamp every ~42 s.
3. **Android foreground service** — `startBleService()`/`stopBleService()` in `ble_service_channel.dart` call a `MethodChannel` (`com.dongyutech.silversole/ble_service`) handled by `MainActivity.kt`, which runs `BleForegroundService.kt` (a sticky foreground service with an ongoing notification) so BLE survives backgrounding.
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

Settings and paired BLE devices persist via **`shared_preferences`**, wrapped in `lib/core/data/save_service.dart` (keys in the `LocalSavableKey` enum). `settingsProvider` (`AppSettings` via freezed) holds identity, deviceId, darkMode, transmission method, the paired-devices list (keyed by `identityKey`, see Sole identity above), and the preferred device. (`hive` is in `pubspec.yaml` but is **not** used in `lib/` — persistence goes through shared_preferences.)

### Models & codegen

Models use **freezed + json_serializable**. Each lives as `foo.dart` + generated `foo.freezed.dart` + `foo.g.dart`. After editing any model, run the `build_runner` command above; the generated files are committed. JSON field names from the device firmware use snake_case via `@JsonKey(name: ...)` (e.g. `battery_percent`).

### Internationalization

Strings live in `assets/translations/strings.csv` (CSV, loaded by `easy_localization` + `CsvAssetLoader`). Supported locales: `en` and `zh-TW` (fallback `en`). `.tr()` is used pervasively — **including for user-facing error messages and some error codes**, so new error strings need CSV entries.

## CI / Release

- `.github/workflows/flutter-ci.yml`: on PRs/pushes to `main`, synthesizes `.env` from GitHub Secrets, then runs analyze + test + debug APK build.
- `.github/workflows/flutter-release.yml` ships to Google Play and GitHub Releases. The tag shape picks the path, and **production only ever gets a bundle testers already ran**:
  - `vX.Y.Z-rc.N` builds a signed AAB (to Play closed testing / `alpha`) plus split-per-ABI and universal APKs (to a GitHub pre-release), all with version code = the workflow run number.
  - `vX.Y.Z` builds nothing: `.github/scripts/play_promote.py` takes the newest live `vX.Y.Z-rc.N` on `alpha`, puts the same version code on `production` at 100 % (Google review follows; keep managed publishing off), and the GitHub release reuses that rc's APKs. No such rc → the run fails before touching production.
  - Manual runs (`workflow_dispatch`) build for an explicit track; `none` only builds the AAB artifact — that is how the first-ever upload to Play Console is made by hand.
  - **When releasing, add a matching `## vX.Y.Z` section to `CHANGELOG.md`** (rc tags use the same section). Play's "what's new" is generated from it by `.github/scripts/play_whatsnew.py`: the bullets under `更新內容:` (zh-TW) and `Updates:` (en-US), kept whole from the top within Play's 500-character cap — so lead with the most important change and keep bullets short.
  - Secrets: the keystore four, `PLAY_SERVICE_ACCOUNT_JSON` (Play API service account), `MAPS_API_KEY`, the Supabase pair, `DISCORD_WEBHOOK_URL`.
- In-app updates: a Play install updates through Play only (`PlayInAppUpdate` → `InAppUpdateController.kt`, priority from the release, 3 = flexible, installed once the app is backgrounded). Play policy forbids steering a Play install to another download, so the GitHub prompt (`update_check_bottom_modal.dart` / `update_checker.dart`) runs only for sideloaded copies.
