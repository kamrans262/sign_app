# Sign2Digital M23 — Subscription, Free Trial & Stripe Billing (Flutter Handoff)

**Status: PREPARED ONLY; do not implement or deploy until Stage 1 is requested.**
**Final module:** M23, after completed M22. Keep the current Flutter branch `fix/m20-android-live-reminder-integration-2026-11-06`; Laravel stays on `fix/m20-admin-ui-modal-filters-2026-11-06`. No new branches, merges or production changes.
**Canonical full backend/API/Admin plan:** `kamrans262/sign_backend/docs/M23_SUBSCRIPTIONS_FREE_TRIAL_STRIPE_BILLING_PREPARED_PLAN_2026-11-06.md` on the current Laravel branch.

## Already approved and present in Flutter

- `lib/features/subscription/presentation/screens/subscription_overview_screen.dart`
- `lib/features/subscription/presentation/screens/choose_plan_screen.dart`
- `lib/features/subscription/presentation/screens/subscription_management_screen.dart`
- `lib/features/subscription/domain/subscription_plan.dart`
- `lib/features/subscription/data/subscription_overview_repository.dart`
- Reuse existing `subscription_current_plan_card.dart`, `subscription_feature_list.dart`, `subscription_management_action_card.dart`.

These currently display **demo** plans, prices, features and usage; do not treat them as paid subscriptions, and never bill the demo CHF figures. Existing approved UX: Overview -> Choose Plan Monthly/Yearly -> Payment Details -> Confirmation; Manage/Change Plan, Payment Method, Billing History, Usage, Cancel Subscription.

## Stage 1 (backend and mobile functional foundation — no Stripe keys)

- Real company-bound plan, usage, entitlement and subscription-state repositories; verified server-managed free allowance of **three uniquely issued/finalized documents per company** by default. Avoid counting drafts, previews and regenerated/signature PDFs. Avoid activation/legacy lockouts until separately authorized.
- Wire existing Overview, Choose Plan and Management screens to authenticated backend data and the active-company selector. No sample prices, status, billing dates or usage shown as live when logged in.
- Add the missing Payment Details / confirmation states using the exact existing visual language, 20px padding, Inter and established widgets. In Stage 1, real purchase actions explicitly unavailable while gateway is unconfigured.
- Appropriate account role and company access rules, conflict and retry handling; never show another company's billing history or plan.
- 320px portrait and full-width landscape acceptance, no clipped navigation/input, stable active-company switching, fixture-only demo previews, widget and API-contract tests.

## Stage 2 (Stripe integration implementation — still no real keys)

- Backend-controlled Checkout session in subscription mode, Stripe-hosted payment capture and secure return-to-app; confirm actual server subscription status instead of activating from the success URL.
- Backend-controlled Customer Portal for payment method and Stripe billing history; allow upgrade/downgrade, renewal, cancel/resume, failed payment states, and accurate pending labels through existing screens.
- Fake/test adapter and verified webhook fixtures in CI. Never ship Stripe secret to Flutter and never claim success based on mock customer cards.
- Existing Flutter UI style preserved. Run M22 profile/security and M20/M21 regression suites. No backend deploy and no Firebase activation.

## After Stage 2: keys and activation

The user has the Stripe publishable key (`pk_...`) and secret key (`sk_...`), to be connected **after code completion** only. Stripe webhook signing secret (`whsec_...`) and monthly/yearly `price_...` identifiers must also be configured through secure server/Stripe Dashboard settings, not chat/GitHub. Start in Stripe test mode, verify real webhook/portal/checkout on devices, then seek separate production approval.

**Current action:** plan committed only; M23 Stage 1 remains not started.
