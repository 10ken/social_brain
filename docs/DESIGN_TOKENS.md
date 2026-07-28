# Design Tokens

This document contains the source-of-truth semantic design tokens for **Social Memory** in Kotlin and Compose formats.

---

## 1. Color Palette Tokens

### Core Canvas Surfaces
| Token | Dark Family | Dark Hex | Light Family | Light Hex | Purpose |
|---|---|---|---|---|---|
| `background` | Slate 900 | `#0F172A` | Slate 50 | `#F8FAFC` | Base window canvas background |
| `surface` | Slate 800 | `#1E293B` | White | `#FFFFFF` | Main card surface, interactive elements |
| `surface_raised` | Slate 700 | `#263449` | Slate 100 | `#F1F5F9` | Elevated panels, raised cards |
| `surface_subtle` | Slate 950 | `#111827` | Slate 200 | `#E2E8F0` | Nested surfaces, background chips |
| `border_subtle` | Slate 700 | `#334155` | Slate 200 | `#E2E8F0` | Standard card border, low-contrast separators |
| `border_strong` | Slate 600 | `#475569` | Slate 300 | `#CBD5E1` | Hero card borders, strong dividers |
| `cardShadow` | Black/40% | `#66000000` | Black/10% | `#1A000000` | Component depth shadows (10% black in Light) |

### Global Navigation Triggers
| Token | Dark Family | Dark Hex | Light Family | Light Hex | Purpose |
|---|---|---|---|---|---|
| `navGlass` | Slate 900/90% | `#E6111827` | White/96% | `#F5FFFFFF` | Frosted bottom nav background |
| `navBorder` | Slate 700/10% | `#1AFFFFFF` | Slate 300 | `#CBD5E1` | Navigation container outline |
| `navInactive` | Slate 50 | `#F8FAFC` | Slate 500| `#64748B` | Unselected tab icons/text |

### Text & Readable Elements
| Token | Dark Family | Dark Hex | Light Family | Light Hex | Purpose |
|---|---|---|---|---|---|
| `text_primary` | Slate 50 | `#F8FAFC` | Slate 900 | `#0F172A` | Titles, standard readability items |
| `text_secondary` | Slate 300 | `#CBD5E1` | Slate 700 | `#334155` | Metadata, timelines, descriptions |
| `text_muted` | Slate 400 | `#94A3B8` | Slate 500 | `#64748B` | Ignored items, disabled inputs |
| `text_on_accent` | Slate 900 | `#0F172A` | Slate 900 | `#0F172A` | Text over bright accents |
| `text_on_strong_accent` | White | `#FFFFFF` | White | `#FFFFFF` | Text over dark accents |

### Semantic Highlight Accents
| Token | Dark Family | Dark Hex | Light Family | Light Hex | Purpose |
|---|---|---|---|---|---|
| `primary` | Teal 500 | `#14B8A6` | Teal 600 | `#0D9488` | Key triggers: Save, Done, Capture |
| `primary_strong` | Teal 700 | `#0F766E` | Teal 700 | `#0F766E` | Pressed state, selected tiles |
| `primary_container`| Teal 500/15%| `#2614B8A6`| Teal 50 | `#F0FDFA` | Subtle status backgrounds |
| `info` | Sky 500 | `#0EA5E9` | Sky 600 | `#0284C7` | Profiles, circles, event dates |
| `info_strong` | Sky 700 | `#0369A1` | Sky 700 | `#0369A1` | Active calendar 3-event highlights |
| `info_dense` | Sky 800 | `#075985` | Sky 800 | `#075985` | High-density calendar tiles (4+) |
| `info_container`| Sky 500/15% | `#260EA5E9`| Sky 50 | `#F0F9FF` | Social subtle backgrounds |
| `warning` | Amber 500 | `#F59E0B` | Amber 600 | `#D97706` | Unconfirmed AI extractions |
| `warning_strong` | Amber 700 | `#B45309` | Amber 700 | `#B45309` | Ambiguity warnings, review flags |
| `warning_container`| Amber 500/15%| `#26F59E0B`| Amber 50 | `#FFFBEB` | Suggestion subtle backgrounds |
| `danger` | Rose 500 | `#F43F5E` | Rose 600 | `#E11D48` | Delete triggers, failed indicators |
| `danger_strong` | Rose 600 | `#E11D48` | Rose 700 | `#BE123C` | Erase database, critical actions |
| `danger_container`| Rose 500/15% | `#26F43F5E`| Rose 50 | `#FFF1F2` | Error subtle backgrounds |

---

## 2. Kotlin / Jetpack Compose Token Definitions

Centralized inside `com.example.ui.theme.Color.kt` and managed by `LocalSocialMemoryColors`:

```kotlin
data class SocialMemoryColorScheme(...)

val DarkSocialMemoryColors = SocialMemoryColorScheme(
    background = Color(0xFF0F172A),
    surface = Color(0xFF1E293B),
    surfaceRaised = Color(0xFF263449),
    surfaceSubtle = Color(0xFF111827),
    // ...
)

val LightSocialMemoryColors = SocialMemoryColorScheme(
    background = Color(0xFFF8FAFC),
    surface = Color(0xFFFFFFFF),
    surfaceRaised = Color(0xFFF1F5F9),
    surfaceSubtle = Color(0xFFE2E8F0),
    // ...
)

val LocalSocialMemoryColors = staticCompositionLocalOf { DarkSocialMemoryColors }
val SocialMemoryColors: SocialMemoryColorScheme
    @Composable get() = LocalSocialMemoryColors.current
```

---

## 3. Contrast Verification Map

Ensure compliance with AA standards during visual rendering:
- `text_on_accent` Slate 900 (`#0F172A`) must be mapped to bright fills:
  - `primary` Teal 500 (`#14B8A6`)
  - `info` Sky 500 (`#0EA5E9`)
  - `warning` Amber 500 (`#F59E0B`)
- `text_on_strong_accent` White (`#FFFFFF`) must be mapped on dark fills:
  - `primary_strong` Teal 700 (`#0F766E`)
  - `info_strong` Sky 700 (`#0369A1`)
  - `info_dense` Sky 800 (`#075985`)
  - `warning_strong` Amber 700 (`#B45309`)
  - `danger_strong` Rose 600 (`#E11D48`)
