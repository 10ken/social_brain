# Social Memory Security & Privacy Framework

Privacy and trustworthiness are the primary pillars of **Social Memory**. This system is carefully structured to guarantee full data sovereignty and safe local-first storage.

## 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker"

Social Memory is positioned strictly as a **Private Memory Assistant for your social life**.
*   **Rule**: We **NEVER** frame the application as "an app that tracks your friends", as this evokes creeping social engineering, tracking, or trust violations.
*   **Design**: The application functions as an externalized, private personal brain, mirroring human memory.

## 2. Security Safeguards

### A. Local-First Database and Device Encryption
Each client keeps a local source of truth (Room on Android and SwiftData on iOS).
On iOS, imported capture bodies, attachments, and AI-analysis payloads are held
in authenticated encrypted files using a device-specific local key; SwiftData
keeps opaque references to those files. The current release does not offer
cross-device content synchronization. This is intentional: without a portable,
independently reviewed key-recovery design, a cloud transport could create a
false expectation that encrypted records can be read on another device. The
**Start Clean** action deletes local records, attachments, and local key material
so a person can safely begin again.

### B. Guarded AI Boundaries
*   **Proxy Pattern**: User prompts bypass direct decompilation risks. The Gemini key is held by an App-Check-protected Firebase Function and is never embedded in either mobile app.
*   **Limited Scope**: All Gemini prompts are localized. User-identifiable details are isolated, and raw data is strictly formatted into granular structured suggestions without any retention or persistent tracking on public LLM endpoints.

### C. Zero-Leak Sandbox Contacts Integration
*   **Explicit Import**: Contacts are parsed locally after consent. Imported
    details remain in the local app store; device contact identifiers never
    leave that device.
*   **Opt-In Direct Consent**: Importing contacts requires clear affirmation of
    the "Social Brain Privacy Promise" dialog before the app asks for runtime
    Android platform read permission (`READ_CONTACTS`).
*   **Complete Local Controls**: Users can add, review, and manage imported profiles securely, with imported records marked clearly with the native "Imported" badge.
