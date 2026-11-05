# Sign2Digital M20 Stage 2: Firebase Push Delivery

**Development only:** no Hostinger deployment, production credentials or cron installation has been performed.

Firebase project: `sign-kamran` / sender ID `473496260414`.
Android and iOS Firebase registrations: `com.example.sign2digital` for the current development builds.

## Flutter device setup

The user's Windows workstation ran FlutterFire and generated `lib/firebase_options.dart` and
`android/app/google-services.json` locally. Those exact generated files are not available
to the GitHub connector; they must be added from the workstation before an actual Android/iOS
release. `firebase_options.dart` contains non-secret Firebase app identifiers, not
server admin credentials.

Stage 2 adds `firebase_core` 5.x, `firebase_messaging` 17.x with Installation IDs (FID), runtime permission and registration,
per-company preference toggles, foreground inbox refresh, notification-open routing,
logout token revocation and token refresh listeners.

The development branch's `main.dart` uses native Firebase default configuration as an
optional bootstrap while project-generated options are not yet committed. Xcode Push Notifications, Debug/Release aps-environment entitlements, and Background Modes
are now configured in the development branch. Apple Developer provisioning and an APNs
.p8 key upload are still required before real iOS push testing. Native iOS Firebase
initialization requires GoogleService-Info.plist or explicit generated options.
The FlutterFire-generated Android google-services.json must be present at build time.

Never put the Firebase service-account JSON in this Flutter repository.

## Laravel / Hostinger release gates

Set these on the PRIVATE Laravel server only (after release approval):

```
M20_FCM_ENABLED=false
M20_FCM_PROJECT_ID=sign-kamran
M20_FCM_CREDENTIALS_PATH=/absolute/private/path/firebase-service-account.json
```

The credentials file must be readable by PHP and outside public_html. Download it
from Firebase console -> Project Settings -> Service accounts -> Generate new private key.
Never paste its private key into a chat, commit, logs or a Flutter build.

Before enabling, confirm Firebase Cloud Messaging API is enabled for the project,
verify MySQL migrations, and have the production cron call `php artisan schedule:run`
each minute. `sign:m20-dispatch` is read-only without `--send`, and even `--send`
does not call Firebase unless M20_FCM_ENABLED=true and credentials are valid.
Push recipients must explicitly enable push in the app. This is entirely independent
of M19 borrower emails and does not opt anybody into them.

APNs for iOS requires an Apple Developer APNs authentication key uploaded to Firebase
Console > Project Settings > Cloud Messaging, and Xcode's Push Notifications and
Remote Notifications background capability plus correct signing/provisioning.

## Testing and operations

- Verify dedicated SQLite and MySQL GitHub CI and regression workflows.
- Test permission-granted / denied / revoked, app foreground/background/terminated,
  token rotation, company switch, logout, duplicate dispatch, retries and invalid tokens
  on real Android and iOS devices.
- Admin may edit English/French push title and body using the already published
  `/admin/notifications/templates` UI. Future push delivery batches use those revisions.
- No production deployment, cron, APNs upload or real FCM sends occurred during code work.

## Stage 2 verified code and release boundary

- Laravel M20 Stage 2 dedicated CI: SQLite, MySQL 8.4, M19/M17/M18 regressions.
- Flutter Stage 2 CI: strict analysis, API registration, original reminders/equipment UI,
  and native iOS entitlement metadata checks.
- The server always re-checks company membership, user activity, event state, push
  opt-in and device revocation immediately before attempting an external send.
- The server never automatically retries an uncertain provider timeout; a documented
  submission only shows that Firebase accepted the request, not device display.
- The app can be run locally from the Windows generated configuration, but that
  configuration is not in the GitHub development branch until deliberately added.
- The existing example Android/iOS package ID is still com.example.sign2digital.
  Finalize your production bundle ID BEFORE registering a production app in Firebase.
- No live push or device delivery can be claimed without the private server credentials,
  user opt-in, real installed application, and (iOS) an APNs authentication key.
