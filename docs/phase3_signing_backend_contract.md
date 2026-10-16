# Phase 3 — Signing backend and deployment contract

The Flutter app now contains screens 23–27, a public signing entry, and native
local caching for PDF artifacts **returned by a trusted signing service**.
This repository does not contain the Laravel service or a deployed public
website. Do not label Phase 3 as production-complete without those services.

## Browser entry

Host the Flutter web bundle on HTTPS with an SPA rewrite for
`/sign/<opaqueToken>` to `index.html`. Compile with
`--dart-define=SIGN2DIGITAL_SIGNING_API_BASE_URL=https://api.example.com`
and replace the example with the real secured backend origin.

This route bypasses the business login UI only, not backend authorization.
Never put admin API keys or personal identity data into the browser URL.
The bearer token must have high entropy, short lifetime, be stored hashed on
the server, scoped to a single document version and signer, and be revoked
after a successful signing or administrative cancellation.

## Required API endpoints

- `GET /api/public/signing/{token}`: Verify token, expiry, document version,
  request status, and signer server-side; rate-limit; return **JSON**:
  `{ "quote": { "id", "clientId", "jobId", "companyId",
  "quoteNumber", "clientName", "clientEmail", "clientPhone",
  "billingAddress", "date", "terms", "currency", "vatBasisPoints",
  "depositBasisPoints", "items": [{"id","title","description",
  "quantity","unitPrice","dimensions"}] }, "request": {"requestId",
  "secureUrl", "expiresAt", "events":[{"id","type","occurredAt"}]},
  "signer": {"documentId","signerId","documentVersion",
  "consentReference"} }`.
  Dates are ISO-8601. The request must include a verified `documentSent`
  event. Return an unauthorized/expired status without quote contents when
  invalid. Do not cache private responses.
- `POST /api/public/signing/{token}/submit`: Verify the token is still
  valid and unspent; compare all quote, request, signer, document-version,
  consent-reference IDs; independently check consent and identity challenges.
  Accept `signaturePngBase64`, method, typed name and capture timestamp as
  **untrusted evidence**, not as proof of authorization.
  Atomically: seal a canonical, versioned copy of the reviewed quote; embed
  the captured signature and relevant audit data into a **signed** PDF;
  associate it with the immutable job ID; store the PDF in protected
  long-lived object storage; record signed event, timestamp, signer and
  audit trail; invalidate the token; return JSON containing:
  `{ "documentId", "quoteId", "jobId", "quoteNumber", "projectName",
  "signerName", "signedAt", "ipAddress", "signedPdfBase64" }`.
  The signed PDF must not be confused with the blank unsigned quote PDF.
  Reject stale/replayed requests and unauthorized document/version swaps.
- Business-user endpoints (authenticated, tenant-scoped) must create
  requests, deliver messages, return secure links and verified events,
  resend requests, download signed documents, and list all documents for a job.
  Do not infer sent or viewed events from opening a share sheet.

All responses and stored audit evidence must use HTTPS, relevant tenant
authorization, access controls, retention policies, and server-side time.
Enforce CORS only for the deployed guest-site origin; never allow credentials
or tokens into logs, analytics, or third-party URLs.

## Flutter behaviors already wired

- Status `Draft/Sent/Viewed/Awaiting Signature/Signed/Expired` derives
  from verified events plus expiry.
- Public guest route loads an authorized customer document, uses the
  existing Draw/Type/Upload signature UI, and submits to the API.
- Signing confirmation requires a matching trusted receipt.
- Native app caches the returned PDF under a job-scoped private index,
  refuses overwrites, and serves the existing Job Documents and Documents
  Detail screens. This **local** cache is not a substitute for the server's
  authoritative permanent storage.
- In-person signing requires distinct signer IDs, both captures,
  consent, and a trusted service callback before confirmation.
- Browser clients rely on the backend's permanent signed-file storage; no
  filesystem persistence is claimed in the browser.

## Production acceptance criteria

1. A customer can open an actual HTTPS link without a Sign2Digital account.
2. Invalid, tampered, expired and replayed tokens reveal no document data.
3. Identity/consent checks are enforced on the server, not just Flutter.
4. Signature submission generates a verifiable PDF of the exact document
   version and stores it permanently under the matching job and tenant.
5. Business-owner Downloads, document history and all status transitions
   use the authoritative server records after app restarts and across devices.
6. Tests cover concurrent submissions, retries, failures, expired requests,
   unsigned/modified document rejection, and permanent document recovery.

Run Flutter tests locally; there is no Flutter SDK or Laravel service attached
to this GitHub editing environment.
