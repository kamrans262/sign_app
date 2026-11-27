# Stage 1 — Mobile interface localization

- Supported languages: English (fallback), French, German, Italian.
- Existing Profile & Settings > Preferences > Language > Save Preferences applies an explicit device-local interface choice after a successful preferences save.
- No saved device choice: Flutter resolves the device language against the supported languages. Unsupported languages fall back to English.
- Existing server preferences retain their canonical language names. Saving unrelated settings does not overwrite the server language. Device-local UI choice does not automatically sync across devices; no backend changes.
- Localized in Stage 1: preference screen, More entry menu, profile settings entry cards, bottom navigation, selection-sheet close/default subtitle, Flutter-provided Material/Cupertino controls. Catalog uses explicit static labels, with English fallback. Do not translate API values, document data, user-entered text or signed files.
- Existing text style, typography, colors, padding, widgets and navigation preserved. No new screen or modal.
- Stage 2: remaining custom UI strings, validation and dynamic states across all modules; native permission strings and supported-language metadata before release. Stage 3: full device regression and overflow testing. Backend/PDF/email/AI/customer webpages excluded.
- Run `flutter pub get`, `flutter analyze`, `flutter test test/core/localization/app_language_test.dart test/features/profile/profile_preferences_screen_test.dart` and native device tests before release. The Flutter SDK resolves flutter_localizations and its transitive dependencies; refresh and review the lockfile with the actual build SDK.
