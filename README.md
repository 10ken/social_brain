<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/c640fc18-446f-492f-80a4-8f7f7de4206a

## Run Locally

**Prerequisites:**  [Android Studio](https://developer.android.com/studio)


1. Open Android Studio
2. Select **Open** and choose the directory containing this project
3. Allow Android Studio to fix any incompatibilities as it imports the project.
4. Create a Firebase Android app for `com.aistudio.socialmemory.pcrzml` and place its generated `google-services.json` in `app/` (the file is intentionally ignored by Git).
5. Deploy the Functions in [`firebase`](firebase), including the `GEMINI_API_KEY` secret. The mobile app never contains this key.
6. Enable Google and Apple authentication, Firestore, Storage, and App Check in the Firebase project.
7. Remove this line from the app's `build.gradle.kts` file: `signingConfig = signingConfigs.getByName("debugConfig")` if you do not have the repository debug keystore.
8. Run the app on an emulator or physical device and sign in before using AI features.
