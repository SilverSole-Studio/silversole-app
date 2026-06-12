# SilverSole UI Design-System Refactor — Design Spec

Date: 2026-06-12
Status: Approved (architecture + scope), pending spec review
Reference: `DESIGN.md` (visual language), `ui_ref/` (8 screenshots)

## 1. Goal

Refactor **all page UI frontend** of SilverSole to the DESIGN.md visual language, and do it as a **modular** change: future pages/widgets compose UI as naturally as stock Material — no long `TextStyle`/`.copyWith` chains, no scattered hardcoded hex. Changing the brand theme color later must be a **few-line** edit.

## 2. Decisions (locked)

- **Brand color → blue**, fully per DESIGN.md: primary `#2F6BFF`, highlight cyan `#29B6E8`. (Replaces current green `#2E7D32`.)
- **Single source of truth** for color: one `app_palette.dart`; change `brandSeed` (1 line) to retheme.
- **Full refactor**: build the design-system foundation, then re-skin every page and widget and align layouts to the DESIGN.md language.
- **Theme Material globally + `ThemeExtension`** (not a static color class, not a parallel widget library).

## 3. Non-goals / constraints

- **No backend changes.** `lib/core/` services, `lib/shared/providers/`, routing logic, and `settingsProvider.darkMode` are untouched. If a UI need seems to require a provider/service change, stop and ask.
- **Not** rebuilding DESIGN.md's invoice screens (different app domain) — we adopt its _style_, applied to SilverSole's existing domain pages.
- **Preserve domain data-viz meaning**: foot-pressure jet colormap, analytics pressure gradient, and chart series colors keep their values (centralized, not recolored).
- Keep the existing grayscale-neutral philosophy: accent drives chromatic roles only; surfaces/outlines stay grayscale; light surface stays `#FCFCFC`; `surfaceTint` transparent.

## 4. Current state (from codebase map)

- `lib/app.dart` builds `ThemeData` inline in `appTheme(Brightness)`: `ColorScheme.fromSeed(green)` + monochrome-neutral `.copyWith` + transparent `surfaceTint` + light surface `#FCFCFC`. ThemeMode from `settingsProvider.darkMode`.
- `lib/core/theme/typograhpy.dart`: only applies Oxanium family; no sizes/weights. `lib/core/theme/theme.dart` is empty.
- `lib/core/utils/useful_extension.dart`: `context.cs`, `context.tt`, `String/TextStyle .bold` helpers.
- No component themes, no `ThemeExtension`.
- Styling debt: 287 instances (77 `.copyWith`, 26 hardcoded hex, 61 inline radius/padding); font re-applied by hand in 6+ files (incl. an `'oxanium'` case typo).
- Shell: go_router flat; `home_page.dart` hosts bottom `NavigationBar` (`app_navigation_bar.dart`) + `IndexedStack` over 5 tabs; each page builds its own `Scaffold`+`AppBar`.
- `test/theme_test.dart` asserts green-dominant accent + grayscale neutrals + `#FCFCFC` + transparent tint.

## 5. Architecture — new `lib/core/theme/` foundation

