# Graph Report - .  (2026-07-28)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 769 nodes · 1174 edges · 67 communities (52 shown, 15 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5231d1ad`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- MainAppScreens.kt
- RecordType
- ai-extraction.schema.json
- String
- AppContainerView.swift
- ContentCipher.swift
- AppDatabase
- AppRepository
- AppViewModel
- ConfidenceState
- AppScreen
- 2. Reusable Modular Architecture (11 Components)
- package.json
- Flow
- SocialEvent
- RecordType
- Social Memory Changelog
- Reminder
- Memory
- Person
- 2. Fact & Observation Observation Tables
- .generateFallback
- enum
- Component Guidelines
- Relationship
- 1. Schema Specifications
- compilerOptions
- required
- index.js
- FirebaseAppDelegate
- 1. Color Palette Tokens
- Social Memory UX/UI Design
- properties
- Social Memory QA & Test Plan
- Social Memory UX/UI Guidelines
- AesGcmCipher
- 2. Security Safeguards
- index.ts
- .prepopulateDataIfEmpty
- Entities.kt
- record-envelope.schema.json
- ExampleRobolectricTest
- AI Extraction & Review Workflow
- Social Memory Architectures
- Calendar Heatmap UX
- type
- ciphertext
- nonce
- applet/replace.js
- app/replace.js
- SecureAiGateway
- revision
- ExampleInstrumentedTest
- ExampleUnitTest
- AesGcmCipherTest
- Run and deploy your AI Studio app
- deviceId
- keyVersion
- schemaVersion
- firebase/README.md
- ios/README.md
- contracts/README.md

## God Nodes (most connected - your core abstractions)
1. `AppViewModel` - 81 edges
2. `AppRepository` - 52 edges
3. `Person` - 34 edges
4. `Memory` - 26 edges
5. `SocialEvent` - 25 edges
6. `Reminder` - 25 edges
7. `AppScreen` - 20 edges
8. `Group` - 19 edges
9. `Relationship` - 18 edges
10. `MainAppContainer()` - 18 edges

## Surprising Connections (you probably didn't know these)
- `ReviewExtractionScreen()` --calls--> `ExtractionResult`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/api/GeminiClient.kt
- `CalendarScreen()` --calls--> `calendarCellColors()`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/ui/theme/Color.kt
- `.body` --calls--> `AppContainerView`  [INFERRED]
  ios/SocialBrain/App/SocialBrainApp.swift → ios/SocialBrain/App/AppContainerView.swift
- `.body` --calls--> `PersonRecord`  [EXTRACTED]
  ios/SocialBrain/App/AppContainerView.swift → ios/SocialBrain/Models/LocalRecords.swift
- `MainActivity` --references--> `AppViewModel`  [EXTRACTED]
  app/src/main/java/com/example/MainActivity.kt → app/src/main/java/com/example/ui/AppViewModel.kt

## Import Cycles
- None detected.

## Communities (67 total, 15 thin omitted)

### Community 0 - "MainAppScreens.kt"
Cohesion: 0.12
Nodes (39): AnnotatedString, AddEventScreen(), AddGroupScreen(), AddPersonScreen(), AskScreen(), BottomNavBar(), Bullet, CalendarScreen() (+31 more)

### Community 1 - "RecordType"
Cohesion: 0.08
Nodes (32): CaseIterable, Codable, Comparable, EncryptedRecordEnvelope, FirebaseAuth, FirebaseFirestore, Firestore, Int (+24 more)

### Community 2 - "ai-extraction.schema.json"
Cohesion: 0.05
Nodes (38): confidenceState, events, evidence, memories, needs_review, people, relationships, reminders (+30 more)

### Community 3 - "String"
Cohesion: 0.17
Nodes (21): AnyObject, Date, Foundation, Identifiable, HomeView, .body, .reminders, AppSettingsRecord (+13 more)

### Community 4 - "AppContainerView.swift"
Cohesion: 0.10
Nodes (27): App, Hashable, AddPersonView, .body, AppContainerView, .body, AppTab, calendar (+19 more)

### Community 5 - "ContentCipher.swift"
Cohesion: 0.09
Nodes (20): CryptoKit, Error, ContentCipher, ContentCipherError, invalidCombinedCiphertext, invalidKeyLength, keychain, KeychainStore (+12 more)

### Community 6 - "AppDatabase"
Cohesion: 0.09
Nodes (10): AppDatabase, getDatabase(), migrate(), AppSettingsDao, CaptureDao, Capture, AppSettingsEntity, Context (+2 more)

### Community 7 - "AppRepository"
Cohesion: 0.13
Nodes (3): AppRepository, Capture, Flow

### Community 8 - "AppViewModel"
Cohesion: 0.13
Nodes (5): AndroidViewModel, AppViewModel, Capture, Flow, StateFlow

