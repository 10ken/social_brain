# Social Brain for iOS

This is the native iOS 17+ SwiftUI app. It is local-first: people, events,
memories, reminders, reviewed captures, and attachments stay on the device.
The app does not currently offer cross-device content sync because encryption
keys are device-specific.

## Bootstrap

Install full Xcode and XcodeGen, then generate the project and resolve the
exact Swift Package dependencies:

```bash
cd ios
./Scripts/bootstrap.sh --local
open SocialBrain.xcodeproj
```

`--local` is the safe default and does not require Firebase credentials. To
check the static project files without full Xcode, run:

```bash
./Scripts/bootstrap.sh --verify-only
```

The checked-in spec requires XcodeGen 2.45.4 or newer. CI intentionally uses
2.45.4 so generated target identifiers remain aligned with the checked-in test
plans.

## Configurations and schemes

| Configuration | Scheme | Runtime expectation |
| --- | --- | --- |
| `Debug-Local` / `Release-Local` | `SocialBrain-Local` | Launches without Firebase configuration. |
| `Debug-Firebase` | `SocialBrain-FirebaseDebug` | Requires the ignored staging Firebase plist and private xcconfig. |
| `Release-Firebase` | `SocialBrain-Release` | Production signing/App Attest configuration; requires real release credentials. |
| `Debug-Local` | `SocialBrain-UITests` | Uses in-memory SwiftData and fake device services for deterministic UI tests. |

Every target uses Swift 5.0 language mode with complete strict-concurrency
checking. The app target links only Firebase Core, Auth, Functions, App Check,
and Google Sign-In; Firestore and Storage are deliberately not linked.

## Firebase setup

Only prepare these files for a Firebase scheme or production build:

1. Copy the environment-specific `GoogleService-Info.plist` to
   `Config/Firebase/GoogleService-Info.plist`—never into `SocialBrain/Resources`.
2. Copy `Config/Firebase.local.xcconfig.example` to the ignored
   `Config/Firebase.local.xcconfig` and set `GOOGLE_REVERSED_CLIENT_ID` to the
   `REVERSED_CLIENT_ID` in the service plist. Set `FUNCTIONS_REGION` there when
   it differs from the non-secret default.
3. For device signing in either runtime, copy
   `Config/Developer.local.xcconfig.example` to the ignored
   `Config/Developer.local.xcconfig` and set `SOCIAL_BRAIN_DEVELOPMENT_TEAM`.
4. Run `./Scripts/bootstrap.sh --firebase` to verify the Firebase pair before
   building.

Both files are ignored and must never be committed. Configure Firebase Auth
with Sign in with Apple and Google, an iOS App Check provider, and the Firebase
Functions region before enabling protected AI actions.

The app target excludes any `GoogleService-Info.plist` under its Resources
folder. Its Firebase-only build phase copies the configured plist into the
product bundle only when `SOCIAL_BRAIN_REQUIRE_FIREBASE_CONFIG=YES`, so Local
builds cannot auto-configure Firebase from a developer’s staging plist.

## Tests

The Local and Firebase schemes each reference a committed test plan. The Local
plan is the CI default and runs both `SocialBrainTests` and
`SocialBrainUITests`. The unit-test bundle also copies the canonical valid and
invalid AI extraction fixtures from `shared/contracts/v1/fixtures`.

With a booted simulator, a Local test run looks like:

```bash
xcodebuild test \
  -project SocialBrain.xcodeproj \
  -scheme "SocialBrain-Local" \
  -testPlan Local \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Dependency resolution and `Package.resolved`

The project pins its direct packages exactly in both `project.yml` and the
tracked `Package.resolved`: Firebase `12.17.0`
(`33a468adfdb75b53f05a37e7c886ca7c962b5c17`) and Google Sign-In `9.1.0`
(`913b4005ea26aebe1c97d54e35ad82a515924c71`). XcodeGen defines package
references but does not resolve them, so `Scripts/bootstrap.sh` copies this
seed lockfile into the generated workspace before resolving the full transitive
closure with Xcode. CI then disables automatic package resolution for the build
and test phases, and uploads Xcode's expanded workspace `Package.resolved` as
an artifact for review and committing when it changes. Keep the spec and seed
lockfile together whenever a direct package pin changes.

## Privacy and signing

`Info.plist` documents Contacts, Photos, Speech Recognition, Microphone, and
full/write-only Calendar access, defines the Google Sign-In URL scheme and
Functions/App Check values from the active xcconfig, and uses the asset-backed
launch screen. The entitlement file enables Sign in with Apple and complete
default data protection. Its privacy manifest declares the app-local
UserDefaults and app-container file-timestamp reasons used by the app. Configure
an Apple development team and signing assets locally for device or archive
builds.
