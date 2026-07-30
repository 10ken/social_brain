<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Social Brain

Social Brain is a local-first private memory assistant for people, events,
follow-ups, and reviewed captures. The Android app and the iOS 17+ SwiftUI
source live in this repository; Firebase only provides authenticated AI
processing. Cross-device content sync is deliberately disabled in the current
release because device-specific encryption keys are not portable between
Android and iOS.

## Android

Open the repository in Android Studio. Add a local `app/google-services.json`,
then configure Firebase Auth, App Check, and the Functions secret as described
in [`firebase/README.md`](firebase/README.md). AI is intentionally unavailable
until the user signs in and the Firebase project is configured.

## iOS

The native iOS source and its XcodeGen project definition are in
[`ios`](ios). It is designed for iOS 17+. Once full Xcode is available, run
`ios/Scripts/bootstrap.sh --local` to validate, generate, and resolve the
local-only scheme; Firebase credentials are only needed for the separate
Firebase scheme. See the setup and validation checklist in
[`ios/README.md`](ios/README.md).

## Development notes

- Do not commit Firebase plist/json configuration, secrets, generated build
  products, or dependency directories.
- On iOS, imported capture payloads and attachments are encrypted with a
  device-specific key. The in-app **Start Clean** action deletes local records,
  encrypted files, and encryption material.
- Firebase AI requests are user initiated and are not persisted by the app.