### Community 9 - "ConfidenceState"
Cohesion: 0.11
Nodes (16): MainActivity, calendarCellColors(), confidenceColors(), ConfidenceState, CONFIRMED, ERROR, IGNORED, NEEDS_REVIEW (+8 more)

### Community 10 - "AppScreen"
Cohesion: 0.10
Nodes (17): AddEvent, AddGroup, AddPerson, AppScreen, Ask, Calendar, ChatMessage, Communities (+9 more)

### Community 11 - "2. Reusable Modular Architecture (11 Components)"
Cohesion: 0.10
Nodes (20): 1. Required Structural Layout, 2. Reusable Modular Architecture (11 Components), 3. Interaction & State Safeguards, Home Page (Weekly Review) Design Specification, I. `BottomNavBar`, I. Progress Bar Removal, II. Duplicate Event Collapsing, II. `HomeHeader` (+12 more)

### Community 12 - "package.json"
Cohesion: 0.10
Nodes (20): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google/generative-ai, devDependencies, typescript (+12 more)

### Community 13 - "Flow"
Cohesion: 0.14
Nodes (3): GroupDao, Flow, Group

### Community 14 - "SocialEvent"
Cohesion: 0.14
Nodes (3): SocialEventDao, EventAttendeeRef, SocialEvent

### Community 15 - "RecordType"
Cohesion: 0.12
Nodes (15): EncryptedRecordEnvelope, HybridRevision, Comparable, parse(), RecordType, CAPTURE, EVENT, EVENT_ATTENDEE (+7 more)

### Community 16 - "Social Memory Changelog"
Cohesion: 0.12
Nodes (16): Added, Added, Added, Added, Added, Added, Added, Changed (+8 more)

### Community 20 - "2. Fact & Observation Observation Tables"
Cohesion: 0.14
Nodes (13): 1. Dimensional / Entity Tables, 2. Fact & Observation Observation Tables, 3. Capture & Logging Cache, `captures` (Immutable history logs of user notes, transcriptions, or chat attachments), `event_attendees_join` (People linked to specific events), `group_members_join` (Relational cross-reference join mapping), `groups` (Circles of friends / communities), `memories` (Granular updates, facts, observations, prefered choices) (+5 more)

### Community 21 - ".generateFallback"
Cohesion: 0.27
Nodes (8): ExtractedEvent, ExtractedMemory, ExtractedPerson, ExtractedRelationship, ExtractedReminder, ExtractionResult, GeminiClient, Bitmap

### Community 22 - "enum"
Cohesion: 0.15
Nodes (13): capture, event, eventAttendee, group, groupMembership, memory, person, relationship (+5 more)

### Community 23 - "Component Guidelines"
Cohesion: 0.17
Nodes (11): 1. Action Triggers & Buttons, 2. Text Indicators & Chips, 3. Card Elements & Selections, 4. Temporary States & Empty Content, Component Guidelines, Confirmed / Active Chips, Danger Buttons (Delete / Clear), Primary Buttons (Confirm / Save) (+3 more)

### Community 25 - "1. Schema Specifications"
Cohesion: 0.18
Nodes (10): 1. Schema Specifications, 2. Evidence Link Requirements, 3. Data Archival & Cleanup Rules, `groups` (Social Circles & Communities), `memories` (Facts & Biographical Milestones), `people` (Biographical Profiles), Relational Data Models, `relationships` (Interpersonal Links) (+2 more)

### Community 26 - "compilerOptions"
Cohesion: 0.18
Nodes (10): compilerOptions, esModuleInterop, module, moduleResolution, outDir, skipLibCheck, strict, target (+2 more)

### Community 27 - "required"
Cohesion: 0.18
Nodes (11): ciphertext, deleted, deviceId, id, keyVersion, nonce, recordType, revision (+3 more)

### Community 28 - "index.js"
Cohesion: 0.20
Nodes (7): app_1, firestore_1, geminiApiKey, generative_ai_1, https_1, params_1, storage_1

### Community 29 - "FirebaseAppDelegate"
Cohesion: 0.20
Nodes (8): FirebaseCore, FirebaseAppDelegate, Any, Bool, NSObject, UIApplication, UIApplicationDelegate, UIKit

### Community 30 - "1. Color Palette Tokens"
Cohesion: 0.22
Nodes (8): 1. Color Palette Tokens, 2. Kotlin / Jetpack Compose Token Definitions, 3. Contrast Verification Map, Core Canvas Surfaces, Design Tokens, Global Navigation Triggers, Semantic Highlight Accents, Text & Readable Elements

### Community 31 - "Social Memory UX/UI Design"
Cohesion: 0.22
Nodes (8): 1. Aesthetic Identity & Theme, 2. Low-Friction Capture Flow, 3. High Accessibility & Touch Ergonomics, 4. Chronological Heatmap Social Calendar UX, 5. Group & Circle Name Uniqueness Validation, Social Memory UX/UI Design, Theme Spec (Default: Light Mode):, Theme Toggling:

