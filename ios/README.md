# Social Brain for iOS

This is the native iOS 17+ SwiftUI application. Generate the Xcode project with
XcodeGen after installing full Xcode:

```bash
cd ios
xcodegen generate
open SocialBrain.xcodeproj
```

Before running, add the environment-specific `GoogleService-Info.plist` to
`SocialBrain/Resources` locally. It is intentionally ignored by Git. Configure
Sign in with Apple, Google Sign-In, App Check, Contacts, Speech, EventKit, and
the Firebase Functions region before attempting a production build.

The initial source establishes the local SwiftData model, encrypted Firestore
envelope, and navigation shell. Feature screens are progressively expanded
against the shared contract in `../shared/contracts`.
