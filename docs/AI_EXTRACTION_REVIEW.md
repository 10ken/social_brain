# AI Extraction & Review Workflow

In Social Memory, AI is a helper, not the master. Every piece of structured data suggestion derived from voice logs, pasted text, or screenshots must flow through a strict state verification pipeline.

---

## 1. The Core Lifecycle

The social memory ingestion pipeline consists of four major stages:

```
Capture ──► AI Extraction ──► Review Suggestions ──► Save Confirmed Items
```

1. **Capture**: The user speaks, paste text, or uploads a screenshot in the Prominent Action trigger.
2. **AI Extraction**: The on-device Gemini API analyzes the raw text, returning suggested entities (people, groups, relationships, memories, events, reminders).
3. **Review Suggestions**: Users view their suggestion list side-by-side with original captured transcripts.
4. **Save Confirmed Items**: Checked items are immediately committed to local database tables; ignored items are soft-discarded.

---

## 2. Ingestion State Enforcements

Suggested items are initialized into distinct confidence configurations:

| State | Background Tint | Significance |
|---|---|---|
| **Confirmed** | `#14B8A6` (15% tint) | Approved by the user. Commits with pristine relations. |
| **Suggested** | `#F59E0B` (15% tint) | Default state of newly parsed facts. Requires review. |
| **Needs Review**| `#B45309` (Solid) | Indicates critical ambiguity (e.g., date of "next Saturday"). |
| **Ignored** | `#263449` (Solid) | Bypassed. Discarded without database footprint. |
| **Error** | `#F43F5E` (15% tint) | Failed OCR/Transcription. |

---

## 3. Strict Rules Against Auto-Saving

To maintain full user control, privacy comfort, and trust:
1. **AI suggestions are NEVER auto-saved** directly into the final SQLite tables (`people`, `groups`, etc.).
2. The UI holds parsed suggestions inside a temporary caching column (`analyzed_json` on the `captures` table) or volatile screen states.
3. Every card clearly renders an **Evidence Block** (the exact excerpt or transcript line where the detail was found), enabling the user to edit or dismiss inaccuracies before final database validation.
