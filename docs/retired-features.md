# Removed features — 18 October 2026

Push announcements and in-PDF word search have been removed from the app and website. Library title search, local download notifications, background audio controls, bookmarks, reading progress, PDF scrolling and reader notices remain.

## Codemagic

Use a new build from this revision (version 1.0.0+13). Remove any pre-build call to `python3 scripts/configure_push.py` and the Flutter argument `--dart-define-from-file=push-config.json`. The old script is temporarily a harmless no-op so existing pre-build hooks do not fail. Normal signing configuration and other build arguments should remain.

The iOS target no longer requests aps-environment or Push Notifications. Its audio background mode remains. No Xcode or new push-capable profile is required for this revision.

## Deployment and existing installations

Deploy the website/admin and release updated Android/iOS builds. The admin collection and send/subscription endpoints are removed regardless of old environment variables. The website unsubscribes/unregisters its retired worker when readers revisit; the old worker URL also serves a retirement worker. Existing mobile installations keep their old code until updated.

Firebase/APNs account resources and hosted environment variables have not been changed remotely. Obsolete Firebase/push variables may be removed from Codemagic and Vercel. Do not revoke shared Apple distribution certificates or App Store Connect API keys: they are still needed for publishing.

The historical notifications migration is retained so existing migration history stays valid. No database tables or existing notification history are deleted; automatic schema push remains disabled. No new database migration is needed to remove the feature from the UI/API.

Ignored local Firebase downloads are not committed. Keep their ignore rules to avoid reintroducing them into Git.
