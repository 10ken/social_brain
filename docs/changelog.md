# Social Memory Changelog

This document logs all incremental updates made to the Social Memory application in chronological order.

## [MVP v1.4.1] - June 2026

### Added
- **Android 15 SDK Update**: Updated SDK target structure and resolved build preview compatibility issues. Aligned compileSdk and targetSdk versions to stable API 35 (Android 15), from the experimental Android 16 (API 36 preview).
- **Core KTX Dependency Optimization**: Downgraded `androidx.core:core-ktx` version from `1.18.0` (alpha/unreleased) to `1.15.0` (stable) in `gradle/libs.versions.toml` to remove dependencies requiring compiler versions higher than API 35, ensuring fully-functional rendering in the stable emulator container.
- **External Calendar Integrations**: In the Calendar tab, added a quick-access sync button next to the "Social Calendar" title. Provides a unified dialog overlay allowing users to connect Google Calendar, Outlook, and iCloud Calendar. The Connect icon has been updated to use a generic calendar icon, and external calendars will automatically sync every day at 5:00 AM in the user's localized time zone.
- **Unified Master Schedule**: Activated integration with the Home page's Next 7 Days view. Connecting an external calendar now dynamically pulls and displays external events alongside local social events natively in the dashboard.
- **Time Zone Preferences**: Added a Time Zone setting under the Settings tab, complete with a persistent storage mechanism allowing users to specify their locale directly (defaulting to EST). Connected Calendars are now also controllable from the Settings Appearance view as well as the Calendar tab overlay.
- **Feature Feedback**: Added a "Suggest a Feature / Improvement" form action within the App Settings page, enabling users to request and describe new platform capabilities.
- **Context Drift Detection**: Instructed the AI to detect when user queries completely deviate from the 3-turn discussion context. The UI now parses automatic `[DRIFT]` message flags and surfaces a non-intrusive prompt allowing the user to either reset their chat cache or stay on the new tangent.
- **Message Action Menus**: Added long-press gesture support across both User queries and AI responses inside the conversation view.
- **Copy and Edit Interactions**: Added context actions. Long-pressing user chat bubbles allows copying the text or populating it back into the query input for editing. Long-pressing AI bubbles provides actions to copy to clipboard or open a quick Issue Report dialog.
- **Multi-line Advanced Parsing**: Added rich inline text parsing on the client. Responses now natively render headers, un-ordered lists, numbered lists, and handle nested italics / bold styling without relying on static raw markdown wrappers.

### Changed
- **Calendar Heatmap UI**: Updated the Calendar page UI to represent active days using solid box gradients instead of small dot indicators. A specific color gradient (ranging from Cyan Light to Cyan Dark) now clearly indicates the presence of 1, 2, or 3+ scheduled items.
- **Calendar Legibility and Flow**: Added an activity level legend ("Daily Activity Level") above the Agenda split to clarify the heatmap gradient colors to the user. Also styled the "Show Month" view reset trigger as a clearly defined, rounded, primary-colored pill button for stronger affordance.
- **Test Permutation Data**: Prepopulated local database with targeted Calendar combinations (1 event, 1 follow up, 2 events/2 follow ups, 3 events) specifically spanning test periods across May, June, and July of 2026 to ensure UI durability and testing reliability.

- **Conversational Recall UI**: Rebuilt the Recall screen to support a continuous, scrollable two-way chat interface reflecting history rather than a single disjointed Q&A result point. Added automatic smooth scrolling to new messages.
- **Persistent Chat History**: Chat history now persists across tab navigation. Added a prominent manual "Clear" button in the action bar to reset context.
- **Smart @Person Linking**: Engineered the AI client to precisely tag referenced network individuals in its responses. Mapped these tags to `ClickableText` annotated spans, allowing users to tap any `@Name` directly within an AI chat bubble to instantly navigate to that person's full profile log.
- **Recall Screen Overhaul**: Changed page titles from "Ask Social Memory" to "Recall Social Insights". Redesigned page descriptions to focus on tracking connections, shared updates, and circle context.
- **Suggested Clickable Recalls**: Embedded 3 custom recommended queries/puzzles based on friends and circles context positioned above the user question text field. Empowered users to click a suggestion to execute the recall instant analysis flow automatically.
- **Navigation Renaming**: Changed bottom navigation tab "People" to "Recall" and "Community" (formerly "Groups") to "Circle".
- **Icon Update**: Changed the bottom navigation icon for the "Recall" page to a message icon (`Icons.Default.Message`).
- **Default Theme Preference**: Set **Dark Mode** as the application's default out-of-the-box theme in settings defaults, `MainActivity` fallback, and `Theme` initial values.
- **Badge Dot Cleanup**: Removed the pending review orange/amber badge dot indicator overlay completely from the primary middle "Capture" tab icon.

