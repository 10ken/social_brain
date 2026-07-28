# Relational Data Models

This document outlines the detailed relational database parameters of **Social Memory**. Every fact, person profile, event, and checklist activity is persisted locally in SQLite through Android Room.

---

## 1. Schema Specifications

### `people` (Biographical Profiles)
- `id`: `INTEGER` (Primary Key, AutoGenerate)
- `fullName`: `TEXT` (Non-null)
- `nickname`: `TEXT` (Nullable)
- `birthday`: `TEXT` (Nullable) - Format: `YYYY-MM-DD`
- `location`: `TEXT` (Nullable)
- `notes`: `TEXT` (Nullable)
- `phoneNumber`: `TEXT` (Nullable)
- `email`: `TEXT` (Nullable)
- `isImported`: `INTEGER` (Non-null, boolean representation `0` / `1`)
- `contactIdOnDevice`: `TEXT` (Nullable)
- `createdAt`: `INTEGER` (Non-null)

### `groups` (Social Circles & Communities)
- `id`: `INTEGER` (Primary Key, AutoGenerate)
- `groupName`: `TEXT` (Non-null, **UNIQUE constraint**)
- `description`: `TEXT` (Nullable)
- `createdAt`: `INTEGER` (Non-null)

### `memories` (Facts & Biographical Milestones)
- `id`: `INTEGER` (Primary Key, AutoGenerate)
- `content`: `TEXT` (Non-null)
- `personId`: `INTEGER` (Nullable, ForeignKey to `people.id`)
- `groupId`: `INTEGER` (Nullable, ForeignKey to `groups.id`)
- `eventId`: `INTEGER` (Nullable, ForeignKey to `social_events.id`)
- `memoryType`: `TEXT` (Non-null) - `life_update`, `preference`, `fact`
- `sourceId`: `INTEGER` (Nullable, ForeignKey to `captures.id`) - original capture link
- `evidence_text`: `TEXT` (Nullable) - source citation/OCR slice
- `confidenceState`: `TEXT` (Non-null) - `confirmed` / `suggested` / `needs_review` / `ignored`
- `archived`: `INTEGER` (Non-null, boolean representation `0` / `1`) - soft-hiding old facts
- `createdAt`: `INTEGER` (Non-null)

### `relationships` (Interpersonal Links)
- `id`: `INTEGER` (Primary Key, AutoGenerate)
- `personAId`: `INTEGER` (Non-null, ForeignKey to `people.id`)
- `personBId`: `INTEGER` (Non-null, ForeignKey to `people.id`)
- `relationshipType`: `TEXT` (Non-null)
- `confidenceState`: `TEXT` (Non-null) - `confirmed` / `suggested` / `needs_review` / `ignored` (defaults to `needs_review`)
- `sourceId`: `INTEGER` (Nullable, ForeignKey to `captures.id`) - original capture link
- `evidence_text`: `TEXT` (Nullable) - citation quote
- `notes`: `TEXT` (Nullable)
- `createdAt`: `INTEGER` (Non-null)

### `social_events` (Events & Gatherings)
- `id`: `INTEGER` (Primary Key, AutoGenerate)
- `title`: `TEXT` (Non-null)
- `startTime`: `INTEGER` (Nullable) - Unix Epoch millis
- `endTime`: `INTEGER` (Nullable)
- `location`: `TEXT` (Nullable)
- `groupId`: `INTEGER` (Nullable, ForeignKey to `groups.id`)
- `sourceId`: `INTEGER` (Nullable, ForeignKey to `captures.id`) - original capture link
- `evidence_text`: `TEXT` (Nullable) - original text segment
- `date_text`: `TEXT` (Nullable) - raw extracted words (e.g., "next Saturday")
- `confidenceState`: `TEXT` (Non-null) - `confirmed` / `suggested` / `needs_review` / `ignored`

### `reminders` (Actionable Callbacks)
- `id`: `INTEGER` (Primary Key)
- `title`: `TEXT` (Non-null)
- `dueDate`: `INTEGER` (Nullable) - Unix Epoch millis
- `completed`: `INTEGER` (Non-null, Boolean)
- `personId`: `INTEGER` (Nullable, ForeignKey to `people.id`)
- `groupId`: `INTEGER` (Nullable, ForeignKey to `groups.id`)
- `sourceId`: `INTEGER` (Nullable, ForeignKey to `captures.id`)
- `evidence_text`: `TEXT` (Nullable)
- `confidenceState`: `TEXT` (Non-null) - `confirmed` / `suggested` / `needs_review`
- `archived`: `INTEGER` (Non-null, Boolean)
- `createdAt`: `INTEGER` (Non-null)

---

## 2. Evidence Link Requirements

To guarantee high context transparency:
- Extracted facts cannot exist without a matching `sourceId` pointing back to the original text, transcript, or screenshot capture.
- If a user opens a suggestion, the card must render the raw captured sentence (`rawContent`/`evidence_text`) so they can confirm how the fact was derived before clicking **Save**.

---

## 3. Data Archival & Cleanup Rules

- Deleting a `Person` cascade-deletes their relationships and memberships, but marks their linked memories and logs as `person_id = null` rather than erasing key historical notes.
- Instead of permanently hard-deleting items like historical events or callback checks, we apply `archived = 1` to hide them from current timeline views, allowing historical graphs to preserve integrity.