### Community 32 - "properties"
Cohesion: 0.22
Nodes (9): type, format, type, properties, deleted, id, updatedAtMs, minimum (+1 more)

### Community 33 - "Social Memory QA & Test Plan"
Cohesion: 0.25
Nodes (7): 1. Testing Frameworks Utilized, 2. Test Execution Details, 3. Manual QA Checklist (Calendar UI), Calendar View Layout and Heatmaps, Entity and Network Relational Consistency, Social Memory QA & Test Plan, Verified Test Outputs:

### Community 34 - "Social Memory UX/UI Guidelines"
Cohesion: 0.25
Nodes (7): 1. Brand Identity & Visual Vibe, 2. Appearance & Theme Toggling, 3. Global Navigation Rules, 4. Dynamic Heatmap Calendar, 5. AI-Review Flow, 6. Accessibility & Contrast Safeguards, Social Memory UX/UI Guidelines

### Community 35 - "AesGcmCipher"
Cohesion: 0.48
Nodes (3): AesGcmCipher, Ciphertext, ByteArray

### Community 36 - "2. Security Safeguards"
Cohesion: 0.29
Nodes (6): 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker", 2. Security Safeguards, A. Local-First Database and Encrypted Sync, B. Guarded AI Boundaries, C. Zero-Leak Sandbox Contacts Integration, Social Memory Security & Privacy Framework

### Community 37 - "index.ts"
Cohesion: 0.29
Nodes (4): AIRequest, geminiApiKey, generateAIContent, resetEncryptedContent

### Community 40 - "record-envelope.schema.json"
Cohesion: 0.33
Nodes (5): additionalProperties, $id, $schema, title, type

### Community 42 - "AI Extraction & Review Workflow"
Cohesion: 0.40
Nodes (4): 1. The Core Lifecycle, 2. Ingestion State Enforcements, 3. Strict Rules Against Auto-Saving, AI Extraction & Review Workflow

### Community 43 - "Social Memory Architectures"
Cohesion: 0.40
Nodes (4): 1. High-Level Architectural Pattern, 2. API Service Integration, Components, Social Memory Architectures

### Community 44 - "Calendar Heatmap UX"
Cohesion: 0.40
Nodes (4): 1. Visual Heatmap Density Layout, 2. Interaction & Dynamic Filtering, Calendar Heatmap UX, Selected Highlight

### Community 45 - "type"
Cohesion: 0.40
Nodes (5): integer, null, minimum, type, deletedAtMs

### Community 46 - "ciphertext"
Cohesion: 0.40
Nodes (5): contentEncoding, maxLength, minLength, type, ciphertext

### Community 47 - "nonce"
Cohesion: 0.40
Nodes (5): contentEncoding, maxLength, minLength, type, nonce

### Community 48 - "applet/replace.js"
Cohesion: 0.50
Nodes (3): content, fs, replacements

### Community 49 - "app/replace.js"
Cohesion: 0.50
Nodes (3): content, fs, replacements

### Community 51 - "revision"
Cohesion: 0.50
Nodes (4): revision, maxLength, minLength, type

### Community 57 - "deviceId"
Cohesion: 0.67
Nodes (3): format, type, deviceId

### Community 58 - "keyVersion"
Cohesion: 0.67
Nodes (3): minimum, type, keyVersion

### Community 59 - "schemaVersion"
Cohesion: 0.67
Nodes (3): schemaVersion, const, type

## Knowledge Gaps
- **262 isolated node(s):** `fs`, `content`, `replacements`, `fs`, `content` (+257 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppViewModel` connect `AppViewModel` to `MainAppScreens.kt`, `AppDatabase`, `Entities.kt`, `AppRepository`, `ConfidenceState`, `AppScreen`, `.prepopulateDataIfEmpty`, `Flow`, `SocialEvent`, `Reminder`, `Memory`, `Person`, `.saveConfirmedSuggestions`, `Relationship`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `AppRepository` connect `AppRepository` to `AppDatabase`, `Entities.kt`, `AppViewModel`, `Flow`, `SocialEvent`, `Reminder`, `Memory`, `Person`, `Relationship`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `Person` connect `Person` to `MainAppScreens.kt`, `.prepopulateDataIfEmpty`, `AppRepository`, `Entities.kt`, `AppViewModel`, `ExampleRobolectricTest`, `Flow`, `SocialEvent`, `.generateFallback`, `.saveConfirmedSuggestions`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **What connects `fs`, `content`, `replacements` to the rest of the system?**
  _262 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `MainAppScreens.kt` be split into smaller, more focused modules?**
  _Cohesion score 0.12307692307692308 - nodes in this community are weakly interconnected._
- **Should `RecordType` be split into smaller, more focused modules?**
  _Cohesion score 0.08205128205128205 - nodes in this community are weakly interconnected._
- **Should `ai-extraction.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._