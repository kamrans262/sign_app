# Stage 1 — Mobile interface localization

- Supported languages: English (fallback), French, German, Italian.
- Existing Profile & Settings > Preferences > Language immediately applies and persists an explicit device-local interface choice. Save Preferences remains available to save account preferences; a server save failure does not revert the interface choice.
- No saved device choice: Flutter resolves the device language against the supported languages. Unsupported languages fall back to English.
- Existing server preferences retain their canonical language names. Saving unrelated settings does not overwrite the server language. Device-local UI choice does not automatically sync across devices; no backend changes.
- Localized in Stage 1: preference screen, More entry menu, profile settings entry cards, bottom navigation, selection-sheet close/default subtitle, Flutter-provided Material/Cupertino controls. Catalog uses explicit static labels, with English fallback. Do not translate API values, document data, user-entered text or signed files.
- Existing text style, typography, colors, padding, widgets and navigation preserved. No new screen or modal.
- Stage 2: remaining custom UI strings, validation and dynamic states across all modules; native permission strings and supported-language metadata before release. Stage 3: Laravel, AI-output guidance, newly generated PDF copy, customer webpages, email and notification localization (separate backend branch and handoff). Stage 4: full mobile device regression, localized overflow, signing and release testing. Stage 1 and Stage 2 mobile-only scope excluded backend changes.
- Run `flutter pub get`, `flutter analyze`, `flutter test test/core/localization/app_language_test.dart test/features/profile/profile_preferences_screen_test.dart` and native device tests before release. The Flutter SDK resolves flutter_localizations and its transitive dependencies; refresh and review the lockfile with the actual build SDK.
