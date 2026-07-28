# Social Memory UX/UI Design

This document details the interface guidelines and design rules established to make **Social Memory** feel premium, cohesive, accessible, and intuitive.

## 1. Aesthetic Identity & Theme
Social Memory features a dual-theme system that defaults to a professional **Light Theme** with an optional immersive **Slate Dark Theme**. Both themes utilize generous negative space and high-contrast Material Symbols for maximum scannability.

### Theme Spec (Default: Light Mode):
*   **Canvas Background**: `Slate 50` (Light) / `Slate 900` (Dark).
*   **Action Surfaces**: `White` (Light) / `Slate 800` (Dark).
*   **Teal Accents**: Primary actionable highlights, checkboxes, FABs.
*   **Sky Accents**: Highlighting friend circles, connections, information indices.
*   **Amber Accents**: Suggested or unconfirmed facts requiring manual validation.

### Theme Toggling:
*   **Access**: Users can toggle between Light, Dark, and System modes via the **Settings** screen.
*   **Trigger**: A Gear icon on the Home page header provides instant access to preferences.

## 2. Low-Friction Capture Flow
The core user interaction is designed around **extremely low capture friction**.

1.  **Draft / Grab**: User inputs text, screenshot, or voice.
2.  **AI Extraction**: Gemini parses content into People, Events, Memories, Relationships, and Reminders.
3.  **Suggestion Review**: The app NEVER auto-saves. Suggestions use Amber labels until confirmed by the user.

## 3. High Accessibility & Touch Ergonomics
*   **Touch Targets**: Minimum **48dp × 48dp** target size for all interactive elements.
*   **Adaptive Layouts**: Content scales to a max density margin of `600dp` on tablets and foldable devices.

## 4. Chronological Heatmap Social Calendar UX
*   **Heatmap Intensity Rendering**:
    - *0 items*: Neutral surface.
    - *1-2 items*: Subtle `info` (Sky) alpha tint.
    - *3+ items*: Solid `infoStrong` (Sky) - shifts text label to high-contrast White.
*   **Interactive Focus Filtering**: Selecting a date filters the agenda list reactive tags. Selecting again clears the filter.

## 5. Group & Circle Name Uniqueness Validation
*   **Real-time Validation Checks**: Enforces unique names for Circles/Groups.
*   **Error State**: Input fields trigger `isError = true` with a Rose/Crimson highlight and a friendly helper message: *"A Circle with this name already exists."*
*   **Submit Protection**: Save button is disabled during collision states.

