# Firebase deployment

Create separate Firebase projects for development, staging, and production.
Do not commit `.firebaserc`, `google-services.json`, `GoogleService-Info.plist`,
or secrets.

Before deployment, enable Apple and Google authentication, configure App Check,
set the `GEMINI_API_KEY` Functions secret, and deploy from this directory.
Firestore only receives encrypted envelopes. The AI callable endpoint relays a
user-initiated prompt and does not persist request content.
