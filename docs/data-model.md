# Social Memory Relational Data Model

Social Memory is backed by a relational SQLite database configured through Android Room to ensure local-first storage and 100% privacy compliance. This document details the tables, schemas, and relational map constraints.

```
                  ┌──────────────┐
                  │    Groups    │
                  └──────┬───────┘
                         │ 1
                         │
                         │ *
                  ┌──────▼───────┐
                  │ GroupMembers │
                  └──────▲───────┘
                         │ *
                         │
                         │ 1
┌─────────────┐   ┌──────┴───────┐   ┌──────────────┐
│  Reminders  ├─*─┤    People    ├─*─┤   Memories   │
└─────────────┘   └──────┬───────┘   └──────────────┘
                         │ 1
                         │
                         │ *
                  ┌──────▼───────┐
                  │ Relationships│
                  └──────────────┘
```

## 1. Dimensional / Entity Tables

### `people` (Individual profiles)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `full_name`: `TEXT` (Non-null)
*   `nickname`: `TEXT` (Nullable)
*   `birthday`: `TEXT` (Nullable) - Format: `YYYY-MM-DD`
*   `location`: `TEXT` (Nullable)
*   `notes`: `TEXT` (Nullable) - Custom biographical summary details

### `groups` (Circles of friends / communities)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `group_name`: `TEXT` (Non-null)
*   `description`: `TEXT` (Nullable)

### `group_members_join` (Relational cross-reference join mapping)
*   `group_id`: `INTEGER` (Foreign key to `groups.id` on cascade delete)
*   `person_id`: `INTEGER` (Foreign key to `people.id` on cascade delete)
*   *Composite Primary Key*: `(group_id, person_id)`

---

## 2. Fact & Observation Observation Tables

### `memories` (Granular updates, facts, observations, prefered choices)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `content`: `TEXT` (Non-null) - Raw fact parsed
*   `person_id`: `INTEGER` (Nullable, ForeignKey to `people.id`)
*   `group_id`: `INTEGER` (Nullable, ForeignKey to `groups.id`)
*   `event_id`: `INTEGER` (Nullable)
*   `created_at`: `INTEGER` (Non-null) - Unix Epoch millis
*   `memory_type`: `TEXT` (Non-null) - E.g., `life_update`, `preference`, `fact`
*   `confidence_state`: `TEXT` (Non-null) - `confirmed` / `suggested`

### `relationships` (Interpersonal connections suggested by Gemini)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `person_a_id`: `INTEGER` (Non-null, ForeignKey to `people.id`)
*   `person_b_id`: `INTEGER` (Non-null, ForeignKey to `people.id`)
*   `relationship_type`: `TEXT` (Non-null) - E.g., `spouse`, `friend`, `coordinator`

### `social_events` (Events, dinners, recurring meetups)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `title`: `TEXT` (Non-null)
*   `start_time`: `INTEGER` (Nullable) - Unix Epoch millis
*   `location`: `TEXT` (Nullable)
*   `group_id`: `INTEGER` (Nullable, ForeignKey to `groups.id`)
*   `confidence_state`: `TEXT` (Non-null) - `confirmed` / `suggested`

### `event_attendees_join` (People linked to specific events)
*   `event_id`: `INTEGER` (Foreign key to `social_events.id`)
*   `person_id`: `INTEGER` (Foreign key to `people.id`)
*   *Composite Primary Key*: `(event_id, person_id)`

### `reminders` (Callbacks and follow-up activities)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `title`: `TEXT` (Non-null) - Task detail
*   `dueDate`: `INTEGER` (Nullable) - Unix Epoch millis for task deadlines
*   `completed`: `INTEGER` (Non-null, boolean representation `0` / `1`)
*   `personId`: `INTEGER` (Nullable, ForeignKey to `people.id` for callbacks)
*   `createdAt`: `INTEGER` (Non-null) - Unix epoch millis of task creation

---

## 3. Capture & Logging Cache

### `captures` (Immutable history logs of user notes, transcriptions, or chat attachments)
*   `id`: `INTEGER` (Primary Key, AutoGenerate)
*   `type`: `TEXT` (Non-null) - `text` / `screenshot` / `voice`
*   `raw_content`: `TEXT` (Non-null)
*   `analyzed_json`: `TEXT` (Nullable) - Structuring extraction suggestions cache
*   `processed`: `INTEGER` (Non-null, boolean)
*   `created_at`: `INTEGER` (Non-null)
