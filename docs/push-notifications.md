# Admin announcements — setup and release

Implemented for Android, iOS and supported web browsers. Neon remains the database.
Firebase Cloud Messaging (FCM) delivers public announcements through a fixed topic
`library-announcements-v1`. There is no Firebase Analytics SDK and no reader account
requirement. Delivery is disabled until explicitly configured. No live migration or
notification was sent while implementing this feature.

## 1. Create Firebase project (no database migration to Firebase)

Open https://console.firebase.google.com and create a project. Google Analytics is
not needed. Register Android app `com.athariyyah.myapp`, Apple app
`com.athariyyah.appname`, and a web app. Do not create Firestore or Realtime Database.
Enable the Firebase Cloud Messaging API if Firebase prompts you.

Download the Android google-services.json and Apple GoogleService-Info.plist to
look up the public app values. Copy `push-config.example.json` to `push-config.json`:

- Project ID: Firebase project settings → General.
- Sender ID: project number / Cloud Messaging Sender ID.
- Android App ID: `mobilesdk_app_id` in the matching client's google-services.json.
- Android API key: that client's `api_key.current_key`.
- Apple App ID: `GOOGLE_APP_ID` from GoogleService-Info.plist.
- Apple API key: `API_KEY` from GoogleService-Info.plist.

These are public application identifiers, **not** a server service account.
The private server key must never go in push-config.json or app build arguments.

## 2. Connect Apple push (required for iOS)

Apple Developer → Certificates, Identifiers & Profiles → Identifiers →
`com.athariyyah.appname`: enable Push Notifications. Create an APNs-enabled key in
Keys, download its .p8 once, and note its Key ID and Apple Team ID. Upload it in
Firebase → Project settings → Cloud Messaging → Apple app configuration.

Refresh/regenerate the App Store provisioning profile in Codemagic after enabling
Push Notifications. The app now has the push entitlement: development for Debug,
production for Release/Profile. The existing background-audio mode is preserved.
You do not need a Mac to configure these portals. Physical iPhone testing is needed.

## 3. Configure the server in Vercel

Firebase → Project settings → Service accounts → generate a private key for the
server. Store the JSON in **Vercel server environment variable**
`FIREBASE_SERVICE_ACCOUNT_JSON`. Do not commit it or paste it in app source.
Restrict the service account to the permissions needed for FCM where feasible.

Set these Vercel variables for the environment you intend to use:

- `PUSH_NOTIFICATIONS_ENABLED=true` (set only after Firebase and database setup)
- `FIREBASE_SERVICE_ACCOUNT_JSON` (private JSON)
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_WEB_API_KEY`
- `FIREBASE_WEB_APP_ID`
- `FIREBASE_WEB_VAPID_KEY`

The last five are public Firebase web-app configuration. Generate the web push
certificate/public VAPID key in Firebase → Cloud Messaging → Web Push certificates.
All registered apps and the server service account must belong to the same project.
`NEXT_PUBLIC_SERVER_URL` should be `https://www.athariyya.online`.

## 4. Apply the additive Neon migration before deploying

The migration adds `notifications`, its admin document-lock relationship, and a
small `push_registration_limits` table for public web registration rate limiting.
It does not change any book data. Dev schema auto-sync is disabled (`push: false`)
so opening a local preview cannot silently modify the connected database schema.

Use a Neon preview branch first and back up the production branch before release.
With the intended DATABASE_URI and PAYLOAD_SECRET configured, from `admin` run:

```sh
npx payload migrate:status
npx payload migrate
```

Review the listed pending migrations first. The new migration is
`20260927_120000_notifications`. Deploy the admin code after it succeeds. The Notifications collection stays hidden until PUSH_NOTIFICATIONS_ENABLED=true, so an unconfigured deployment does not query the new tables. Do not
roll it back after sending notifications without retaining your send history.

## 5. Build mobile apps in Codemagic (build 1.0.0+9)

Provide your filled public push-config.json in the build workspace (for example,
through a Codemagic environment variable written to the file in a pre-build step).
Run before the Flutter build:

```sh
python3 scripts/configure_push.py push-config.json
```

Add this to your Flutter build arguments for both Android and iOS:

```text
--dart-define-from-file=push-config.json
```

The script writes the native Firebase resources used for cold-start delivery.
Android does not need an additional google-services Gradle plugin: the script
supplies its required string resources. The existing iOS embed phase copies the
Apple plist into the bundle. These generated config files are gitignored.
Without the config, the notification settings remain unavailable and the library
continues to work. iOS signing still requires an updated push-enabled profile.

## 6. Opt in and send a test

Install the new build on a test phone. Tap the bell in the library header, enable
announcements, and accept the operating system permission prompt. No launch-time
permission request is made. The toggle lets readers unsubscribe later.

For web, use HTTPS and tap the bell. Unsupported browsers may not permit web push.
iPhone/iPad web push requires a supported OS and a website installed to the Home
Screen; native iOS push works independently. Browser/device settings can suppress
notifications and delivery is not guaranteed to every subscriber.

Admin → Notifications → create title and message → Save → Preview and send.
The confirmation shows the saved content and explicitly states the audience is
ALL opted-in readers. Saving/editing never sends a message. There is no recall.

Use a separate Firebase project + Vercel preview + Neon branch for pre-release
push tests, so test messages cannot reach production subscribers.

Statuses: `draft` → `sending` → `accepted`. Accepted means FCM accepted the request,
not device-level delivery. An ambiguous response becomes `uncertain`; do not retry
blindly because some devices may already have received it. A killed server process
may leave `sending`; investigate before manually creating another announcement.
An atomic Neon claim prevents concurrent duplicate sends. The topic is public
announcements only: never include private reader information in broadcasts.

## Validation before release

- Permission denied: reading/audio remain usable, no forced prompt loop.
- Android/iPhone: foreground, background, locked screen, tap notification from a
  terminated app, refreshed token, disable/re-enable announcements.
- Foreground messages appear inside the app; background messages use system UI.
- Web: supported browser, permission denied, foreground message, background worker,
  click notification, unsubscribe, registration rate limit, storage unavailable.
- Admin: unauthenticated/cross-origin send denied; save does not send; two requests
  for one draft result in one Firebase send; missing credentials leave draft intact.
- Check Privacy Policy and App Store privacy/Play Data Safety answers against the
  final Firebase configuration. Policy text now describes optional push processing.

No real delivery was verified without a configured Firebase project and APNs key.
