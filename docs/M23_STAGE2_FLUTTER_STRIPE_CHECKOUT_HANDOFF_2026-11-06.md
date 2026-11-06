# M23 Stage 2 — Stripe Hosted Billing Flutter Handoff

**Branch:** `fix/m20-android-live-reminder-integration-2026-11-06` (existing branch, no new branch).

**Code-stage only; no Stripe keys, no production charge, no deployment.** Canonical backend architecture and activation instructions: `kamrans262/sign_backend/docs/M23_STAGE2_STRIPE_IMPLEMENTATION_AND_ACTIVATION_HANDOFF_2026-11-06.md`.

## Approved UI and real behavior

- The exact existing subscription screens (Overview, Choose Plan and Management) remain. Payment Details now reviews only the server-published plan with approved price and features, and uses the existing white cards, Inter, teal `#166282`, dark `#122536`, 20px padding, responsive max-width and navigation.
- Signed-in billing is loaded from authenticated `X-Company-Id` APIs and invalidated if the active company changes during a request. Demo prices remain isolated to signed-out/design previews, and cannot trigger Stripe payments.
- Secure Checkout uses `url_launcher` to open only `https://checkout.stripe.com/...`, and the Billing Portal only `https://billing.stripe.com/...`. Flutter never asks for raw card details and never stores publishable or secret API keys.
- Once Checkout opens, the app displays **pending**, never paid. A separate **Verify Payment Status** action rechecks the backend's authoritative provider state; return URLs or browser-close signals are not evidence of success.
- Plan changes require Stripe's server-side preview and an explicit modal confirm; the backend uses no proration by default. Payment method opens the official Customer Portal; cancellation requires confirmation and requests period-end cancellation; resume is shown when that cancellation is scheduled. All errors are truthful; no payments are fabricated.
- Billing History fetches only the logged-in company’s verified SaaS invoices and never conflates M17 customer-issued invoices.
- `url_launcher` was added to `pubspec.yaml`; run `flutter pub get` after pulling the branch. Never add Stripe secret keys to Flutter. The official Stripe SDK does **not** need to be added on-device for hosted Checkout.

## Verification and external gates

Offline widget and repository tests cover trusted-domain redirects, mock HTTP billing state, company isolation, no-Stripe disabled checkout, pending confirmation, plan-change preview/consent, cancellation and portrait/landscape. CI also runs Android debug compilation and previous-module Flutter suites. These tests use a fake Stripe provider; they do **not** prove real Test Mode delivery.

External test mode approval still requires the actual backend, a properly configured HTTPS Checkout return URL/app-link association, Stripe Dashboard customer portal and live signed webhook endpoint, real Android/iOS devices, and explicit authorization. Keep all billing flags OFF until that separate activation.
