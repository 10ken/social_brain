# Social Brain for iOS

This is the native iOS 17+ SwiftUI application. It is local-first: people,
events, memories, reminders, reviewed captures, and attachments stay on the
device. The current release intentionally does **not** expose cross-device
content sync because its encryption keys are device-specific.

## Setup after Xcode installation

Generate the Xcode project with XcodeGen:

```bash
cd ios
xcodegen generate
open SocialBrain.xcodeproj
```

Before running, copy the Firebase configuration supplied for the selected
environment to `SocialBrain/Resources/GoogleService-Info.plist`. A deliberately
nonfunctional field reference is available as
`GoogleService-Info.plist.example`; never commit the real file.

Configure the following before a production build:

1. Firebase Auth with Sign in with Apple and Google enabled.
2. An iOS App Check provider and the Firebase Functions region.
3. The Google Sign-In URL scheme using the real reversed client ID.
4. Apple Signing, Contacts, Photos, Speech, Microphone, and EventKit access.

Until Firebase configuration is present, the app remains usable for local
records while cloud AI actions show a configuration/sign-in explanation.

## Validation

Once Xcode is available, run the `SocialBrainTests` scheme and follow the iOS
checklist in `../docs/qa-test-plan.md`. This repository intentionally does not
contain an Xcode project, signing assets, App Check credentials, or a Firebase
plist, so a simulator build before those prerequisites are installed is not a
meaningful readiness signal.

The shared contracts in `../shared/contracts` govern AI extraction results. The
Firestore envelope code is retained and tested as an isolated future transport
component, but UI synchronization is disabled pending a portable key-recovery
design.
