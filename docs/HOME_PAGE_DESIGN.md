# Home Page (Weekly Review) Design Specification

This document details the visual identity, structural alignment, state handling, and technical architecture of the renovated **Home Page (Weekly Review)** in the Social Memory application.

---

## 1. Required Structural Layout

The Home screen reorganizes social context into a singular, highly cohesive, single-scroll dashboard designed to make the user:
1. **Aware** of outstanding AI extractions that require confirmation.
2. **Prepared** for upcoming calendar commitments.
3. **Prompted** to action pending social follow-ups.
4. **Synchronized** with recent biographical updates of contacts.

The layout consists of these major sections ordered vertically:
1. **Header (Social Brain / System Vault status)**
2. **Weekly Review Title & Active Date Range**
3. **Circle (Group Context) Pill Filter Trigger**
4. **Needs Review (Centralized Amber Notification)**
5. **This Week (Next Up Event Card & Compact Rows)**
6. **Follow-Up (Vertical Stack Checklist Action Cards)**
7. **Recent Updates (Categorized Biography Log)**
8. **Bottom Navigation (Prominent "Capture" Trigger)**

---

## 2. Reusable Modular Architecture (11 Components)

The screen is built from 11 atomic Jetpack Compose blocks, enforcing extreme maintainability and high rendering performance:

### I. `BottomNavBar`
- **Purpose**: Unified tab switcher.
- **Design Elements**: Uses a Glassmorphism effect (`navGlass` background) with a `navBorder` outline.
- **Metrics**: Height is fixed at `84.dp` with a bottom padding of `24.dp` for ergonomics.
- **Prominent Capture Trigger**: The central "Capture" tab features a floating, high-contrast prominent container shape (`RoundedCornerShape(16.dp)`) with a deep Teal background.

### II. `HomeHeader`
- **Purpose**: System identity and security feedback.
- **Design Elements**: Renders the "Social Brain" brand alongside an elegant, pill-shaped **LOCKED** status tag in primary Teal, assuring complete client-side data privacy.

### III. `WeeklyReviewHeader`
- **Purpose**: Dynamic date and circle filter context.
- **Design Elements**: Highlights "Weekly Review" in display typography paired with the Gregorian calendar range and a clickable Pill button displaying the currently active circle filter context.

### IV. `NeedsReviewCard` (Amber Security Vault)
- **Purpose**: Actionable review trigger for AI unconfirmed data.
- **Design Elements**: Soft Amber container background (`SocialMemoryColors.warningContainer`). Employs high-contrast Amber text, clear metrics, and two actions: "Review Suggestions" and "Dismiss".
- **Rule Check**: Replaces the previous "Action Required" card which wrongly used red/rose error styling.

### V. `ThisWeekSection`
- **Purpose**: Chronological summary of scheduled events.
- **Design Elements**: Hosts a top Next Up hero card followed by compact rows of subsequent gatherings, terminating in a prominent link to view the complete interactive calendar.

### VI. `EventCard` (Primary Hero)
- **Purpose**: Spotlights the closest upcoming commitment.
- **Design Elements**: Raised Slate canvas background (`#1E293B`). Embedded circle tag, attendee profile list (compact tags), and related occurrences grouping indicator.

### VII. `CompactEventRow` (Secondary Events)
- **Purpose**: Minimalist density rendering of secondary events.
- **Design Elements**: Single row footprint showing title, group info, truncated attendee chips, and an highlighted EEEE weekday badge.

### VIII. `FollowUpSection`
- **Purpose**: Container for action items and tasks.
- **Design Elements**: Houses a unified Material card grouping all active reminders vertically. Highly legible, non-cramped list item format.

### IX. `FollowUpRow`
- **Purpose**: Single action item checkbox list.
- **Design Elements**: Displays a custom circular feedback checkbox, person's name, action description, and a 48dp dismiss icon. Selecting the task launches the Action Details logger dialog.

### X. `RecentUpdatesSection`
- **Purpose**: Personal relationship updates database view.
- **Design Elements**: Stacks relevant contact notes chronologically. Displays empty state suggestions when no entries exist.

### XI. `RecentUpdateRow`
- **Purpose**: Individual update card with indicator.
- **Design Elements**: Left accent indicator bar colored dynamically based on categorical parsing:
  - **Work Updates**: Info Sky.
  - **Health Updates**: Warning Amber.
  - **Travel Updates**: Info Sky.
  - **Confirmed Facts**: Primary Teal.

---

## 3. Interaction & State Safeguards

### I. Progress Bar Removal
- **Rationale**: The unlabeled progress bar previously situated above the bottom navigation was removed to reduce cognitive load and visual clutter. The "Social Memory" system status is now communicated via headers and localized loaders.

### II. Duplicate Event Collapsing
- **Strategy**: Deduplicates scheduled calendar items on the database flow. If multiple identical events appear on the calendar for the same day, they are collapsed into a single component showing the primary event details and a secondary badge indicating the presence of related duplicate details (e.g., `+1 related entry`).

### II. Vertical Stacking of Action Items
- **Strategy**: Replaces horizontally scrollable cards with vertically stacked, high-density line records. Eliminates horizontal scrolling fatigue and provides a natural layout for single-finger checklist completions.

### III. Accessible Touch Targets
- **Strategy**: Every button, pill, tab, checkbox, and action handler incorporates a minimum interactable width of **48dp × 48dp** leveraging Compose Material 3 `minimumInteractiveComponentSize` markers.

### IV. Dynamic UI States
The layout provides high-fidelity fallback presentation for each logical state:
- **Empty States**: Friendly explanatory instructions when events, follow-ups, or notes are unavailable.
- **Dismiss Status**: Tapping "Dismiss" on the Suggestion Card temporarily collapses the card locally within memory, respecting user fatigue and space optimizations.