## [MVP v1.4.0] - June 2026

### Added
- **Global Settings and Preferences Configuration**: Implemented a comprehensive in-app **Settings screen** enabling direct user control over contact integration credentials (Email, Phone number), application-wide visual appearance, and data privacy disclosures. Added localized Settings and Notifications icons directly to the main Home Page header.
- **Persistent Light Mode Support**: Engineered a complementary, clean, professional **Light Mode** capability (`LightSocialMemoryColors`). Completely redefined the composition local `SocialMemoryColorScheme` to dynamically read from database user preferences, falling back appropriately to System Default options.
- **Notifications Hub**: Configured a centralized system action center tracking pending AI reviews (`Amber`), upcoming calendar events (`Sky`), and confirmed local background sync operations (`Teal`).
- **Comprehensive Documentation Refresh**: Updated `DESIGN_TOKENS.md`, `UX_UI_GUIDELINES.md`, and `COMPONENT_GUIDELINES.md` to formally document light/dark hex color mappings, theme toggling behavior, and responsive component styling rules.

## [MVP v1.3.0] - June 2026

### Added
- **Renovated Premium Home Page Layout**: Completely refactored the `HomeScreen` dashboard into a highly legible, single-column scrollable structure mapped in strict chronological order (Header, Weekly Review title, Circle filter, Needs Review, This Week, Follow Up, Recent Updates, Bottom Navigation) to maximize visual flow.
- **11 Atomic Reusable Composables**: Partitioned the dashboard into clear, high-performance, stateless View blocks (`BottomNavBar`, `HomeHeader`, `WeeklyReviewHeader`, `NeedsReviewCard`, `ThisWeekSection`, `EventCard`, `CompactEventRow`, `FollowUpSection`, `FollowUpRow`, `RecentUpdatesSection`, `RecentUpdateRow`) to guarantee maximum maintainability.
- **Amber-based Needs Review Safety Guardrail**: Replaced the previous error-toned crimson AI card with a calming, trustworthy Amber warning-container card (`SocialMemoryColors.warningContainer`). Integrates direct navigation hooks in one single finger movement.
- **Deduplicated & Grouped Timelines**: Configured the "This Week" event cards to automatically group, merge, and collapse identical repeating occurrences while displaying compact "+X related entries" indicators, eliminating redundant scroll clutter.
- **Accessible Vertical Follow-up Checklists**: Reconfigured horizontally cramped tasks into high-density, vertically stacked checklist rows. Applied standard Compose interactive limits (`minimumInteractiveComponentSize`) ensuring robust **48dp × 48dp** touch targets for check toggles.
- **Categorized Biography Memory Feeds**: Enriched the "Recent Updates" feed items with live color indicators matching specific parsed updates (Sky for Work/Travel updates, Amber for Health updates, and Teal for standard relationship logs) to boost visual scanning.
- **Spec Suite Addition**: Authored `HOME_PAGE_DESIGN.md` documentation detailing the full architecture, layout order, interactive states, and responsive layout properties of the dashboard.

## [MVP v1.2.0] - June 2026

### Added
- **Premium Slate Dark Custom Theme**: Replaced the light lilac mockup theme with a sleek, premium dark slate foundation (`Slate 900` background and `Slate 800` cards) optimized for low visual glare, focused privacy, and premium aesthetic feel.
- **Centralized Design Tokens**: Implemented the `SocialMemoryColors` tokens architecture in Kotlin to isolate styling properties (surfaces, semantic text elements, action accents, and alpha containers) cleanly from screen views.
- **Sky-based Dynamic Density Calendar**: Reconfigured the calendar heatmap to utilize Sky colors instead of Teal to distinguish social gathering density smoothly from transactional completion triggers (Teal).
- **AI Extraction Confidence State Engine**: Introduced the strict 5-stage state pipeline (Confirmed, Suggested, Needs Review, Ignored, Error) mapped onto Amber (AI uncertainty tint), Teal (action/completed), Sky (social), and Rose (destructive action) colors, ensuring users are always in command of AI-generated content.
- **Clean Ingestion Documentation Suite**: Produced structured architectural guidelines for layout contrast, database schemas, and state constraints:
  - Created `UX_UI_GUIDELINES.md`
  - Created `DESIGN_TOKENS.md`
  - Created `DATA_MODEL.md`
  - Created `AI_EXTRACTION_REVIEW.md`
  - Created `CALENDAR_UX.md`
  - Created `COMPONENT_GUIDELINES.md`

