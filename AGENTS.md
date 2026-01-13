# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains Flutter source code. Key areas include `lib/shared/pages/` for screens, `lib/shared/widgets/` for reusable UI, `lib/core/` for utilities (errors, routing, update checker), and `lib/constants.dart` for app constants.
- `assets/` holds static files: `assets/images/` for graphics, `assets/fonts/` for fonts, and `assets/translations/strings.csv` for i18n strings.
- `test/` contains Flutter tests.
- Platform folders: `android/`, `ios/`, plus `build/` for build outputs.
- GitHub Actions live under `.github/workflows/`

## Build, Test, and Development Commands
- `flutter pub get` installs dependencies.
- `flutter run` launches the app on a connected device/emulator.
- `flutter analyze` runs static analysis using `analysis_options.yaml`.
- `flutter test` runs unit/widget tests in `test/`.
- `flutter build apk --debug` builds a debug APK; `flutter build apk --release` for release.

## Coding Style & Naming Conventions
- Use Dart/Flutter defaults: 2-space indentation, trailing commas where appropriate.
- Class names in `UpperCamelCase`, file names in `lower_snake_case`.
- Prefer const constructors where possible; keep widgets small and focused.
- Lint rules are defined in `analysis_options.yaml` and enforced via `flutter analyze`.

## Testing Guidelines
- Framework: Flutter test (`flutter_test`).
- Place tests under `test/` and name files `*_test.dart`.
- Run `flutter test` locally before PRs.

## Commit & Pull Request Guidelines
- Commit history uses conventional prefixes like `feat:` and `fix:` (e.g., `feat: update checker...`).
- PRs should include a clear description, linked issues (if any), and screenshots for UI changes.
- Mention any required setup (e.g., `.env` keys, Supabase config) in the PR body.

## Configuration Notes
- Environment variables come from `.env` (registered in `pubspec.yaml`).
- Localization strings live in `assets/translations/strings.csv` and are loaded via `easy_localization`.

## Security & Secrets
- Never commit secrets (API keys, tokens, service credentials) to the repo.
- Store local secrets in `.env`; ensure `.env` is in `.gitignore` and only referenced via `flutter_dotenv`.
- For CI/CD, use GitHub Secrets and inject them at runtime (e.g., create `.env` in workflows).
- When logging errors, avoid printing sensitive values to console or crash reports.
- Do not modify RLS policies without documenting the rationale and impact.

## Modernization Preference
- When a requirement can be fulfilled by a well-supported, widely adopted package or framework, prefer that over custom-built implementations.
- If a custom solution is proposed, document why a mature alternative (e.g., Riverpod for state management) is not suitable.
