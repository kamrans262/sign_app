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

Stage 2 adds `firebase_core`, `firebase_messaging`, runtime permission and registration,
per-company preference toggles, foreground inbox refresh, notification-open routing,
logout token revocation and token refresh listeners.

The development branch's `main.dart` uses native Firebase default configuration as an
optional bootstrap while project-generated options are not yet committed. Before iOS
device testing, initialize with `DefaultFirebaseOptions.currentPlatform` from the
FlutterFire-generated file and configure Xcode Push Notifications + Background Modes.
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
