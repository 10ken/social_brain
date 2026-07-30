# Firebase deployment

Create separate Firebase projects for development, staging, and production.
Do not commit `.firebaserc`, `google-services.json`, `GoogleService-Info.plist`,
or secrets.

Before deployment, enable Apple and Google authentication, configure App Check,
set the `GEMINI_API_KEY` Functions secret, and deploy from this directory:

```bash
firebase functions:secrets:set GEMINI_API_KEY
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
firebase deploy
```

`generateAIContent` requires both a Firebase user and App Check. It accepts a
bounded text prompt plus an optional image, and validates structured AI output
before returning it. It does not write prompt or response content to Firestore.
It uses `gemini-3.6-flash` by default; set the non-secret `GEMINI_MODEL`
environment setting to use an approved deployment-specific model instead.

`deleteAccountData` is the only account-deletion callable. It requires Firebase
Authentication, App Check, and a Firebase ID token whose verified `auth_time`
is no more than five minutes old. It accepts no request payload, deletes legacy
Firestore and Storage data plus private AI rate-limit metadata, then deletes the
Firebase Auth user only after that cleanup succeeds. The obsolete
clean-slate callable is not deployed.

Firestore and Storage rules explicitly deny client record and attachment sync in
this release. Do not enable or advertise sync until a portable key-recovery
design is approved and independently reviewed.
