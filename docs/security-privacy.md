# Social Memory Security & Privacy Framework

Privacy and trustworthiness are the primary pillars of **Social Memory**. This system is carefully structured to guarantee full data sovereignty and safe local-first storage.

## 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker"

Social Memory is positioned strictly as a **Private Memory Assistant for your social life**.
*   **Rule**: We **NEVER** frame the application as "an app that tracks your friends", as this evokes creeping social engineering, tracking, or trust violations.
*   **Design**: The application functions as an externalized, private personal brain, mirroring human memory.

## 2. Security Safeguards

### A. Local-First Database and Encrypted Sync
Each client keeps a local source of truth (Room on Android and SwiftData on iOS). When a user enables multi-device sync, personal content is sent to Firebase only inside encrypted record envelopes. Routing metadata is retained solely to synchronize records and enforce ownership rules.

### B. Guarded AI Boundaries
*   **Proxy Pattern**: User prompts bypass direct decompilation risks. The Gemini key is held by an App-Check-protected Firebase Function and is never embedded in either mobile app.
*   **Limited Scope**: All Gemini prompts are localized. User-identifiable details are isolated, and raw data is strictly formatted into granular structured suggestions without any retention or persistent tracking on public LLM endpoints.

### C. Zero-Leak Sandbox Contacts Integration
*   **Explicit Import and Sync**: Contacts are parsed locally after consent. Imported details become encrypted CRM content only when the user has enabled account sync; device contact identifiers themselves never leave that device.
*   **Opt-In Direct Consent**: Initiating a sync requires clear affirmation of the "Social Brain Privacy Promise" dialog, detailing how and where data is used before asking for runtime Android platform read permission (`READ_CONTACTS`).
*   **Complete Local Controls**: Users can add, review, and manage imported profiles securely, with imported records marked clearly with the native "Imported" badge.
