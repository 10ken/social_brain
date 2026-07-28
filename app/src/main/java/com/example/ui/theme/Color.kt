package com.example.ui.theme

import androidx.compose.ui.graphics.Color

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf

data class SocialMemoryColorScheme(
    val background: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val surfaceSubtle: Color,

    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val textOnAccent: Color,
    val textOnStrongAccent: Color,

    val borderSubtle: Color,
    val borderStrong: Color,

    val primary: Color,
    val primaryStrong: Color,
    val primaryContainer: Color,

    val info: Color,
    val infoStrong: Color,
    val infoDense: Color,
    val infoContainer: Color,

    val warning: Color,
    val warningStrong: Color,
    val warningContainer: Color,

    val danger: Color,
    val dangerStrong: Color,
    val dangerContainer: Color,

    val navGlass: Color,
    val navBorder: Color,
    val navInactive: Color,
    val cardShadow: Color
) {
    // Aliases for compatibility with legacy or shorthand references
    val rose: Color get() = danger
    val confirm: Color get() = primary
    val success: Color get() = primary
    val destructive: Color get() = danger
    val surfaceVariant: Color get() = surfaceSubtle
    val isLightMode: Boolean @Composable get() = background == LightSocialMemoryColors.background
}

val DarkSocialMemoryColors = SocialMemoryColorScheme(
    background = Color(0xFF0F172A),
    surface = Color(0xFF1E293B),
    surfaceRaised = Color(0xFF263449),
    surfaceSubtle = Color(0xFF111827),

    textPrimary = Color(0xFFF8FAFC),
    textSecondary = Color(0xFFCBD5E1),
    textMuted = Color(0xFF94A3B8),
    textOnAccent = Color(0xFF0F172A),
    textOnStrongAccent = Color(0xFFFFFFFF),

    borderSubtle = Color(0xFF334155),
    borderStrong = Color(0xFF475569),

    primary = Color(0xFF14B8A6),
    primaryStrong = Color(0xFF0F766E),
    primaryContainer = Color(0x2614B8A6),

    info = Color(0xFF7DD3FC), // Sky 300 for Dark mode text
    infoStrong = Color(0xFF38BDF8),
    infoDense = Color(0xFF0C4A6E),
    infoContainer = Color(0x260EA5E9),

    warning = Color(0xFFF59E0B),
    warningStrong = Color(0xFFB45309),
    warningContainer = Color(0x26F59E0B),

    danger = Color(0xFFF43F5E),
    dangerStrong = Color(0xFFE11D48),
    dangerContainer = Color(0x26F43F5E),

    navGlass = Color(0xE6111827), // 90% opacity (as per user request: 0xE6 is 90%)
    navBorder = Color(0x1AFFFFFF), // 10% white
    navInactive = Color(0xFFCBD5E1),
    cardShadow = Color(0x66000000) // 40% black
)

val LightSocialMemoryColors = SocialMemoryColorScheme(
    background = Color(0xFFF8FAFC),
    surface = Color(0xFFFFFFFF),
    surfaceRaised = Color(0xFFF1F5F9),
    surfaceSubtle = Color(0xFFE2E8F0),

    textPrimary = Color(0xFF0F172A),
    textSecondary = Color(0xFF334155),
    textMuted = Color(0xFF64748B),
    textOnAccent = Color(0xFF0F172A),
    textOnStrongAccent = Color(0xFFFFFFFF),

    borderSubtle = Color(0xFFE2E8F0),
    borderStrong = Color(0xFFCBD5E1),

    primary = Color(0xFF0D9488),
    primaryStrong = Color(0xFF0F766E),
    primaryContainer = Color(0xFFF0FDFA),

    info = Color(0xFF0284C7),
    infoStrong = Color(0xFF0369A1),
    infoDense = Color(0xFF0C4A6E),
    infoContainer = Color(0xFFF0F9FF),

    warning = Color(0xFFD97706),
    warningStrong = Color(0xFFB45309),
    warningContainer = Color(0xFFFFFBEB),

    danger = Color(0xFFE11D48),
    dangerStrong = Color(0xFFBE123C),
    dangerContainer = Color(0xFFFFF1F2),

    navGlass = Color(0xF5FFFFFF), // 96% opacity as per user request
    navBorder = Color(0xFFCBD5E1),
    navInactive = Color(0xFF64748B),
    cardShadow = Color(0x1A000000) // 10% black
)

