# Social Brain architecture

Social Brain is a local-first private memory assistant for people, events,
follow-ups, and reviewed captures.

## Client architecture

Android uses Jetpack Compose with an MVVM-style `AppViewModel` and Room.
iOS uses SwiftUI, SwiftData, and focused local services. Each client owns its
local source of truth; neither reads another device's private record store.

```
┌──────────────────────────────────────────────────────────┐
│ Android: Jetpack Compose · iOS: SwiftUI                  │
└───────────────────────────┬──────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────┐
│ View state, capture review, calendar and permission flows │
└───────────────┬─────────────────────────────┬────────────┘
                │                             │
┌───────────────▼──────────────┐  ┌───────────▼───────────┐
│ Local store and device key   │  │ Authenticated AI proxy │
│ Room / SwiftData / encrypted │  │ Firebase Auth +        │
│ attachments                  │  │ App Check + Functions  │
└──────────────────────────────┘  └───────────────────────┘
```

Local records include people, groups, memberships, relationships, events,
captures, memories, and reminders. On iOS, attachment bytes are encrypted with
a device-bound key before being stored in the application-support directory.
Every AI-derived item stays pending until the user explicitly reviews it.

## Cloud boundary

The Firebase callable endpoint is the only supported cloud boundary for AI
requests. It requires a signed-in Firebase user and App Check, owns the Gemini
credential, accepts bounded text plus an optional image, and does not persist
prompt or response content. The canonical structured extraction result is
defined by `shared/contracts/v1/ai-extraction.schema.json` and uses camelCase
JSON fields.

## Sync status

Cross-device content synchronization is intentionally disabled. Current local
encryption keys are device specific, so Firestore envelope code is retained only
as an isolated, future transport component. The user interface does not upload,
download, or claim to synchronize personal records until a portable key-recovery
design has been approved and independently reviewed.
