# App Store Preflight Fixes Implementation Plan

> **For agentic workers:** implement task-by-task, in order. Steps use checkbox (`- [ ]`) syntax. TDD where there is logic: failing test → minimal code → green → commit.

**Goal:** Clear the code-side App Store rejections and warnings found by the `app-store-preflight-skills` audit (2026-10-26), so the first App Store submission is not bounced for things the app itself can fix.

**Architecture:** Small, independent fixes in the existing Flutter app plus one new Supabase Edge Function. No new architecture; follow the patterns already in the files touched (Riverpod providers over plain services, `Result<T>`, `.tr()` strings in `assets/translations/strings.csv`, theme via `context.*` getters — see `CLAUDE.md`).

**Tech Stack:** Flutter 3.47.6, Riverpod v3, supabase_flutter, easy_localization (CSV), Deno Edge Function (Supabase).

**Spec:** The preflight report in the session (rules from `~/.agents/skills/app-store-preflight-skills/references/`). Guidelines cited per task.

## Global Constraints

- Flutter binary: `export PATH=/private/tmp/claude-501/-Users-andongni-Documents-Myself-Folder-16-Big-Project-SilverSole-silversole-app/d69cee22-57a4-4018-82c2-3e793a1c21a5/scratchpad/flutter-3.47.6/bin:$PATH` (the user's own SDK at `~/Documents/Myself_Folder/_Other/flutter` is too old — do not touch it).
- Work on `main`. The working tree has lots of **unrelated untracked/modified files** (mascot assets, etc.): stage **only** the files your task changed, by path. Never `git add -A`/`.`/`-a`. Before committing `strings.csv` or `CLAUDE.md`, check `git diff` for hunks that are not yours.
- Do **not** push. Commit messages in Traditional Chinese, `type(scope): 說明` like the existing history, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every new user-facing string goes into `assets/translations/strings.csv` with both `en` and `zh-TW` columns.
- `flutter analyze` must stay clean for touched files; `flutter test` must stay fully green (currently 408 tests).
- Out of scope (needs the user): Sign in with Apple, privacy policy / terms text and URLs, support e-mail, demo account, review notes. The firmware developer mode (7 taps) **stays as is** — the user chose to document it in the review notes.
- Read `memory`-style gotcha: widget tests that mount `EasyLocalization` need the shared_preferences mock and only one `EasyLocalization` mount per test file, or they hang.

## Review Focus

1. A user who never ran a foot check must see an honest empty state on the mascot home, never a number.
2. Account deletion must leave the app signed out and on `/sign-in` even when the function call fails half-way (no stuck session pointing at a deleted user).
3. The sole-sample stream must not reach a page whose origin is not the games domain, including after an in-page navigation away from it.
4. Report/block must be reachable from every place a stranger's nickname or photo is shown.
5. Removing the launch-time location request must not break the map cards (they request on demand already).

---

### Task 1: Location permission only when needed (5.1.1)

**Files:** Modify `lib/main.dart`, `ios/Runner/Info.plist`, `ios/Runner/en.lproj/InfoPlist.strings`, `ios/Runner/zh-Hant.lproj/InfoPlist.strings`.

- [ ] Delete the `Permission.locationWhenInUse.request()` block in `main()` (and imports that become unused). `map_card.dart:123` and `safe_zone_map_view.dart:84` already call `Geolocator.checkPermission/requestPermission` when a map needs the position — read both to confirm, and confirm nothing else relied on the launch prompt.
- [ ] **Keep** `NSLocationAlwaysAndWhenInUseUsageDescription`: geolocator's binary references `requestAlwaysAuthorization`, and App Store Connect flags a missing purpose string (ITMS-90683) even if never called. Rewrite all location purpose strings (Info.plist zh default + both `.strings`) to say concretely what location is for, e.g. zh: 「在地圖上顯示你目前的位置，方便查看鞋墊位置與設定安全範圍。」 / en: "Shows where you are on the map, so you can see your insoles' location and set a safe zone." For the Always key, same purpose, and add that the app does not track location in the background.
- [ ] `plutil -lint` all three plists/strings; `flutter analyze`; commit `fix(ios): 啟動時不再要求定位權限，定位用途說明寫清楚`.

### Task 2: App privacy manifest

**Files:** Create `ios/Runner/PrivacyInfo.xcprivacy`; modify `ios/Runner.xcodeproj/project.pbxproj` (add file reference + Runner target "Resources" build phase entry, same way `Info.plist`/`LaunchScreen.storyboard`/`Assets.xcassets` are wired — use fresh 24-hex IDs that don't collide).

- [ ] `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty, `NSPrivacyAccessedAPITypes` empty array (Runner's own Swift uses no Required Reason API; every plugin except flutter_blue_plus_darwin ships its own manifest and fbp uses none — verified).
- [ ] `NSPrivacyCollectedDataTypes`: declare what the app actually sends to Supabase, verified by reading the code, each with `Linked` true, `Tracking` false, purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`. Expected (confirm/adjust from code): Email Address (auth), User ID, Name (friends nickname), Photos or Videos (avatar upload), Device ID (sole chip ID / device status heartbeat), Other User Content only if found. Do **not** declare data the app never uploads (live IMU/pressure stays on device; recordings are only shared by the user as a file).
- [ ] Verify the pbxproj still parses: `plutil -lint ios/Runner.xcodeproj/project.pbxproj` and `xcodebuild -list -project ios/Runner.xcodeproj`. Commit `chore(ios): 加上 App 隱私清單 PrivacyInfo.xcprivacy`. List in the commit body which data types were declared and why.

### Task 3: Sole samples only to the games domain (4.7.2)

**Files:** Modify `lib/shared/providers/game_sole_forwarding.dart` (+ its callers `GameWebViewPage`, `PlazaTabPage` if the signature changes); test `test/game_sole_forwarding_test.dart` and/or `test/sole_sample_script_test.dart`.

- [ ] Read how `plaza_bridge.dart` guards its script (`guardedPublishScript`, origin check inside the injected JS because `allowedOriginRules` is Android-only) and how `game_camera_permission.dart` decides the games origin. Reuse the same origin constant (`Constants` games URL, `https://h5.silversole.dongyu.company`).
- [ ] Failing test first: the script produced for a sample is wrapped so it only runs when `location.origin` equals the games origin (string-level assertion on the generated JS, like `plaza_bridge_test`), and/or forwarding skips evaluation when the web view's current URL origin is not the games origin (whichever matches the existing structure — prefer guarding inside the JS, so a navigation between the check and the evaluation cannot leak).
- [ ] Implement, green, commit `fix(games): 鞋墊資料只送給遊戲網域的頁面`.

### Task 4: No fake figures presented as real (1.4.1 / 2.3.1)

User decision: **show real state where data exists, an honest empty state where it doesn't; the gait tab gets a clear "sample data" label.**

**Files (expected):** `lib/shared/pages/theme_two/home_body_t2.dart`, `lib/shared/pages/daily_missions_bottom_modal.dart`, the gait tab widgets in both themes (find users of `gait_analysis_data.dart`), the foot-check result page (to persist the score), `lib/core/data/save_service.dart` (`LocalSavableKey`), `assets/translations/strings.csv`, related tests (`daily_missions_bottom_modal_test.dart`, `gait_panel_test.dart`, `gait_panel_t2_test.dart`, `foot_check_result_page_test.dart` …).

- [ ] **Sweep first:** `grep -rn "mock\|placeholder\|comingSoon\|TODO" lib/` and list every figure or entry a release-build user can see that is fake or leads to "coming soon". Put that list in the commit body. Fix all of them in this task, using the rules below; anything that does not fit a rule, choose the most honest option and note it.
- [ ] **Health score (mascot home):** persist the last foot-check result (score + timestamp) via `save_service.dart` when a foot check finishes (the result page / rating already computes it — `foot_check_rating.dart`). Home shows that score and when it was taken; with none saved, show an empty state (e.g. 「尚未做過足部健檢」 + the existing route into the foot check) — no number. Remove `mockScore`. Test: persisted score shows; no saved result → no digits in that card.
- [ ] **Steps / step goal / streak:** the app has no pedometer. Remove the step figures and the streak count from the mascot home; the daily-mission card and sheet must not show step progress or a walking mission with fake progress — drop the walking mission (and its `comingSoon()`), keep the missions that lead somewhere real. Remove `mockSteps`, `mockStepGoal`, `mockStreakDays`. `foot_check_status` (uses mockSteps) needs new copy without a step count.
- [ ] **Fall guard:** drop the "family notified" clause and the "7 days" framing; say what is true (falls detected since the app was opened / none detected). Remove `mockFamilyNotified`.
- [ ] **Gait tab (both themes):** keep the content but add a prominent, non-dismissable 「範例資料 · 尚未實際量測」 / "Sample data — not measured yet" banner at the top of the tab, styled with existing theme tokens (no hardcoded hex). Also soften copy that reads as a personal diagnosis about *this* user (e.g. `strings.csv` lines around 358–387: "watch closely", "worsening together… falling confidence", "most recent fall: week 10", "early sign of functional decline") so it reads as an example. Test: the banner renders in both gait panels.
- [ ] Update/extend tests, full suite green, commit `fix(ui): 移除假裝真實的數字，沒有資料就誠實顯示`.

### Task 5: Delete account (5.1.1(v))

**Files:** Create `supabase/functions/delete-account/index.ts` (+ `supabase/functions/delete-account/deno.json` only if the repo convention needs it — there is no `supabase/functions` dir yet; `heartbeat` lives in another repo, so keep this one self-contained). Modify `lib/core/auth/auth_service.dart`, the account section of `lib/shared/pages/person_page.dart` (and the mascot-theme equivalent if one exists — grep for the sign-out row), `assets/translations/strings.csv`, `supabase/README.md` (one paragraph: what the function does, how to deploy). Tests under `test/`.

- [ ] **Edge Function:** `Deno.serve`; read the caller's JWT from `Authorization`, resolve the user with a client created from `SUPABASE_URL` + `SUPABASE_ANON_KEY` and that header (`auth.getUser()`); 401 if none. With a service-role client (`SUPABASE_SERVICE_ROLE_KEY`): list and remove the user's objects in the avatars bucket (read `supabase_friends_repository.dart` around `avatarsBucket` for the bucket name and path layout), then `auth.admin.deleteUser(user.id)`. Return JSON `{ ok: true }` / `{ error }` with proper status codes. Only POST. No CORS needed (mobile only). Do **not** deploy — the lead deploys it.
- [ ] **Data left behind:** read `supabase/migrations/*.sql` and the queries in `lib/core/data/` for every table keyed by user id (`user_devices`, `devices`, `device_locations`, `silversole_record_data`, friends tables…). Tables in the migrations already `on delete cascade` to `auth.users`; for tables not defined in this repo you cannot see the FK — list them in the report so the lead can check the live schema. Don't write a migration for tables you can't see.
- [ ] **App:** `AuthService.deleteAccount()` → `Result<void>`: `functions.invoke('delete-account', method: HttpMethod.post)`; on success (and also on a 401/404 meaning "user already gone") sign out locally (Supabase + `GoogleSignIn.instance.signOut()` like `supabaseSignOut`), clear `authUserProvider`. Map failures to localized messages. UI: a destructive "刪除帳號 / Delete account" row in the account section, below sign out, only when signed in. Tapping opens a confirmation dialog that states plainly what is deleted (account, nickname/photo, friends) and that it cannot be undone; destructive confirm button uses `colorScheme.error`. Busy state while running; on success navigate to `/sign-in` with a snackbar.
- [ ] Tests: dialog appears and cancel does nothing; the service maps an `Ok`/error from an injectable invoker (make the invoke a constructor-injected function or a small seam so it is unit-testable without Supabase).
- [ ] Commit `feat(auth): App 內刪除帳號（Edge Function delete-account）`.

### Task 6: Report / block wherever strangers appear (1.2)

**Files:** `lib/shared/pages/friends/org_pages.dart` (member rows), `lib/shared/pages/friends/requests_page.dart` (incoming requests), `lib/core/friends/friend_rules.dart` (nickname filter), repository/interface only if a method is missing, strings, tests under `test/friends/`.

- [ ] Read how `person_pages.dart` offers report (photo / nickname) and block, and reuse the same repository calls and dialogs — extract a shared helper/widget if both new places need the same menu, rather than copying.
- [ ] Org member rows (not yourself): an overflow menu with report photo, report nickname, block.
- [ ] Incoming friend requests: add report (photo / nickname) next to the existing decline-and-block.
- [ ] Nickname filter: a small blocklist of obvious slurs/profanity (zh + en, case-insensitive, also matching with spaces/punctuation stripped) checked in `friend_rules.dart` alongside the existing reserved-name check, returning the existing invalid-nickname error path with a new message key. Check `supabase/migrations/20261026120000_friends_rpc_abuse.sql` — if the server validates nicknames too, say so in the report (do not change SQL in this task).
- [ ] Tests for the filter (blocked word, blocked word with spacing, normal names pass) and that the new menu entries exist. Commit `feat(friends): 組織成員與好友邀請也能檢舉、封鎖；暱稱加不雅字過濾`.

### Task 7: Wrap-up

- [ ] Full `flutter analyze` (CI flags: `--no-fatal-warnings --no-fatal-infos`) and `flutter test`; both green.
- [ ] Update `CLAUDE.md` only where a statement became false (e.g. the location request at startup, the delete-account function). Check `git diff CLAUDE.md` for other people's hunks before committing.
- [ ] Final report to the lead: commits (hash + subject), anything deviating from this plan and why, the list from Task 4's sweep, the tables from Task 5 whose cascade could not be verified, and the server-side nickname validation finding from Task 6.
