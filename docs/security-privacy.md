# Social Memory Security & Privacy Framework

Privacy and trustworthiness are the primary pillars of **Social Memory**. This system is carefully structured to guarantee full data sovereignty and safe local-first storage.

## 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker"

Social Memory is positioned strictly as a **Private Memory Assistant for your social life**.
*   **Rule**: We **NEVER** frame the application as "an app that tracks your friends", as this evokes creeping social engineering, tracking, or trust violations.
*   **Design**: The application functions as an externalized, private personal brain, mirroring human memory.

## 2. Security Safeguards

### A. Local-First SQLite Database
Every record, individual note, group circle alignment, and transcribed action remains 100% on the user's phone, encrypted and safely managed in local SQLite structures through Android Room.

### B. Guarded AI Boundaries
*   **Proxy Pattern**: For production implementations, user prompts bypass direct decompilation risks. Direct API keys are shielded behind secure cloud proxy gateways.
*   **Limited Scope**: All Gemini prompts are localized. User-identifiable details are isolated, and raw data is strictly formatted into granular structured suggestions without any retention or persistent tracking on public LLM endpoints.

### C. Zero-Leak Sandbox Contacts Integration
*   **Device-Local Syncing Only**: The dynamic contacts directory integration operates fully within the offline Android Application Sandbox. Contact lists are parsed locally on the SQLite interface, completely blocking any central server uploads.
*   **Opt-In Direct Consent**: Initiating a sync requires clear affirmation of the "Social Brain Privacy Promise" dialog, detailing how and where data is used before asking for runtime Android platform read permission (`READ_CONTACTS`).
*   **Complete Local Controls**: Users can add, review, and manage imported profiles securely, with imported records marked clearly with the native "Imported" badge.