val LocalSocialMemoryColors = staticCompositionLocalOf { DarkSocialMemoryColors }
// Kept for legacy compat, but redirect it to current theme
val SocialMemoryColors: SocialMemoryColorScheme
    @Composable get() = LocalSocialMemoryColors.current

enum class ConfidenceState {
    CONFIRMED,
    SUGGESTED,
    NEEDS_REVIEW,
    IGNORED,
    ERROR
}

@Composable
fun confidenceColors(state: ConfidenceState): Pair<Color, Color> {
    return when (state) {
        ConfidenceState.CONFIRMED ->
            SocialMemoryColors.primaryContainer to SocialMemoryColors.primary

        ConfidenceState.SUGGESTED ->
            SocialMemoryColors.warningContainer to SocialMemoryColors.warning

        ConfidenceState.NEEDS_REVIEW ->
            SocialMemoryColors.warningStrong to SocialMemoryColors.textOnStrongAccent

        ConfidenceState.IGNORED ->
            SocialMemoryColors.surfaceRaised to SocialMemoryColors.textMuted

        ConfidenceState.ERROR ->
            SocialMemoryColors.dangerContainer to SocialMemoryColors.danger
    }
}

@Composable
fun calendarCellColors(itemCount: Int, isSelected: Boolean): Pair<Color, Color> {
    return when {
        isSelected ->
            SocialMemoryColors.infoStrong to SocialMemoryColors.textOnStrongAccent

        itemCount <= 0 ->
            SocialMemoryColors.surface to SocialMemoryColors.textSecondary

        itemCount == 1 ->
            SocialMemoryColors.primaryContainer to SocialMemoryColors.primaryStrong

        itemCount == 2 ->
            SocialMemoryColors.primary.copy(alpha = 0.6f) to SocialMemoryColors.textOnAccent

        else ->
            SocialMemoryColors.primary to SocialMemoryColors.textOnAccent
    }
}

// Fallback & Compatibility variables to maintain references in pre-existing views
val PolishBg: Color @Composable get() = SocialMemoryColors.background
val PolishText: Color @Composable get() = SocialMemoryColors.textPrimary
val PolishSubtext: Color @Composable get() = SocialMemoryColors.textSecondary

val PolishPrimary: Color @Composable get() = SocialMemoryColors.primary
val PolishPrimaryContainer: Color @Composable get() = SocialMemoryColors.primaryContainer
val PolishOnPrimary: Color @Composable get() = SocialMemoryColors.textOnAccent
val PolishOnPrimaryContainer: Color @Composable get() = SocialMemoryColors.primary

val PolishSurface: Color @Composable get() = SocialMemoryColors.surface
val PolishSurfaceVariant: Color @Composable get() = SocialMemoryColors.surfaceSubtle
val PolishActiveState: Color @Composable get() = SocialMemoryColors.surfaceRaised
val PolishBorder: Color @Composable get() = SocialMemoryColors.borderSubtle

val PolishErrorContainer: Color @Composable get() = SocialMemoryColors.dangerContainer
val PolishErrorText: Color @Composable get() = SocialMemoryColors.danger
val PolishErrorBorder: Color @Composable get() = SocialMemoryColors.danger

val Slate900: Color @Composable get() = SocialMemoryColors.background
val Slate800: Color @Composable get() = SocialMemoryColors.surface
val Slate700: Color @Composable get() = SocialMemoryColors.borderSubtle
val Slate400: Color @Composable get() = SocialMemoryColors.textMuted
val Slate300: Color @Composable get() = SocialMemoryColors.textSecondary
val Slate50: Color @Composable get() = SocialMemoryColors.textPrimary

val Emerald500: Color @Composable get() = SocialMemoryColors.primary
val Emerald400: Color @Composable get() = SocialMemoryColors.primary
val Teal500: Color @Composable get() = SocialMemoryColors.primary
val Teal100: Color @Composable get() = SocialMemoryColors.primaryContainer
val Sky500: Color @Composable get() = SocialMemoryColors.info
val Rose500: Color @Composable get() = SocialMemoryColors.danger
val Amber500: Color @Composable get() = SocialMemoryColors.warning