| File                  | Responsibility                                                                                                                                                                                                                                                                                                                    |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app_palette.dart`    | **Only place raw colors live.** `const brandSeed = Color(0xFF2F6BFF)`, `brandCyan`, `rewardGold #FAC42A`, `dataOrange #FF9A1F`, `alert #E5392E`, `success`, gradient stop lists, and `AppDataViz` ramps (pressure jet, analytics gradient, chart series — values unchanged). Retheme = edit `brandSeed` (+ optional `brandCyan`). |
| `app_typography.dart` | Full `TextTheme` builder. Every slot carries size + weight (Oxanium `fontVariations: [FontVariation('wght', n)]` + matching `fontWeight`). Replaces the family-only `AppTypography`.                                                                                                                                              |
| `app_spacing.dart`    | `abstract final class AppSpacing { static const xs=4, sm=8, md=12, base=16, lg=20, xl=24, xxl=32; }` (dp per DESIGN §4).                                                                                                                                                                                                          |
| `app_radius.dart`     | `AppRadius { card=20, banner=16, fab=18, field=12, sub=8; pill = StadiumBorder; }` + ready-made `BorderRadius`/`RoundedRectangleBorder` getters.                                                                                                                                                                                  |
| `app_tokens.dart`     | `class AppTokens extends ThemeExtension<AppTokens>` holding non-`ColorScheme` colors (brandCyan, rewardGold, dataOrange, alert, success, onReward), gradients, and `AppDataViz`. Implements `copyWith` + `lerp`. Two instances: `AppTokens.light` / `AppTokens.dark`.                                                             |
| `app_theme.dart`      | `ThemeData appTheme(Brightness)` (moved out of `app.dart`): `ColorScheme.fromSeed(brandSeed)` + grayscale-neutral lock (ported verbatim from current `app.dart`) + global `textTheme` + **all component themes** (§7) + `extensions: [AppTokens.of(brightness)]`.                                                                 |
| `theme.dart`          | Barrel export of the above (currently empty file repurposed), so callers `import 'package:.../core/theme/theme.dart'`.                                                                                                                                                                                                            |

`lib/app.dart` shrinks to: import `app_theme.dart`, wire `theme: appTheme(light)`, `darkTheme: appTheme(dark)`, `themeMode` from `settingsProvider` (unchanged).

### 5.1 Type scale → Material `TextTheme` slots (DESIGN §3)

| Slot            | size / wght | Use                           |
| --------------- | ----------- | ----------------------------- |
| `displayLarge`  | 36 / 800    | auth hero, big landing titles |
| `displaySmall`  | 28 / 800    | hero secondary                |
| `headlineSmall` | 24 / 700    | stat numbers, large values    |
| `titleLarge`    | 20 / 700    | page title / AppBar           |
| `titleMedium`   | 16 / 700    | section/card title            |
| `titleSmall`    | 14 / 600    | sub-section                   |
| `bodyLarge`     | 16 / 500    | emphasized body               |
| `bodyMedium`    | 15 / 400    | default body                  |
| `bodySmall`     | 13 / 400    | caption / meta                |
| `labelLarge`    | 14 / 600    | button text                   |
| `labelMedium`   | 12 / 500    | chips/badges                  |
| `labelSmall`    | 11 / 500    | nav labels                    |

Consequence: most `*.copyWith(fontWeight: bold, fontFamily: 'Oxanium')` calls are deleted — the slot already carries it. `.bold` helper stays for the few deliberate overrides.

### 5.2 Ergonomics — extend `useful_extension.dart`

Keep `context.cs`, `context.tt`, `.bold`. Add `context.tokens` → `Theme.of(context).extension<AppTokens>()!`. New widget code:

```dart
Card(child: Text('標題', style: context.tt.titleMedium))     // sized/weighted already
FilledButton(onPressed: …, child: Text('連線'))               // blue pill from theme
Container(color: context.tokens.rewardGold)                  // custom token
padding: const EdgeInsets.all(AppSpacing.base)
```

## 6. ColorScheme neutral-lock (preserve)

Port the existing logic verbatim: build `accents = ColorScheme.fromSeed(brandSeed, brightness)`, build `neutrals` from the monochrome variant, then `.copyWith` all surface/outline roles from `neutrals`, force light `surface = #FCFCFC`, `surfaceTint = transparent`. Only the seed changes (green→blue). This keeps `theme_test.dart`'s grayscale guarantees intact.

## 7. Component themes (in `app_theme.dart`)

