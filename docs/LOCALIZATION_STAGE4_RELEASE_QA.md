# Sign2Digital Stage 4 — localization release QA handoff

**Source branches (unchanged)**
- Flutter: fix/m20-android-live-reminder-integration-2026-11-06
- Laravel: fix/m20-admin-ui-modal-filters-2026-11-06

## Acceptance gates
1. Run Flutter localization, network-header and PDF parity tests on CI.
2. Compile an Android debug APK without signing and an iOS simulator
   build without codesigning on macOS. This does not produce a TestFlight IPA.
3. Run backend Stage 3 localization, public-signing, template, issued-PDF
   integrity and M20–M23 regression tests on SQLite + MySQL.
4. Test on an actual iPhone and an Android handset in English, French,
   German and Italian at system/default font size and larger accessibility
   text. Review sign-in, company, job, quote, invoice, addendum, reports,
   acceptance, expense, deposit, profile, support, subscription and
   notification screens. Verify long words do not clip or overlap.
5. Create *new, unsent* sample documents in each language; review page
   spacing, signature placeholders, reference numbers, original values,
   dates, Swiss QR data and page breaks. Verify AI output languages.
6. Confirm existing signed/issued PDFs retain their original bytes/hash,
   signature and signing time when switching languages. Never reissue.
7. Test customer signed links and standard emails for all four languages.
   Include one deliberately unsupported language (fallback English).
8. Test iOS APNs only with live device signing and provisioning after
   developer authorization; Android FCM should not regress.
9. For TestFlight: on the Mac, preserve the existing Xcode Runner workspace,
   current GoogleService-Info.plist, entitlements, Team ID,
   com.sign2digital.app and **existing app icon**; set a new monotonically
   increasing build number only after tests. Do not automatically regenerate
   launcher icons, splash resources, Pods, or Firebase configuration.
10. Record pass/fail per language. Do not publish or deploy automatically.

## Local Mac commands
From the existing sign_app directory (after the user has authorized pulling):
```sh
git status --short
git fetch origin
git merge --ff-only origin/fix/m20-android-live-reminder-integration-2026-11-06
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/core/localization test/core/sign_api_client_test.dart
flutter build ios --simulator --debug --no-codesign
```

For a **real TestFlight** IPA, a physical macOS/Xcode signed build is required.
The macOS CI simulator build is unsigned and cannot establish APNs delivery,
App Store acceptance, native phone permission behavior or TestFlight upload.

## Production backend gate
No deployment was performed. The additive de/it notification migration
requires an explicit backup and the user's deployment authorization.
Run the existing Laravel regression suite and check published notification
revisions on staging before using `php artisan migrate --force` live.
Preserve older signed PDF snapshots and admin-edited template revisions.

## Stage 4 shared sheet and popup localization correction
Selected language now applies to shared selection option labels, approved confirmation titles and content, existing form dialogs and selected custom invoice/equipment/country/addenda/AI sheets. The underlying option identifiers, callbacks, keys, state, existing layout and Apple platform configuration remain untouched. Test with `flutter test test/core/localization/modal_localization_test.dart`, then verify each module's dialogs on a real device. Dynamic user-entered text is not automatically translated.
