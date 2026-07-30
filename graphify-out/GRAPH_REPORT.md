# Graph Report - social_brain  (2026-07-28)

## Corpus Check
- 81 files · ~61,876 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1375 nodes · 2490 edges · 90 communities (82 shown, 8 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 175 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `97090797`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- MainAppScreens.kt
- RecordType
- ai-extraction.schema.json
- SocialEventRecord
- CommunityViews.swift
- .generateKey
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
- CalendarAuthorizationState
- 2. Fact & Observation Observation Tables
- AiAccessState
- enum
- Component Guidelines
- Relationship
- 1. Schema Specifications
- compilerOptions
- required
- LocalEncryptedContentStore
- .application
- 1. Color Palette Tokens
- Social Memory UX/UI Design
- properties
- Social Memory QA & Test Plan
- Social Memory UX/UI Guidelines
- AesGcmCipher
- 2. Security Safeguards
- aiContract.ts
- CaptureComposerView
- Equatable
- record-envelope.schema.json
- CaptureRecord
- AI Extraction & Review Workflow
- Social Brain architecture
- Calendar Heatmap UX
- type
- ciphertext
- nonce
- applet/replace.js
- app/replace.js
- String
- revision
- ExampleInstrumentedTest
- GroupRecord
- ExampleUnitTest
- AesGcmCipherTest
- SocialEventEditorView
- deviceId
- View
- .envelope
- Social Brain
- PersonRecord
- contracts/README.md
- Foundation
- ReminderRecord
- properties
- enum
- $defs
- AuthenticationStateStore.swift
- AuthenticationStateStore
- AppCheckState
- CaptureKind
- InMemoryContentKeyProvider
- required
- confidenceState
- properties
- AuthenticationAndAIStatusView
- ai-contract.test.js
- RecallWorkspaceView
- .baseQuery
- optionalText
- AuthenticationState
- parseTextToBlocks
- ExtractionContractTest
- name
- id

## God Nodes (most connected - your core abstractions)
1. `AppViewModel` - 84 edges
2. `AppRepository` - 52 edges
3. `PersonRecord` - 36 edges
4. `Person` - 34 edges
5. `CaptureRecord` - 32 edges
6. `Memory` - 26 edges
7. `LocalEncryptedContentStore` - 26 edges
8. `SocialEvent` - 25 edges
9. `Reminder` - 25 edges
10. `GroupRecord` - 24 edges

## Surprising Connections (you probably didn't know these)
- `ReviewExtractionScreen()` --calls--> `ExtractionResult`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/api/GeminiClient.kt
- `CalendarScreen()` --calls--> `calendarCellColors()`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/ui/theme/Color.kt
- `.body` --calls--> `AppContainerView`  [INFERRED]
  ios/SocialBrain/App/SocialBrainApp.swift → ios/SocialBrain/App/AppContainerView.swift
- `.body` --calls--> `CaptureWorkspaceView`  [INFERRED]
  ios/SocialBrain/App/AppContainerView.swift → ios/SocialBrain/Views/CaptureViews.swift
- `.body` --calls--> `HomeWorkspaceView`  [INFERRED]
  ios/SocialBrain/App/AppContainerView.swift → ios/SocialBrain/Views/HomeAndRecordsViews.swift

## Import Cycles
- None detected.

## Communities (90 total, 8 thin omitted)

### Community 0 - "MainAppScreens.kt"
Cohesion: 0.17
Nodes (31): AnnotatedString, AddEventScreen(), AddGroupScreen(), AddPersonScreen(), AiAccessNotice(), AskScreen(), BottomNavBar(), CalendarScreen() (+23 more)

### Community 1 - "RecordType"
Cohesion: 0.06
Nodes (42): App, CaseIterable, Codable, Comparable, Hashable, AppContainerView, AppTab, calendar (+34 more)

### Community 2 - "ai-extraction.schema.json"
Cohesion: 0.06
Nodes (37): events, memories, people, relationships, reminders, additionalProperties, description, items (+29 more)

### Community 3 - "SocialEventRecord"
Cohesion: 0.21
Nodes (11): Identifiable, AppSettingsRecord, EventAttendeeRecord, GroupMembershipRecord, MemoryRecord, RelationshipRecord, SocialEventRecord, Date (+3 more)

### Community 4 - "CommunityViews.swift"
Cohesion: 0.14
Nodes (16): .body, CalendarWorkspaceView, CommunitiesWorkspaceView, .body, GroupsListView, .archivedGroups, .body, .groups (+8 more)

### Community 5 - ".generateKey"
Cohesion: 0.22
Nodes (8): ContentCipher, ContentCipherError, invalidCombinedCiphertext, invalidKeyLength, randomGenerationFailed, Data, ContentCipherTests, OSStatus

### Community 6 - "AppDatabase"
Cohesion: 0.13
Nodes (8): AppDatabase, getDatabase(), migrate(), CaptureDao, Capture, Context, RoomDatabase, SupportSQLiteDatabase

### Community 7 - "AppRepository"
Cohesion: 0.10
Nodes (5): PersonDao, Person, AppRepository, Capture, Flow

### Community 8 - "AppViewModel"
Cohesion: 0.08
Nodes (9): android, AndroidViewModel, AppViewModel, Capture, ChatMessage, Bitmap, Flow, ReviewExtraction (+1 more)

### Community 9 - "ConfidenceState"
Cohesion: 0.11
Nodes (16): MainActivity, calendarCellColors(), confidenceColors(), ConfidenceState, CONFIRMED, ERROR, IGNORED, NEEDS_REVIEW (+8 more)

### Community 10 - "AppScreen"
Cohesion: 0.14
Nodes (14): AddEvent, AddGroup, AddPerson, AppScreen, Ask, Calendar, Communities, EditGroup (+6 more)

### Community 11 - "2. Reusable Modular Architecture (11 Components)"
Cohesion: 0.10
Nodes (20): 1. Required Structural Layout, 2. Reusable Modular Architecture (11 Components), 3. Interaction & State Safeguards, Home Page (Weekly Review) Design Specification, I. `BottomNavBar`, I. Progress Bar Removal, II. Duplicate Event Collapsing, II. `HomeHeader` (+12 more)

### Community 12 - "package.json"
Cohesion: 0.09
Nodes (21): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google/generative-ai, devDependencies, typescript (+13 more)

### Community 13 - "Flow"
Cohesion: 0.10
Nodes (7): AppSettingsDao, GroupDao, Flow, AppSettingsEntity, Capture, Group, GroupMemberRef

### Community 14 - "SocialEvent"
Cohesion: 0.10
Nodes (7): SocialEventDao, EventAttendeeRef, SocialEvent, CompactEventRow(), EventCard(), NextSevenDaysSection(), ExampleRobolectricTest

### Community 15 - "RecordType"
Cohesion: 0.12
Nodes (15): EncryptedRecordEnvelope, HybridRevision, Comparable, parse(), RecordType, CAPTURE, EVENT, EVENT_ATTENDEE (+7 more)

### Community 16 - "Social Memory Changelog"
Cohesion: 0.12
Nodes (16): Added, Added, Added, Added, Added, Added, Added, Changed (+8 more)

### Community 19 - "CalendarAuthorizationState"
Cohesion: 0.09
Nodes (25): AnyObject, EKEvent, EKEventStore, EventKit, CalendarAuthorizationState, .canRead, .canWrite, denied (+17 more)

### Community 20 - "2. Fact & Observation Observation Tables"
Cohesion: 0.14
Nodes (13): 1. Dimensional / Entity Tables, 2. Fact & Observation Observation Tables, 3. Capture & Logging Cache, `captures` (Immutable history logs of user notes, transcriptions, or chat attachments), `event_attendees_join` (People linked to specific events), `group_members_join` (Relational cross-reference join mapping), `groups` (Circles of friends / communities), `memories` (Granular updates, facts, observations, prefered choices) (+5 more)

### Community 21 - "AiAccessState"
Cohesion: 0.07
Nodes (22): ExtractionContract, ExtractedEvent, ExtractedMemory, ExtractedPerson, ExtractedRelationship, ExtractedReminder, ExtractionResult, GeminiClient (+14 more)

### Community 22 - "enum"
Cohesion: 0.15
Nodes (13): capture, event, eventAttendee, group, groupMembership, memory, person, reminder (+5 more)

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

### Community 28 - "LocalEncryptedContentStore"
Cohesion: 0.13
Nodes (18): FileManager, LocalContentKeyManager, LocalContentKeyProviding, LocalContentPurpose, captureAnalysis, captureAttachment, captureBody, recordNote (+10 more)

### Community 29 - ".application"
Cohesion: 0.25
Nodes (7): FirebaseAppDelegate, Any, Bool, URL, NSObject, UIApplication, UIApplicationDelegate

### Community 30 - "1. Color Palette Tokens"
Cohesion: 0.22
Nodes (8): 1. Color Palette Tokens, 2. Kotlin / Jetpack Compose Token Definitions, 3. Contrast Verification Map, Core Canvas Surfaces, Design Tokens, Global Navigation Triggers, Semantic Highlight Accents, Text & Readable Elements

### Community 31 - "Social Memory UX/UI Design"
Cohesion: 0.22
Nodes (8): 1. Aesthetic Identity & Theme, 2. Low-Friction Capture Flow, 3. High Accessibility & Touch Ergonomics, 4. Chronological Heatmap Social Calendar UX, 5. Group & Circle Name Uniqueness Validation, Social Memory UX/UI Design, Theme Spec (Default: Light Mode):, Theme Toggling:

### Community 32 - "properties"
Cohesion: 0.17
Nodes (12): type, minimum, type, properties, deleted, keyVersion, schemaVersion, updatedAtMs (+4 more)

### Community 33 - "Social Memory QA & Test Plan"
Cohesion: 0.22
Nodes (8): 1. Testing Frameworks Utilized, 2. Test Execution Details, 3. Manual QA Checklist (Calendar UI), 4. iOS validation after Xcode installation, Calendar View Layout and Heatmaps, Entity and Network Relational Consistency, Social Memory QA & Test Plan, Verified Test Outputs:

### Community 34 - "Social Memory UX/UI Guidelines"
Cohesion: 0.25
Nodes (7): 1. Brand Identity & Visual Vibe, 2. Appearance & Theme Toggling, 3. Global Navigation Rules, 4. Dynamic Heatmap Calendar, 5. AI-Review Flow, 6. Accessibility & Contrast Safeguards, Social Memory UX/UI Guidelines

### Community 35 - "AesGcmCipher"
Cohesion: 0.48
Nodes (3): AesGcmCipher, Ciphertext, ByteArray

### Community 36 - "2. Security Safeguards"
Cohesion: 0.29
Nodes (6): 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker", 2. Security Safeguards, A. Local-First Database and Device Encryption, B. Guarded AI Boundaries, C. Zero-Leak Sandbox Contacts Integration, Social Memory Security & Privacy Framework

### Community 37 - "aiContract.ts"
Cohesion: 0.07
Nodes (49): AuthenticatedUser, AuthenticationRequiredError, requireAuthenticatedUser(), AIContractValidationError, AIExtractionResult, AIResponseSizeError, ConfidenceState, confidenceStates (+41 more)

### Community 38 - "CaptureComposerView"
Cohesion: 0.07
Nodes (30): CaptureImporting, AttachmentStatusRow, .body, CaptureComposerView, .body, .canSave, .requiresAttachment, .sourceHelp (+22 more)

### Community 39 - "Equatable"
Cohesion: 0.08
Nodes (27): Equatable, Error, AuthenticationProvider, apple, google, CalendarServiceError, calendarUnavailable, eventNotFound (+19 more)

### Community 40 - "record-envelope.schema.json"
Cohesion: 0.33
Nodes (5): additionalProperties, $id, $schema, title, type

### Community 41 - "CaptureRecord"
Cohesion: 0.13
Nodes (19): CaptureRecord, Bool, optional(), PersonEditorView, Bool, MemoryEditorView, .body, .events (+11 more)

### Community 42 - "AI Extraction & Review Workflow"
Cohesion: 0.40
Nodes (4): 1. The Core Lifecycle, 2. Ingestion State Enforcements, 3. Strict Rules Against Auto-Saving, AI Extraction & Review Workflow

### Community 43 - "Social Brain architecture"
Cohesion: 0.40
Nodes (4): Client architecture, Cloud boundary, Social Brain architecture, Sync status

### Community 44 - "Calendar Heatmap UX"
Cohesion: 0.40
Nodes (4): 1. Visual Heatmap Density Layout, 2. Interaction & Dynamic Filtering, Calendar Heatmap UX, Selected Highlight

### Community 45 - "type"
Cohesion: 0.40
Nodes (5): integer, minimum, type, null, deletedAtMs

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

### Community 50 - "String"
Cohesion: 0.21
Nodes (7): CaptureAttachment, CaptureImportRequest, LocalCaptureService, Data, ModelContext, ModelContainer, String

### Community 51 - "revision"
Cohesion: 0.50
Nodes (4): revision, maxLength, minLength, type

### Community 53 - "GroupRecord"
Cohesion: 0.20
Nodes (20): GroupRecord, .body, GroupDetailView, .body, .groupMemberships, GroupEditorView, PersonDetailView, .body (+12 more)

### Community 56 - "SocialEventEditorView"
Cohesion: 0.11
Nodes (19): AttendeePickerView, .body, CalendarAccessCard, .body, CalendarAccessRationaleView, .body, .body, SocialEventDetailView (+11 more)

### Community 57 - "deviceId"
Cohesion: 0.67
Nodes (3): format, type, deviceId

### Community 58 - "View"
Cohesion: 0.13
Nodes (20): CloudSyncUnavailableSection, .body, ConfidenceBadge, .body, .color, .label, DataManagementView, .body (+12 more)

### Community 59 - ".envelope"
Cohesion: 0.17
Nodes (11): HybridRevision, CloudSyncAvailability, FirestoreEnvelopeCodec, FirestoreEnvelopeStore, Any, EncryptedRecordEnvelope, Int, Int64 (+3 more)

### Community 60 - "Social Brain"
Cohesion: 0.18
Nodes (8): Firebase deployment, Setup after Xcode installation, Social Brain for iOS, Validation, Android, Development notes, iOS, Social Brain

### Community 61 - "PersonRecord"
Cohesion: 0.13
Nodes (17): PersonRecord, .members, .body, GroupMemberPickerView, .availablePeople, .body, .body, RelationshipDetailView (+9 more)

### Community 67 - "Foundation"
Cohesion: 0.14
Nodes (9): Foundation, LocalCaptureAndResetTests, URL, LocalEncryptedContentStoreTests, URL, ServiceStateTests, SocialBrain, XCTest (+1 more)

### Community 68 - "ReminderRecord"
Cohesion: 0.19
Nodes (19): ReminderRecord, EventSummaryRow, .body, HomeWorkspaceView, .body, .memories, .openReminders, .upcomingEvents (+11 more)

### Community 69 - "properties"
Cohesion: 0.12
Nodes (17): coworker, friend, met_through, sibling, spouse, maxLength, minLength, type (+9 more)

### Community 70 - "enum"
Cohesion: 0.12
Nodes (16): event_context, follow_up, general_note, life_update, preference, maxLength, minLength, type (+8 more)

### Community 71 - "$defs"
Cohesion: 0.12
Nodes (16): needs_review, suggested, enum, type, $defs, confidenceState, evidence, memory (+8 more)

### Community 72 - "AuthenticationStateStore.swift"
Cohesion: 0.18
Nodes (11): AuthenticationServices, Combine, CryptoKit, FirebaseAppCheck, FirebaseAuth, FirebaseCore, GoogleSignIn, FirebaseRuntime (+3 more)

### Community 73 - "AuthenticationStateStore"
Cohesion: 0.19
Nodes (7): AuthStateDidChangeListenerHandle, AuthenticationStateStore, Data, Int, UIViewController, .accountActions, PersonNameComponents

### Community 74 - "AppCheckState"
Cohesion: 0.18
Nodes (11): AppCheckState, checking, failed, .isReady, ready, unavailable, AppCheckStateStore, Bool (+3 more)

### Community 75 - "CaptureKind"
Cohesion: 0.15
Nodes (13): CaptureKind, .displayName, email, photo, screenshot, sharedText, text, voice (+5 more)

### Community 76 - "InMemoryContentKeyProvider"
Cohesion: 0.18
Nodes (7): LocalDataResetService, ModelContext, InMemoryContentKeyProvider, .hasKey, Bool, Data, Model

### Community 77 - "required"
Cohesion: 0.20
Nodes (14): confidenceState, content, evidence, memoryType, name, personA, personB, relationshipType (+6 more)

### Community 78 - "confidenceState"
Cohesion: 0.15
Nodes (14): $ref, person, reminder, $ref, $ref, additionalProperties, properties, type (+6 more)

### Community 79 - "properties"
Cohesion: 0.14
Nodes (14): $ref, event, additionalProperties, properties, type, $ref, dateText, location (+6 more)

### Community 80 - "AuthenticationAndAIStatusView"
Cohesion: 0.18
Nodes (9): ProtectedFeatureAvailability, available, unavailable, .body, AuthenticationAndAIStatusView, .aiAvailability, .aiAvailabilityRow, .authenticationStatus (+1 more)

### Community 81 - "ai-contract.test.js"
Cohesion: 0.20
Nodes (8): {
  AI_RATE_LIMIT_MAX_REQUESTS,
  AI_RATE_LIMIT_WINDOW_MS,
  evaluateAIRequestRateLimit,
}, {
  AIContractValidationError,
  AIResponseSizeError,
  MAX_AI_RESPONSE_BYTES,
  ensureAIResponseWithinLimit,
  isAIExtractionResult,
  parseAIExtractionOutput,
}, { AIRequestValidationError, parseAIRequest }, assert, { AuthenticationRequiredError, requireAuthenticatedUser }, fs, path, test

### Community 82 - "RecallWorkspaceView"
Cohesion: 0.36
Nodes (8): RecallWorkspaceView, .events, .memories, .normalizedQuery, .people, .reminders, Bool, String

### Community 83 - ".baseQuery"
Cohesion: 0.54
Nodes (4): keychain, KeychainStore, Any, String

### Community 84 - "optionalText"
Cohesion: 0.29
Nodes (8): string, optionalText, null, maxLength, type, resolvedDate, format, type

### Community 85 - "AuthenticationState"
Cohesion: 0.29
Nodes (7): AuthenticationState, failed, signedIn, signedOut, signingIn, unavailable, .userID

### Community 86 - "parseTextToBlocks"
Cohesion: 0.60
Nodes (6): Bullet, ChatBlock, Heading, Numbered, Paragraph, parseTextToBlocks()

### Community 88 - "name"
Cohesion: 0.50
Nodes (4): maxLength, minLength, type, name

### Community 89 - "id"
Cohesion: 0.67
Nodes (3): format, type, id

## Knowledge Gaps
- **457 isolated node(s):** `fs`, `content`, `replacements`, `fs`, `content` (+452 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppViewModel` connect `AppViewModel` to `MainAppScreens.kt`, `AppRepository`, `ConfidenceState`, `AppScreen`, `Flow`, `SocialEvent`, `Reminder`, `Memory`, `AiAccessState`, `Relationship`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Foundation` to `RecordType`, `SocialEventRecord`, `AuthenticationStateStore.swift`, `String`, `CalendarAuthorizationState`, `.envelope`, `LocalEncryptedContentStore`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `AppRepository` connect `AppRepository` to `AppViewModel`, `Flow`, `SocialEvent`, `Reminder`, `Memory`, `Relationship`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `PersonRecord` (e.g. with `.members` and `.body`) actually correct?**
  _`PersonRecord` has 9 INFERRED edges - model-reasoned connections that need verification._
- **What connects `fs`, `content`, `replacements` to the rest of the system?**
  _457 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RecordType` be split into smaller, more focused modules?**
  _Cohesion score 0.05858585858585859 - nodes in this community are weakly interconnected._
- **Should `ai-extraction.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.05832147937411095 - nodes in this community are weakly interconnected._