package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color

@Composable
fun getMaterialColorScheme(colors: SocialMemoryColorScheme) = darkColorScheme(
    primary = colors.primary,
    onPrimary = colors.textOnAccent,
    primaryContainer = colors.primaryContainer,
    onPrimaryContainer = colors.primary,
    secondary = colors.info,
    onSecondary = colors.textOnAccent,
    tertiary = colors.surfaceRaised,
    onTertiary = colors.textPrimary,
    background = colors.background,
    onBackground = colors.textPrimary,
    surface = colors.surface,
    onSurface = colors.textPrimary,
    surfaceVariant = colors.surfaceSubtle,
    onSurfaceVariant = colors.textSecondary,
    outline = colors.borderSubtle,
    error = colors.danger,
    onError = Color.White
)

@Composable
fun MyApplicationTheme(
    themeMode: String = "DARK",
    content: @Composable () -> Unit
) {
    val darkTheme = when (themeMode) {
        "LIGHT" -> false
        "DARK" -> true
        else -> isSystemInDarkTheme()
    }
    
    val socialMemoryColors = if (darkTheme) DarkSocialMemoryColors else LightSocialMemoryColors

    CompositionLocalProvider(
        LocalSocialMemoryColors provides socialMemoryColors
    ) {
        MaterialTheme(
            colorScheme = getMaterialColorScheme(socialMemoryColors),
            typography = Typography,
            content = content
        )
    }
}