## [MVP v1.1.1] - June 2026

### Added
- **Circle Name Uniqueness Validation**: Applied a strict uniqueness constraint for social circles/groups.
  - Added real-time check against the database of current groups, displaying a crimson validation error message under the text field if a name collision occurs.
  - Disabled the creation action while duplicate values are active to secure relational integrity.
  - Implemented transactional integrity at the `AppViewModel` tier to prevent duplicate circle insertions through any background execution pathway.

## [MVP v1.1.0] - June 2026

### Added
- **Dynamic Heatmap Social Calendar**: Rewrote the calendar screen into an interactive offline schedule planner.
  - Generates correct day alignments using Gregorian Calendar models mapping from current beginning to end of month.
  - Implements density color date boxes (heatmaps): date tiles are dynamically styled in progressively darker shades of Material brand purple based on the total number of events and checklists scheduled. High-density tiles automatically shift text colors to preserve AA contrast rating.
  - Added dual Agenda views displaying list items comprehensively of any selected month or drilled down strictly to isolated day selections.
  - Implements responsive calendar navigation: supporting horizontal month-by-month increment/decrement and a custom full month-year grid picker to jump directly to target years and months.
- **Privacy-first Contacts Integration**: Added an opt-in workflow in the `PeopleIndex` screen. Implemented a prominent "Contacts Sync" option paired with a detailed "Social Brain Privacy Promise" dialog informing users that all data remains 100% device-local and offline with zero cloud telemetry. Integrated device address book querying with fallback mock connections if permissions are restricted.
- **Smart Contact Fields**: Added `phoneNumber`, `email`, `isImported`, and `contactIdOnDevice` attributes to the `Person` schema. Rendered phone call, email, and native "Imported" indicators cleanly inside `PersonDetailScreen`.
- **Social Profile Tagging**: Added active horizontal-sliding profile chips directly onto the `CaptureScreen` notepad. Empowered users to tag visual screenshots, transcript segments, or voice note captures directly to specific coworker or friend profiles to preserve raw background files under their profile history.
- **AI Suggested Partnerships**: Designed an "AI Partnership Detections Center" card on the `HomeScreen`. Surfaces recommended core relational attributes parsed by heuristic analysis with explicit match confidence levels, supportive context clues, and responsive "Confirm Connection" / "Dismiss" verification triggers.
- **Dynamic Checkbox Reminders**: Refactored the `FOLLOW UP` section on the `HomeScreen` into checkable Material 3 rounded chips with live "Done" toggle checkmarks.

## [MVP v1.0.0] - June 2026

### Added
-   **Local-First Database Schema**: Defined highly robust Room entities and mappings for `Person`, `Group`, `Relationship`, `Memory`, `Capture`, `SocialEvent`, and `Reminder` tables with foreign keys and cascade deletions.
-   **AppRepository**: Designed clean database transaction interfaces, Flow mapping accessors, join query functions, and prepolutation defaults.
-   **Gemini Client Layer**: Created a REST API extraction integration with Retrofit, prompting structured JSON from unstructured logs, voice transcripts, or screenshots.
-   **AppViewModel Architecture**: Designed MVVM controller state-handling, navigation stack tracking, database observation mappings, and capture simulation executors.
-   **Adaptive Dark Slate UI (Material 3)**: Created visual layouts conforming to custom responsive margins, 48dp touch targets, and beautiful Slate themes:
    -   `HomeScreen`: Displaying "This Week" timeline events, "Follow-ups" checkboxes, and "Recent Updates".
    -   `PeopleIndexScreen`: Searchable index of connections with FAB overlay entries.
    -   `GroupsScreen` & `DetailProfile`: Circles of friends with detailed biographical updates.
    -   `SocialCalendar`: Upcoming chronological listing of timelines.
    -   `CaptureScreen`: Textpad extraction block with image and audio transcription simulators.
    -   `ReviewSuggestionsScreen`: Interactive confirmation pipeline with ignore sliders and evidence source tracking.
-   **QA Unit & Visual Suite**: Added Robolectric and Roborazzi visual assert screenshot tests for verified color values.
-   **User-facing System Docs**: Created comprehensive architectural plans, data schemas, accessibility design guidelines, testing outlines, and privacy structures inside `/docs`.
