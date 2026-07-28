# Component Guidelines

This guide details Material Design 3 (M3) component classes and styling rules utilized inside **Social Memory**. All components are theme-aware and dynamically switch between **Dark Mode** (Default) and **Light Mode**.

---

## 1. Action Triggers & Buttons

Every button style strictly indicates action urgency. Colors are derived from the current `SocialMemoryColorScheme`:

### Primary Buttons (Confirm / Save)
- **Styling**: Background is `SocialMemoryColors.primary`, Text is `SocialMemoryColors.textOnAccent` (Slate 900) for high accessibility.
- **Elevation**: 2dp.
- **Minimum Target**: 48dp × 48dp.

### Secondary Buttons (Neutral / Cancel)
- **Styling**: Background is `SocialMemoryColors.surface`, Outlined border is `SocialMemoryColors.borderSubtle`, Text label is `SocialMemoryColors.textPrimary`.
- **Accent On-Hover**: `SocialMemoryColors.surfaceRaised` custom raised background.

### Danger Buttons (Delete / Clear)
- **Styling**: Solid background is `SocialMemoryColors.danger`, Text label is `SocialMemoryColors.textOnAccent` (Slate 900).
- **Destructive Solid**: `SocialMemoryColors.dangerStrong` is paired with White text for critical confirmation sheets.

---

## 2. Text Indicators & Chips

Chips categorize entities and confidence states during extraction using `SocialMemoryColors` container tokens:

### Suggested Chips
- **Container**: `SocialMemoryColors.warningContainer`.
- **Text Label**: `SocialMemoryColors.warning`.

### Confirmed / Active Chips
- **Container**: `SocialMemoryColors.primaryContainer`.
- **Text Label**: `SocialMemoryColors.primary`.

### Social Chips (Person / Circle Group)
- **Container**: `SocialMemoryColors.infoContainer` (#F0F9FF).
- **Text Label**: `SocialMemoryColors.infoStrong` (#0369A1).
- **Border**: `SocialMemoryColors.info.copy(alpha = 0.25f)` outline.
- **Radius**: 12dp.

---

## 3. Card Elements & Selections

Every major card component in Light Mode must be visibly identifiable.
- **Default Surface Card**: Soft rounded rectangle (20-24dp corner shape) set to `SocialMemoryColors.surface` background (#FFFFFF).
  - **Light Mode**: Enforced with a `SocialMemoryColors.borderSubtle` or `SocialMemoryColors.borderStrong` outline and a soft `SocialMemoryColors.cardShadow` (10% black) with 6-8dp elevation.
  - **Dark Mode**: No shadow required; uses background color elevation (Slate 800/700).
- **Raised / Hero Cards**: Uses `SocialMemoryColors.surface` with `borderStrong` and higher shadow elevation (8-12dp).

---

## 4. Temporary States & Empty Content

- **Empty State**: Rendered using a center-aligned column, a descriptive Material symbol icon colored in `SocialMemoryColors.textMuted`, and a secondary descriptive subtitle label.
- **Loading State**: Uses standard material CircularProgressIndicator components colored in brand `SocialMemoryColors.primary`.
- **Permission Dialog**: Only requested on-demand when the user explicitly triggers audio captures. Fits modern M3 bottom sheets styled with `SocialMemoryColors.surface` backgrounds and `SocialMemoryColors.primary` action buttons.
