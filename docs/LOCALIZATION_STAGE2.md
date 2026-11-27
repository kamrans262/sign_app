# Stage 2 — mobile localisation implementation

English, French, German and Italian share the existing UI. 1555 source-label entries per non-English language (including Stage 1). The implementation includes screen and common-component labels, form hints and selected validation messages, confirmations, AI voice controls and signature consent, selected dynamic templates, filter and status display, dashboard and search, profile/security/subscription controls, and locale-aware display formatting in job, deposit, invoice, labour, expense, reminder, equipment, AI and report creation forms. Currency formatting is applied to invoice creation totals without changing amount or currency. Date values and stored codes remain unchanged. Native iOS InfoPlist.strings for all five declared permissions in four languages are registered in Runner resources; the OS selects native prompt language.

## Boundaries
No UI styling, routing, financial calculations, API contracts, Android native permissions or application icons intentionally changed. No backend, email, AI output, customer-facing webpage or authoritative PDF localisation performed. Native permission changes add Xcode resources only; retain local developer signing settings when merging. Flutter SDK determines the intl dependency version.

## Verification / remaining coverage
The catalog is not proof of every UI string being connected. Additional strings remain: uncatalogued hardcoded text, custom rich text, some dynamic messages and selector values, backend-provided errors and other monetary/date displays. These need full screen-by-screen translation audit and device QA. Added dedicated focused tests and a read-only CI workflow; native release builds and device results are not verified here. Do not publish the app as fully translated until the audit and tests pass.

## Latest verification
The dedicated localisation workflow passed at d40d9c5 after removing a duplicate named argument in Settings. Later translations extend document preview, signing confirmation, subscription, security setup, addenda, expenses, equipment reminder and job photo workflows. They require a fresh CI run; the earlier pass does not establish verification of the later commit. No device release builds were performed.

The dedicated localisation workflow also passed at f444103, including full Flutter analysis, focused language/profile tests and iOS language declarations. Shared client, job, signature, quote and profile cards were subsequently connected to existing translations; verify the new revision before release.

## Follow-up mobile coverage
Localized dynamic invoice, expense and labour confirmations, retry suffixes, selected dashboard and expense/labour financial display, detail timestamps and VAT percentage labels. Added placeholder regression tests. This changes Dart and documentation only, with no Apple project/configuration or dependency changes. Full remaining screen audit, native device builds and backend-provided text are not certified by this change.

## Language selection correction
Selecting a language now persists the device-local locale and updates the interface immediately, independently of the account preferences save. The existing Save Preferences action remains responsible for account settings. Added a widget regression for immediate French labels and a failed account save. No native or backend files changed.

## Stage 2 code audit closure
The 94 feature presentation screens were reviewed for direct literal Text widget
candidates. Remaining high-impact consent, privacy, signed document, quote,
report, invoice, labour, equipment and profile label gaps were translated and
connected to the existing components. Source-level widget lint and focused
multilanguage regression tests were added. No iOS/macOS project files changed.
The code audit does not replace physical French/German/Italian screen overflow
checks, real network error inspection or release builds; those are Stage 4.
Stage 3 is backend/PDF/email/AI/customer pages (not mobile QA).