| Theme                                                                                                                                          | Config                                                                                                                                                                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `appBarTheme`                                                                                                                                  | transparent bg + `surfaceTintColor` transparent, `elevation 0`, `scrolledUnderElevation 0`, `centerTitle false`, `titleTextStyle = titleLarge`.                                                                                                      |
| `cardTheme`                                                                                                                                    | `color = surfaceContainerLow`(card), `surfaceTintColor` transparent, shape `RoundedRectangleBorder(AppRadius.card)`. Light: small `elevation` + `shadowColor` (~8% black) for the soft DESIGN shadow; Dark: `elevation 0` (separated by color step). |
| `filledButtonTheme`                                                                                                                            | bg primary / fg onPrimary, `StadiumBorder`, `minimumSize (0,48)`, `textStyle = labelLarge`, `elevation 0`.                                                                                                                                           |
| `elevatedButtonTheme` / `outlinedButtonTheme`                                                                                                  | `elevation 0`, `StadiumBorder` (or `AppRadius.field` where rectangular), consistent padding.                                                                                                                                                         |
| `chipTheme` (ChoiceChip)                                                                                                                       | `StadiumBorder`, unselected bg `surfaceContainerHighest`/chip; **selected → `inverseSurface` bg + `onInverseSurface` label** (this _is_ the DESIGN inverse-chip rule for free: dark-in-light, white-in-dark).                                        |
| `navigationBarTheme`                                                                                                                           | `height 64`, `backgroundColor = surface`, `elevation 0`, `indicatorColor` transparent, `labelBehavior alwaysShow`; `iconTheme`/`labelTextStyle` via `WidgetStateProperty`: selected → primary, else → `onSurfaceVariant`/hint; label = `labelSmall`. |
| `floatingActionButtonTheme`                                                                                                                    | bg primary / fg white, `RoundedRectangleBorder(AppRadius.fab)` squircle.                                                                                                                                                                             |
| `inputDecorationTheme`                                                                                                                         | `OutlineInputBorder(AppRadius.field)`, focused border = primary; consistent for auth/device fields.                                                                                                                                                  |
| `dividerTheme`                                                                                                                                 | color = outlineVariant, `thickness 1`, `space` from tokens.                                                                                                                                                                                          |
| `segmentedButtonTheme`, `bottomSheetTheme` (top radius `card`, drag handle), `dialogTheme` (radius `card`), `progressIndicatorTheme` (primary) | aligned.                                                                                                                                                                                                                                             |

## 8. Helper composites (thin, only where Material has no equivalent)

- `SectionCard({title, trailing, onTap, child})` — `lib/shared/widgets/section_card.dart`. Card + header row (`titleMedium` + trailing `→`/action) + body; applies exact DESIGN card shadow. Primary card used across home/analytics/person.
- `StatRow(List<StatItem>)` — equal columns + thin vertical dividers (DESIGN C2).
- `BrandGradientText(text, style)` — `ShaderMask` with `tokens.brandGradient` (hero highlight).
- `AppScaffold({title, actions, body, floatingActionButton})` — optional, dedupes per-page Scaffold+AppBar. Adopt where it simplifies; not forced.

## 9. Migration — pages & widgets

Foundation lands first (whole app turns blue + consistent). Then, file by file, replace hardcoded color/`copyWith`/inline radius with tokens/slots and apply the visual language:

**Pages** (`lib/shared/pages/`):

- `home_body.dart` — hero greeting (`displaySmall` + `BrandGradientText`), `SectionCard`s, fix `'oxanium'` typo, token paddings.
- `devices_page.dart` — list via themed cards/`build_material_list`, FAB squircle (from theme), search field via `inputDecorationTheme`.
- `device_connect_bottom_modal.dart` — `bottomSheetTheme`, themed buttons/progress.
- `analytics_page.dart` (heaviest) — move pressure gradient to `AppDataViz`; `SectionCard`s; `SegmentedButton` via theme; replace `withValues` opacities with token-derived; remove `copyWith` font/weight.
- `analytics_detail_page.dart` — pill tab states via `AppRadius`/inverse pattern; themed Filled/Elevated buttons.
- `pressure_visualization_page.dart` — jet colormap → `AppDataViz.jet` (values unchanged); themed sensor cards; remove `Colors.grey`.
- `person_page.dart` — settings rows via `build_material_list`; titles via slots; dark-mode toggle unchanged.
- `sign_in_page.dart` / `sign_up_page.dart` — replace `Colors.grey` with `onSurfaceVariant`; titles via `displayLarge`; fields/buttons via themes.
- `device_recent_warnings_page.dart` — slots + tokens.

