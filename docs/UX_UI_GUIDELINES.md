# Social Memory UX/UI Guidelines

This document outlines the user experience (UX) and user interface (UI) guidelines for **Social Memory**, a private, personal CRM and social memory assistant.

---

## 1. Brand Identity & Visual Vibe

The visual identity of Social Memory is designed to feel:
- **Private & Safe**: Users must feel complete data sovereignty. Raw logs are retained on-device only with zero automatic telemetry.
- **Calm & Flexible**: Supports both **Light Mode** (optimized for day/clarity) and **Dark Mode** (optimized for night/focus). **Dark Mode is the application default.**
- **Intelligent & Respectful**: AI suggestion pipelines are non-intrusive. AI never auto-saves and is marked in warning state tints (Amber) until user confirmation.
- **High Friction Reduction**: Prominent capture triggers paired with intuitive one-tap review and save triggers.

---

## 2. Appearance & Theme Toggling

Social Memory utilizes a dynamic theme system supporting manual toggling via the Settings screen. Core identifiers are easy to distinguish in both modes due to specific structural rules:

- **Theme Selection**:
  - **Dark (Default)**: Immersive, high-focus Teal-on-Slate canvas. Relies on surface elevation (`surfaceRaised`) and contrast for separation.
  - **Light**: Crisp, professional Slate-on-White canvas. 
    - **Surface System**: Uses a soft page background (`Slate 50`) and white elevated cards (`White`) to prevent "white-on-white" blending.
    - **Visual Separation**: Every component is visibly distinct through clear surface color changes, visible borders (`borderStrong` or `borderSubtle`), and soft shadows (`cardShadow`).
- **Toggling Interaction**:
  - Triggered via the **Cog/Gear icon** on the Top Right of the Home Page.
  - Opens the **Settings Page** as a secondary modal-style overlay.
  - Overlays feature an **'X' close button** and support **dismiss-on-click-away** (clicking the background scrim closes the settings).

---

## 3. Global Navigation Rules

The application uses a strict navigation hierarchy to ensure user flow is predictable:

1. **Hierarchy**: Home → Calendar → Capture → Circle → Recall.
2. **Back Navigation Override**: When the user is on the **Notifications** screen, tapping the system or top-bar "Back" button MUST return them directly to the **Home Page**, regardless of the previous screen in the stack (e.g. Settings).
3. **Adaptive Bottom Bar**: The navigation container uses a "Glassmorphism" effect with `navGlass` and `navBorder`, ensuring it remains legible over scrolling list content. It features a prominent bottom padding of `24.dp` for ergonomics.

Colors communicate transaction states across both modes:

1. **Slate foundations**: Establishes the **Private Workspace**.
   - Dark: `Slate 900` background.
   - Light: `Slate 50` background.
2. **Teal Highlights**: Indicates **Action / Completion / Relief**. Used for Capture, Save, Confirm, and "Done" states.
3. **Sky Highlights**: Indicates **Social Context / People / Relationships**.
4. **Amber Highlights**: Indicates **AI Uncertainty / Review Needed**.
5. **Rose Highlights**: Indicates **Destructive Actions / Failure / Risk**.

---

## 4. Dynamic Heatmap Calendar

Our Social Calendar uses **Sky (Social Focus)** for activity volume:
- **0 events**: Neutral surface background.
- **1-2 events**: Subtle Sky Container tint.
- **3+ events**: Solid Sky strong/dense fills with high-contrast White text.
- **Selected date**: High-contrast `primaryStrong` (Dark Teal) background.

---

## 5. AI-Review Flow

Suggestions must never auto-save:
1. **Suggested**: Label is `warning` (Amber). Evidence text is shown clearly.
2. **Needs Review**: Marked in `warningStrong`. Highlight details such as uncertain timings.
3. **Confirmed**: Saved object with a bright `primaryContainer` (Teal), moving lists safely to the Home Page timeline.
4. **Ignored**: Muted gray chips (`textMuted`) that bypass database commitments.

---

## 6. Accessibility & Contrast Safeguards

- **Contrast Ratios**: Body labels have a minimum rating of **4.5:1** contrast.
- **On-Accent Color Mappings**:
  - Always use `Slate 900` (Dark) text on bright accents like `Teal 500`, `Sky 500`, or `Amber 500`.
  - Use White labels (`#FFFFFF`) on darker surfaces such as `primaryStrong`, `infoStrong`, and `dangerStrong`.
- **Touch Targets**: Minimum interactive size of **48dp × 48dp**.
