# Graph Report - .  (2026-07-29)

## Corpus Check
- 126 files · ~128,169 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2120 nodes · 4085 edges · 133 communities (124 shown, 9 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 217 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Compose Screen Navigation
- Encrypted Record Envelopes
- AI Extraction Contracts
- SwiftData Record Models
- SwiftUI App Container
- Authenticated Content Encryption
- Android Room Database
- Android Group Repository
- Android App State
- Android Theme and Activity
- AI Review Persistence
- Weekly Review Home UI
- Firebase Functions Package
- Gemini and People Data
- Social Event Data Access
- Encrypted Record Types
- Release History
- Reminder Data Access
- Memory Data Access
- Calendar Permissions
- Relational Data Schema
- Secure Android AI Gateway
- Shared Record Type Contract
- Compose Component Guidelines
- Relationship Data Access
- Relational Model Specification
- Functions TypeScript Config
- Encrypted Envelope Metadata
- Encrypted Local Content Store
- iOS Contact Import
- Compose Design Tokens
- Social Memory UI Design
- JSON Schema Primitives
- Quality Assurance Plan
- UX UI Guidelines
- Android AES GCM Cipher
- Security and Privacy
- Firebase Account Deletion
- iOS Capture Composer
- Calendar Service Errors
- Record Envelope JSON Schema
- iOS Home and Memory Views
- AI Extraction Review Workflow
- System Architecture
- Calendar Heatmap UX
- Deletion Timestamp Schema
- Ciphertext Schema Field
- Nonce Schema Field
- Applet Replacement Script
- App Replacement Script
- iOS Local Capture Service
- Revision Schema Field
- Android Instrumentation Test
- iOS Group Editor
- Android Unit Test
- Android Cipher Unit Test
- iOS Event Editor
- Device Identifier Schema
- iOS Data Management Views
- Firestore Envelope Sync
- Platform Setup Documentation
- iOS People and Groups Views
- Shared Contract Documentation
- iOS Persistence Test Suite
- SwiftData Social Records
- Relationship Type Schema
- Memory Type Schema
- AI Extraction Result Schema
- Firebase Authentication Runtime
- iOS Authentication State
- App Check Status
- Capture Detail and Types
- Local Data Reset
- AI Contract Required Fields
- Person Extraction Schema
- Event Extraction Schema
- Protected Service Availability
- AI Contract Tests
- Firebase AI Error Mapping
- Keychain Storage
- Optional Date Schema
- Authentication State Model
- Text Block Parser
- Android Extraction Contract Test
- Capture Input Preparation
- Identifier Schema
- Device Voice Capture
- Firebase AI Functions Gateway
- Strict JSON Decoding
- Archived Records UI
- Capture Review State
- AI Extraction Contract Models
- Record Lifecycle Management
- Application Settings and Calendar
- Legacy Capture Migration
- iOS App Bootstrap
- Test Voice Capture
- Android Extraction Contracts
- Encryption Store Tests
- Contact Permission Services
- iOS Calendar Service
- Speech Recognition Permissions
- Voice Capture View Model
- Capture Workspace Environment
- Device Contacts Import
- Firebase Functions AI Gateway
- Application Navigation Tabs
- Encrypted Content Cleanup
- Memory Extraction Schema
- Persistence and Migration Tests
- EventKit Calendar Adapter
- Encryption Error Handling
- Reminder Extraction Schema
- Voice Capture Service
- Voice Capture Errors
- Project Bootstrap Script
- App Check Refresh State
- Device Calendar Import
- Capture Import Errors
- Encrypted Store Errors
- Calendar Access Views
- Authentication AI Status UI
- AI Contract Test Suite
- Account Deletion Tests
- Capture Review Routing
- Persistence Error Reporting
- SwiftData Save Operations
- iOS Group Detail UI
- AI Memory Type

## God Nodes (most connected - your core abstractions)
1. `AppViewModel` - 84 edges
2. `AppRepository` - 52 edges
3. `DeviceVoiceCaptureService` - 36 edges
4. `Person` - 34 edges
5. `RecallWorkspaceView` - 31 edges
6. `Memory` - 26 edges
7. `CaptureComposerView` - 26 edges
8. `SocialEvent` - 25 edges
9. `Reminder` - 25 edges
10. `AppEnvironment` - 25 edges

## Surprising Connections (you probably didn't know these)
- `.authorizationSection` --references--> `ContactImporting`  [INFERRED]
  ios/SocialBrain/Views/ContactImportViews.swift → ios/SocialBrain/Services/ContactImportService.swift
- `ReviewExtractionScreen()` --calls--> `ExtractionResult`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/api/GeminiClient.kt
- `CalendarScreen()` --calls--> `calendarCellColors()`  [INFERRED]
  app/src/main/java/com/example/ui/screens/MainAppScreens.kt → app/src/main/java/com/example/ui/theme/Color.kt
- `.body` --calls--> `AppContainerView`  [INFERRED]
  ios/SocialBrain/App/SocialBrainApp.swift → ios/SocialBrain/App/AppContainerView.swift
- `.body` --calls--> `CalendarWorkspaceView`  [INFERRED]
  ios/SocialBrain/App/AppContainerView.swift → ios/SocialBrain/Views/CalendarViews.swift

## Import Cycles
- None detected.

## Communities (133 total, 9 thin omitted)

### Community 0 - "Compose Screen Navigation"
Cohesion: 0.16
Nodes (32): AnnotatedString, AddEventScreen(), AddGroupScreen(), AddPersonScreen(), AiAccessNotice(), AskScreen(), BottomNavBar(), CalendarScreen() (+24 more)

### Community 1 - "Encrypted Record Envelopes"
Cohesion: 0.09
Nodes (30): Comparable, HybridRevision, EncryptedRecordEnvelope, .authenticatedMetadata, HybridRevision, .encoded, RecordType, capture (+22 more)

### Community 2 - "AI Extraction Contracts"
Cohesion: 0.06
Nodes (37): events, memories, people, relationships, reminders, additionalProperties, description, items (+29 more)

### Community 3 - "SwiftData Record Models"
Cohesion: 0.17
Nodes (21): Identifiable, AppSettingsRecord, CalendarLinkMode, exported, imported, CaptureRecord, EventAttendeeRecord, GroupMembershipRecord (+13 more)

### Community 4 - "SwiftUI App Container"
Cohesion: 0.40
Nodes (3): AppContainerView, .body, SwiftUI

### Community 5 - "Authenticated Content Encryption"
Cohesion: 0.24
Nodes (6): CryptoKit, ContentCipher, randomGenerationFailed, Data, ContentCipherTests, Security

### Community 6 - "Android Room Database"
Cohesion: 0.09
Nodes (10): AppDatabase, getDatabase(), Context, migrate(), AppSettingsDao, CaptureDao, Capture, AppSettingsEntity (+2 more)

### Community 7 - "Android Group Repository"
Cohesion: 0.08
Nodes (6): GroupDao, Group, GroupMemberRef, AppRepository, Capture, Flow

### Community 8 - "Android App State"
Cohesion: 0.06
Nodes (22): AndroidViewModel, AddEvent, AddGroup, AddPerson, AppScreen, AppViewModel, Ask, Calendar (+14 more)

### Community 9 - "Android Theme and Activity"
Cohesion: 0.11
Nodes (16): MainActivity, calendarCellColors(), confidenceColors(), ConfidenceState, CONFIRMED, ERROR, IGNORED, NEEDS_REVIEW (+8 more)

### Community 10 - "AI Review Persistence"
Cohesion: 0.06
Nodes (44): ExtractionReviewService, ExtractionSuggestionKind, event, memory, person, relationship, reminder, StoredExtractionReview (+36 more)

### Community 11 - "Weekly Review Home UI"
Cohesion: 0.10
Nodes (20): 1. Required Structural Layout, 2. Reusable Modular Architecture (11 Components), 3. Interaction & State Safeguards, Home Page (Weekly Review) Design Specification, I. `BottomNavBar`, I. Progress Bar Removal, II. Duplicate Event Collapsing, II. `HomeHeader` (+12 more)

### Community 12 - "Firebase Functions Package"
Cohesion: 0.09
Nodes (21): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google/generative-ai, devDependencies, typescript (+13 more)

### Community 13 - "Gemini and People Data"
Cohesion: 0.13
Nodes (5): GeminiClient, Bitmap, PersonDao, Person, IllegalStateException

### Community 14 - "Social Event Data Access"
Cohesion: 0.10
Nodes (5): SocialEventDao, Capture, EventAttendeeRef, SocialEvent, ExampleRobolectricTest

### Community 15 - "Encrypted Record Types"
Cohesion: 0.12
Nodes (15): EncryptedRecordEnvelope, HybridRevision, Comparable, parse(), RecordType, CAPTURE, EVENT, EVENT_ATTENDEE (+7 more)

### Community 16 - "Release History"
Cohesion: 0.12
Nodes (16): Added, Added, Added, Added, Added, Added, Added, Changed (+8 more)

### Community 17 - "Reminder Data Access"
Cohesion: 0.15
Nodes (4): ReminderDao, Reminder, FollowUpRow(), FollowUpSection()

### Community 18 - "Memory Data Access"
Cohesion: 0.17
Nodes (3): Flow, MemoryDao, Memory

### Community 19 - "Calendar Permissions"
Cohesion: 0.12
Nodes (15): Date, String, UUID, UITestCalendarService, .authorizationState, CalendarAuthorizationState, .canRead, .canWrite (+7 more)

### Community 20 - "Relational Data Schema"
Cohesion: 0.14
Nodes (13): 1. Dimensional / Entity Tables, 2. Fact & Observation Observation Tables, 3. Capture & Logging Cache, `captures` (Immutable history logs of user notes, transcriptions, or chat attachments), `event_attendees_join` (People linked to specific events), `group_members_join` (Relational cross-reference join mapping), `groups` (Circles of friends / communities), `memories` (Granular updates, facts, observations, prefered choices) (+5 more)

### Community 21 - "Secure Android AI Gateway"
Cohesion: 0.14
Nodes (12): AiAccessException, AiAccessState, APP_CHECK_REQUIRED, FIREBASE_NOT_CONFIGURED, RATE_LIMITED, READY, SERVICE_UNAVAILABLE, SIGN_IN_REQUIRED (+4 more)

### Community 22 - "Shared Record Type Contract"
Cohesion: 0.15
Nodes (13): capture, event, eventAttendee, group, groupMembership, memory, person, reminder (+5 more)

### Community 23 - "Compose Component Guidelines"
Cohesion: 0.17
Nodes (11): 1. Action Triggers & Buttons, 2. Text Indicators & Chips, 3. Card Elements & Selections, 4. Temporary States & Empty Content, Component Guidelines, Confirmed / Active Chips, Danger Buttons (Delete / Clear), Primary Buttons (Confirm / Save) (+3 more)

### Community 24 - "Relationship Data Access"
Cohesion: 0.14
Nodes (3): android, RelationshipDao, Relationship

### Community 25 - "Relational Model Specification"
Cohesion: 0.18
Nodes (10): 1. Schema Specifications, 2. Evidence Link Requirements, 3. Data Archival & Cleanup Rules, `groups` (Social Circles & Communities), `memories` (Facts & Biographical Milestones), `people` (Biographical Profiles), Relational Data Models, `relationships` (Interpersonal Links) (+2 more)

### Community 26 - "Functions TypeScript Config"
Cohesion: 0.18
Nodes (10): compilerOptions, esModuleInterop, module, moduleResolution, outDir, skipLibCheck, strict, target (+2 more)

### Community 27 - "Encrypted Envelope Metadata"
Cohesion: 0.18
Nodes (11): ciphertext, deleted, deviceId, id, keyVersion, nonce, recordType, revision (+3 more)

### Community 28 - "Encrypted Local Content Store"
Cohesion: 0.08
Nodes (33): CodingKey, CodingKeys, fileToken, keyVersion, purpose, recordID, recordType, relativePath (+25 more)

### Community 29 - "iOS Contact Import"
Cohesion: 0.06
Nodes (37): CNContactPickerDelegate, CNContactPickerViewController, CNContact, FirebaseAppDelegate, Any, Bool, URL, ContactImportCandidate (+29 more)

### Community 30 - "Compose Design Tokens"
Cohesion: 0.22
Nodes (8): 1. Color Palette Tokens, 2. Kotlin / Jetpack Compose Token Definitions, 3. Contrast Verification Map, Core Canvas Surfaces, Design Tokens, Global Navigation Triggers, Semantic Highlight Accents, Text & Readable Elements

### Community 31 - "Social Memory UI Design"
Cohesion: 0.22
Nodes (8): 1. Aesthetic Identity & Theme, 2. Low-Friction Capture Flow, 3. High Accessibility & Touch Ergonomics, 4. Chronological Heatmap Social Calendar UX, 5. Group & Circle Name Uniqueness Validation, Social Memory UX/UI Design, Theme Spec (Default: Light Mode):, Theme Toggling:

### Community 32 - "JSON Schema Primitives"
Cohesion: 0.17
Nodes (12): type, minimum, type, properties, deleted, keyVersion, schemaVersion, updatedAtMs (+4 more)

### Community 33 - "Quality Assurance Plan"
Cohesion: 0.22
Nodes (8): 1. Testing Frameworks Utilized, 2. Test Execution Details, 3. Manual QA Checklist (Calendar UI), 4. iOS validation after Xcode installation, Calendar View Layout and Heatmaps, Entity and Network Relational Consistency, Social Memory QA & Test Plan, Verified Test Outputs:

### Community 34 - "UX UI Guidelines"
Cohesion: 0.25
Nodes (7): 1. Brand Identity & Visual Vibe, 2. Appearance & Theme Toggling, 3. Global Navigation Rules, 4. Dynamic Heatmap Calendar, 5. AI-Review Flow, 6. Accessibility & Contrast Safeguards, Social Memory UX/UI Guidelines

### Community 35 - "Android AES GCM Cipher"
Cohesion: 0.48
Nodes (3): AesGcmCipher, Ciphertext, ByteArray

### Community 36 - "Security and Privacy"
Cohesion: 0.29
Nodes (6): 1. Ethical Alignment: "Memory Assistant" vs. "Friend Tracker", 2. Security Safeguards, A. Local-First Database and Device Encryption, B. Guarded AI Boundaries, C. Zero-Leak Sandbox Contacts Integration, Social Memory Security & Privacy Framework

### Community 37 - "Firebase Account Deletion"
Cohesion: 0.05
Nodes (61): ACCOUNT_DELETION_CALLABLE_OPTIONS, AccountDataDeletionDependencies, AccountDeletionRequestValidationError, assertEmptyAccountDeletionPayload(), deleteAccountDataForUser(), isRecord(), mapAccountDeletionError(), readAuthTime() (+53 more)

### Community 38 - "iOS Capture Composer"
Cohesion: 0.11
Nodes (18): CaptureImportCoordinating, CaptureInputPreparing, AttachmentStatusRow, .body, CaptureComposerView, .body, .canSave, .sourceHelp (+10 more)

### Community 39 - "Calendar Service Errors"
Cohesion: 0.22
Nodes (9): CalendarServiceError, calendarMismatch, calendarUnavailable, eventIsNotSocialBrainExport, eventNotFound, invalidDateRange, noWritableCalendar, readAccessRequired (+1 more)

### Community 40 - "Record Envelope JSON Schema"
Cohesion: 0.33
Nodes (5): additionalProperties, $id, $schema, title, type

### Community 41 - "iOS Home and Memory Views"
Cohesion: 0.10
Nodes (38): optional(), EventSummaryRow, .body, HomeWorkspaceView, .body, .memories, .openReminders, .upcomingEvents (+30 more)

### Community 42 - "AI Extraction Review Workflow"
Cohesion: 0.40
Nodes (4): 1. The Core Lifecycle, 2. Ingestion State Enforcements, 3. Strict Rules Against Auto-Saving, AI Extraction & Review Workflow

### Community 43 - "System Architecture"
Cohesion: 0.40
Nodes (4): Client architecture, Cloud boundary, Social Brain architecture, Sync status

### Community 44 - "Calendar Heatmap UX"
Cohesion: 0.40
Nodes (4): 1. Visual Heatmap Density Layout, 2. Interaction & Dynamic Filtering, Calendar Heatmap UX, Selected Highlight

### Community 45 - "Deletion Timestamp Schema"
Cohesion: 0.40
Nodes (5): integer, minimum, type, null, deletedAtMs

### Community 46 - "Ciphertext Schema Field"
Cohesion: 0.40
Nodes (5): contentEncoding, maxLength, minLength, type, ciphertext

### Community 47 - "Nonce Schema Field"
Cohesion: 0.40
Nodes (5): contentEncoding, maxLength, minLength, type, nonce

### Community 48 - "Applet Replacement Script"
Cohesion: 0.50
Nodes (3): content, fs, replacements

### Community 49 - "App Replacement Script"
Cohesion: 0.50
Nodes (3): content, fs, replacements

### Community 50 - "iOS Local Capture Service"
Cohesion: 0.26
Nodes (6): CaptureImportRequest, LocalCaptureService, Bool, CaptureRecord, Data, ModelContext

### Community 51 - "Revision Schema Field"
Cohesion: 0.50
Nodes (4): revision, maxLength, minLength, type

### Community 53 - "iOS Group Editor"
Cohesion: 0.32
Nodes (6): GroupEditorView, GroupsListView, .archivedGroups, .body, .groups, GroupRecord

### Community 56 - "iOS Event Editor"
Cohesion: 0.18
Nodes (13): EventAttendeeRecord, AttendeePickerView, .body, SocialEventEditorView, .body, .groups, .people, CaptureRecord (+5 more)

### Community 57 - "Device Identifier Schema"
Cohesion: 0.67
Nodes (3): format, type, deviceId

### Community 58 - "iOS Data Management Views"
Cohesion: 0.11
Nodes (25): AccountDeletionView, .body, .body, CloudSyncUnavailableSection, .body, DataManagementView, .body, LocalResetStatus (+17 more)

### Community 59 - "Firestore Envelope Sync"
Cohesion: 0.29
Nodes (5): CloudSyncAvailability, CloudSyncError, malformedEnvelope, unavailable, FirestoreEnvelopeStore

### Community 60 - "Platform Setup Documentation"
Cohesion: 0.13
Nodes (12): Firebase deployment, Bootstrap, Configurations and schemes, Dependency resolution and `Package.resolved`, Firebase setup, Privacy and signing, Social Brain for iOS, Tests (+4 more)

### Community 61 - "iOS People and Groups Views"
Cohesion: 0.09
Nodes (34): GroupMembershipRecord, CommunitiesWorkspaceView, .body, .body, GroupMemberPickerView, .availablePeople, .body, PeopleListView (+26 more)

### Community 67 - "iOS Persistence Test Suite"
Cohesion: 0.25
Nodes (5): Foundation, CaptureImportLimits, SocialBrain, SwiftData, XCTest

### Community 68 - "SwiftData Social Records"
Cohesion: 0.07
Nodes (32): AppSettingsRecord, CaptureRecord, EventAttendeeRecord, GroupMembershipRecord, GroupRecord, MemoryRecord, PersonRecord, RelationshipRecord (+24 more)

### Community 69 - "Relationship Type Schema"
Cohesion: 0.12
Nodes (17): coworker, friend, met_through, sibling, spouse, maxLength, minLength, type (+9 more)

### Community 70 - "Memory Type Schema"
Cohesion: 0.22
Nodes (9): event_context, follow_up, general_note, life_update, preference, relationship, enum, type (+1 more)

### Community 71 - "AI Extraction Result Schema"
Cohesion: 0.15
Nodes (13): needs_review, suggested, enum, type, $defs, confidenceState, evidence, relationship (+5 more)

### Community 72 - "Firebase Authentication Runtime"
Cohesion: 0.24
Nodes (9): AuthenticationServices, FirebaseAppCheck, FirebaseAuth, FirebaseCore, GoogleSignIn, FirebaseRuntime, .appCheckProviderConfigured, .isConfigured (+1 more)

### Community 73 - "iOS Authentication State"
Cohesion: 0.17
Nodes (8): AuthStateDidChangeListenerHandle, AuthenticationStateStore, Data, Error, Int, UIViewController, .accountActions, PersonNameComponents

### Community 74 - "App Check Status"
Cohesion: 0.29
Nodes (7): AppCheckState, checking, failed, .isReady, ready, unavailable, Date

### Community 75 - "Capture Detail and Types"
Cohesion: 0.10
Nodes (20): CaptureKind, .displayName, email, photo, screenshot, sharedText, text, voice (+12 more)

### Community 76 - "Local Data Reset"
Cohesion: 0.15
Nodes (11): LocalDataResetError, .errorDescription, LocalDataResetService, LocalEncryptedContentResetting, LocalEncryptedContentStore, ModelContext, Set, FailingResetStore (+3 more)

### Community 77 - "AI Contract Required Fields"
Cohesion: 0.20
Nodes (14): confidenceState, content, evidence, memoryType, name, personA, personB, relationshipType (+6 more)

### Community 78 - "Person Extraction Schema"
Cohesion: 0.20
Nodes (10): person, $ref, maxLength, minLength, type, additionalProperties, properties, type (+2 more)

### Community 79 - "Event Extraction Schema"
Cohesion: 0.20
Nodes (10): $ref, event, additionalProperties, properties, type, $ref, dateText, location (+2 more)

### Community 80 - "Protected Service Availability"
Cohesion: 0.20
Nodes (7): ProtectedFeatureAvailability, available, unavailable, .availability, .aiAvailability, .aiAvailability, ServiceStateTests

### Community 81 - "AI Contract Tests"
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

### Community 82 - "Firebase AI Error Mapping"
Cohesion: 0.06
Nodes (44): AIClientError, accountDeletionRequiresRecentSignIn, appCheck, disabled, .errorDescription, invalidContract, invalidRequest, rateLimited (+36 more)

### Community 83 - "Keychain Storage"
Cohesion: 0.54
Nodes (4): keychain, KeychainStore, Any, String

### Community 84 - "Optional Date Schema"
Cohesion: 0.29
Nodes (8): string, optionalText, null, maxLength, type, resolvedDate, format, type

### Community 85 - "Authentication State Model"
Cohesion: 0.20
Nodes (10): AuthenticationProvider, apple, google, AuthenticationState, failed, signedIn, signedOut, signingIn (+2 more)

### Community 86 - "Text Block Parser"
Cohesion: 0.60
Nodes (6): Bullet, ChatBlock, Heading, Numbered, Paragraph, parseTextToBlocks()

### Community 88 - "Capture Input Preparation"
Cohesion: 0.10
Nodes (24): ImageIO, CaptureInputLimits, CaptureInputPreparationError, attachmentTooLarge, .errorDescription, sourceLabelTooLong, textTooLong, unreadableFile (+16 more)

### Community 89 - "Identifier Schema"
Cohesion: 0.67
Nodes (3): format, type, id

### Community 90 - "Device Voice Capture"
Cohesion: 0.15
Nodes (10): AVAudioPlayer, AVAudioPlayerDelegate, AVAudioRecorder, DeviceVoiceCaptureService, .microphonePermission, Bool, FileManager, URL (+2 more)

### Community 91 - "Firebase AI Functions Gateway"
Cohesion: 0.15
Nodes (11): Functions, AIExtractionRequest, .callablePayload, AIImagePayload, .decodedByteCount, Any, Data, FirebaseFunctionsAIGateway (+3 more)

### Community 92 - "Strict JSON Decoding"
Cohesion: 0.23
Nodes (7): DynamicJSONKey, StrictJSONObject, Decoder, Int, Set, KeyedDecodingContainer, T

### Community 93 - "Archived Records UI"
Cohesion: 0.10
Nodes (20): ArchivedRecordsView, .archivedEvents, .archivedGroups, .archivedMemories, .archivedPeople, .archivedRelationships, .archivedReminders, .body (+12 more)

### Community 94 - "Capture Review State"
Cohesion: 0.13
Nodes (15): CaseIterable, .currentReviewState, CaptureReviewState, completed, inProgress, pending, AIResponseMimeType, json (+7 more)

### Community 95 - "AI Extraction Contract Models"
Cohesion: 0.21
Nodes (20): Codable, Equatable, AIConfidenceState, needsReview, suggested, AIExtractedEvent, AIExtractedMemory, AIExtractedPerson (+12 more)

### Community 96 - "Record Lifecycle Management"
Cohesion: 0.18
Nodes (13): RecordLifecycleService, Bool, GroupRecord, ModelContext, PersonRecord, SocialEventRecord, SyncableRecord, .body (+5 more)

### Community 97 - "Application Settings and Calendar"
Cohesion: 0.16
Nodes (10): ApplicationSettingsOpening, SystemApplicationSettingsOpener, CalendarService, CalendarWorkspaceView, .events, SocialEventDetailView, .attendees, .calendarService (+2 more)

### Community 98 - "Legacy Capture Migration"
Cohesion: 0.22
Nodes (10): LegacyCaptureMigrationResult, LegacyCaptureMigrationService, Bool, CaptureRecord, Data, FileManager, LocalEncryptedContentStore, ModelContext (+2 more)

### Community 99 - "iOS App Bootstrap"
Cohesion: 0.15
Nodes (13): App, SocialBrainApp, .body, SocialBrainStorageRootView, .body, StorageRecoveryView, .body, ModelContainer (+5 more)

### Community 100 - "Test Voice Capture"
Cohesion: 0.15
Nodes (9): UITestVoiceCaptureService, .microphonePermission, .speechRecognitionPermission, .state, TimeInterval, VoiceRecording, VoiceTranscriptionResult, transcript (+1 more)

### Community 101 - "Android Extraction Contracts"
Cohesion: 0.22
Nodes (7): ExtractionContract, ExtractedEvent, ExtractedMemory, ExtractedPerson, ExtractedRelationship, ExtractedReminder, ExtractionResult

### Community 102 - "Encryption Store Tests"
Cohesion: 0.17
Nodes (6): InMemoryContentKeyProvider, .hasKey, LocalEncryptedContentStoreTests, Bool, Data, URL

### Community 103 - "Contact Permission Services"
Cohesion: 0.15
Nodes (11): Contacts, UITestContactImportService, .authorizationState, ContactAuthorizationState, authorized, .canSelectContacts, denied, notDetermined (+3 more)

### Community 104 - "iOS Calendar Service"
Cohesion: 0.30
Nodes (6): EventKit, CalendarEventDraft, CalendarEventOwnership, Date, String, UUID

### Community 105 - "Speech Recognition Permissions"
Cohesion: 0.14
Nodes (10): .speechRecognitionPermission, VoicePermissionState, authorized, .canUse, denied, notDetermined, restricted, unavailable (+2 more)

### Community 106 - "Voice Capture View Model"
Cohesion: 0.26
Nodes (6): String, VoiceCaptureViewModel, VoicePermissionStatus, .canRecord, .canTranscribe, .voiceSection

### Community 107 - "Capture Workspace Environment"
Cohesion: 0.33
Nodes (10): AnyObject, AppEnvironment, LocalPersistenceProviding, LocalCaptureImportCoordinator, ContactImporting, CaptureImporting, VoiceCaptureServicing, CaptureWorkspaceView (+2 more)

### Community 108 - "Device Contacts Import"
Cohesion: 0.23
Nodes (7): CNAuthorizationStatus, CNContactStore, DateComponents, DeviceContactImportService, .authorizationState, CNContact, String

### Community 109 - "Firebase Functions AI Gateway"
Cohesion: 0.21
Nodes (9): FirebaseFunctions, AdaptiveAIGateway, AIExtracting, FirebaseBuildConfiguration, .appCheckProvider, .functionsRegion, LocalOnlyAIGateway, String (+1 more)

### Community 110 - "Application Navigation Tabs"
Cohesion: 0.17
Nodes (12): Hashable, AppTab, calendar, capture, communities, home, recall, LocalDataResetComponent (+4 more)

### Community 111 - "Encrypted Content Cleanup"
Cohesion: 0.24
Nodes (6): EncryptedContentCleanupQueue, .references, LocalEncryptedContentStore, String, LocalEncryptedContentStore, UserDefaults

### Community 112 - "Memory Extraction Schema"
Cohesion: 0.17
Nodes (12): $ref, maxLength, minLength, type, memory, additionalProperties, properties, type (+4 more)

### Community 113 - "Persistence and Migration Tests"
Cohesion: 0.24
Nodes (5): FirebaseFunctionsErrorMapperTests, LocalCaptureAndResetTests, ModelContainer, URL, XCTestCase

### Community 114 - "EventKit Calendar Adapter"
Cohesion: 0.29
Nodes (4): EKEvent, EKEventStore, EventKitCalendarService, .authorizationState

### Community 115 - "Encryption Error Handling"
Cohesion: 0.20
Nodes (10): Error, ContentCipherError, invalidCombinedCiphertext, invalidKeyLength, invalidNonceLength, LegacyCaptureMigrationSafetyError, unableToVerifyLegacyContent, TestResetFailure (+2 more)

### Community 116 - "Reminder Extraction Schema"
Cohesion: 0.20
Nodes (10): reminder, $ref, dueText, title, additionalProperties, properties, type, maxLength (+2 more)

### Community 117 - "Voice Capture Service"
Cohesion: 0.22
Nodes (8): AVFoundation, Combine, VoiceCaptureState, idle, playing, recorded, recording, Speech

### Community 118 - "Voice Capture Errors"
Cohesion: 0.22
Nodes (9): VoiceCaptureError, .errorDescription, microphoneAccessRequired, noActiveRecording, playbackCouldNotStart, recordingCouldNotStart, recordingFileMissing, recordingTooLarge (+1 more)

### Community 119 - "Project Bootstrap Script"
Cohesion: 0.68
Nodes (7): fail(), require_command(), require_file(), bootstrap.sh script, usage(), validate_firebase_configuration(), validate_static_configuration()

### Community 121 - "Device Calendar Import"
Cohesion: 0.54
Nodes (5): DeviceCalendarEvent, DeviceCalendarImportView, .body, .importableDeviceEvents, SocialEventRecord

### Community 122 - "Capture Import Errors"
Cohesion: 0.25
Nodes (8): CaptureImportError, attachmentRequired, attachmentTooLarge, invalidAttachment, missingContent, missingEncryptedReference, textTooLarge, voiceTooLarge

### Community 123 - "Encrypted Store Errors"
Cohesion: 0.25
Nodes (8): LocalEncryptedContentStoreError, invalidAttachmentMetadata, invalidReference, invalidStoredKey, missingContent, tamperedContent, unsupportedKeyVersion, unsupportedSchemaVersion

### Community 124 - "Calendar Access Views"
Cohesion: 0.29
Nodes (7): CalendarAccessCard, .body, CalendarAccessRationaleView, .body, .body, Bool, Void

### Community 125 - "Authentication AI Status UI"
Cohesion: 0.25
Nodes (7): .aiSection, AuthenticationAndAIStatusView, .aiAvailabilityRow, .appCheck, .authentication, .authenticationStatus, UIViewController

### Community 127 - "Account Deletion Tests"
Cohesion: 0.33
Nodes (5): {
  ACCOUNT_DELETION_CALLABLE_OPTIONS,
  AccountDeletionRequestValidationError,
  deleteAccountDataForUser,
  mapAccountDeletionError,
  RecentAuthenticationRequiredError,
  RECENT_AUTH_MAX_AGE_SECONDS,
  requireRecentAuthenticatedUser,
  assertEmptyAccountDeletionPayload,
}, assert, { AuthenticationRequiredError }, { DEFAULT_GEMINI_MODEL, resolveGeminiModel }, test

### Community 128 - "Capture Review Routing"
Cohesion: 0.33
Nodes (6): CaptureReviewDestination, event, .id, memory, person, reminder

### Community 131 - "iOS Group Detail UI"
Cohesion: 0.16
Nodes (14): .body, GroupDetailView, .groupMemberships, .members, .body, ConfidenceBadge, .body, .color (+6 more)

### Community 132 - "AI Memory Type"
Cohesion: 0.29
Nodes (7): AIMemoryType, eventContext, followUp, generalNote, lifeUpdate, preference, relationship

## Knowledge Gaps
- **617 isolated node(s):** `fs`, `content`, `replacements`, `fs`, `content` (+612 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Foundation` to `RecordType`, `LegacyCaptureMigrationService`, `String`, `.generateKey`, `ContactAuthorizationState`, `AuthenticationStateStore.swift`, `CalendarEventDraft`, `AIExtractionReviewView`, `LocalDataResetService`, `FirebaseFunctionsAIGateway.swift`, `EncryptedContentCleanupQueue`, `VoiceCaptureService.swift`, `CaptureInputPreparationError`, `FirestoreEnvelopeStore.swift`, `LocalEncryptedContentReference`, `Equatable`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Why does `SwiftData` connect `Foundation` to `saveLocalChanges`, `LegacyCaptureMigrationService`, `String`, `SocialBrainStorageRootView`, `SwiftUI`, `CaptureComposerView`, `ContactAuthorizationState`, `MemoryEditorView`, `AIExtractionReviewView`, `LocalDataResetService`, `ContactImportReviewView`, `RecallWorkspaceView`, `CaptureInputPreparationError`, `View`, `CalendarViews.swift`, `PersonDetailView`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Why does `SocialBrainSchemaV1` connect `SocialBrainSchemaV1` to `Foundation`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **What connects `fs`, `content`, `replacements` to the rest of the system?**
  _617 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RecordType` be split into smaller, more focused modules?**
  _Cohesion score 0.0859465737514518 - nodes in this community are weakly interconnected._
- **Should `ai-extraction.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.05832147937411095 - nodes in this community are weakly interconnected._
- **Should `AppDatabase` be split into smaller, more focused modules?**
  _Cohesion score 0.09116809116809117 - nodes in this community are weakly interconnected._