**Widgets** (`lib/shared/widgets/`, `dialogs/`):

- `status_card.dart`, `warning_card.dart` — central cards: kill hardcoded `TextStyle(fontFamily:'oxanium',…)`/`FontVariation`; `Colors.red`→`tokens.alert`, `Colors.green`→`tokens.success`, `Colors.grey[800]`→`onSurfaceVariant`; radii via `AppRadius`.
- `recent_data_list.dart`, `recent_data_chart_card.dart` — wear icons → `tokens.success`/`alert`; chart legend series → `AppDataViz.series`; slots/tokens.
- `build_material_list.dart` — `outerRadius 16/innerRadius 4` → `AppRadius`.
- `device_binding_field.dart`, `update_check_bottom_modal.dart` — fields/buttons via themes, token spacing.
- `app_navigation_bar.dart` — relies on `navigationBarTheme` (blue active); keep icon set.
- `chart/chart_section.dart` — series colors → `AppDataViz.series` (theme-aware) instead of `Colors.accents`.
- `foot_pressure_heatmap.dart` — pull jet/marker colors from `AppDataViz`; keep math + values.
- `map_card.dart`, `rader_dot.dart` — radii/tokens; map keeps its JSON light/dark styles.

## 10. Tests

- `test/theme_test.dart`: replace `isGreenDominant` → `isBlueDominant` (blue channel dominant for primary). Keep grayscale-neutral, `#FCFCFC`, transparent-tint assertions (still valid).
- Add: `AppTokens` present in both brightness themes; key `TextTheme` slots non-null with expected weights; `brandSeed` is the single recolor knob (smoke check primary derives from it).

## 11. Verification

- `flutter analyze` clean (CI runs `--no-fatal-warnings --no-fatal-infos`).
- `flutter test` green (incl. updated theme tests).
- Manual: run app, screenshot Home / Analytics / Devices / Settings / Sign-in in **both** light and dark; confirm blue brand, inverse chips, squircle FAB, soft card shadow, readable text, and that the pressure heatmap/charts keep their colors.

## 12. Rollout

1. Foundation: `app_palette` → `app_spacing`/`app_radius` → `app_typography` → `app_tokens` → `app_theme` → rewire `app.dart` → extend `useful_extension` → update `theme_test`. Verify build/test/visual at this checkpoint (app already looks blue + consistent).
2. Helper composites (`SectionCard`, `StatRow`, `BrandGradientText`, optional `AppScaffold`).
3. Re-skin widgets (central cards first: `status_card`, `warning_card`).
4. Re-skin pages (home, analytics, devices, pressure, person, auth, detail, warnings).
5. Final analyze + test + light/dark screenshots.

## 13. File inventory

**New:** `app_palette.dart`, `app_typography.dart` (replaces typo'd `typograhpy.dart`), `app_spacing.dart`, `app_radius.dart`, `app_tokens.dart`, `app_theme.dart`, `theme.dart` (barrel); `widgets/section_card.dart`, `widgets/stat_row.dart`, `widgets/brand_gradient_text.dart`, optional `widgets/app_scaffold.dart`.

**Modified:** `lib/app.dart`, `lib/core/utils/useful_extension.dart`, `test/theme_test.dart`, all listed pages/widgets, and `CLAUDE.md` (document the new theme system). `lib/core/theme/typograhpy.dart` removed/migrated.

**Untouched:** providers, services, routing logic, models, `settingsProvider`, l10n CSV.
