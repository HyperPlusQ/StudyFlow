package com.hyperplusq.studyflow.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

private val LightColors = lightColorScheme(
    primary = Color(0xFF4F6BED),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFDFE2FF),
    onPrimaryContainer = Color(0xFF071A66),
    secondary = Color(0xFF006C5A),
    tertiary = Color(0xFF8A4F00),
    background = Color(0xFFF9F9FF),
    surface = Color(0xFFF9F9FF),
    surfaceContainer = Color(0xFFF0F0FA),
    surfaceContainerHigh = Color(0xFFE9E9F3),
    outline = Color(0xFF767680)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB9C0FF),
    onPrimary = Color(0xFF132778),
    primaryContainer = Color(0xFF3545A0),
    onPrimaryContainer = Color(0xFFDFE2FF),
    secondary = Color(0xFF75D8BE),
    tertiary = Color(0xFFFFB870),
    background = Color(0xFF111319),
    surface = Color(0xFF111319),
    surfaceContainer = Color(0xFF1B1C23),
    surfaceContainerHigh = Color(0xFF25262E),
    outline = Color(0xFF90909A)
)

@Composable
fun StudyFlowTheme(content: @Composable () -> Unit) {
    val context = LocalContext.current
    val colors = when {
        Build.VERSION.SDK_INT >= 31 && isSystemInDarkTheme() -> dynamicDarkColorScheme(context)
        Build.VERSION.SDK_INT >= 31 -> dynamicLightColorScheme(context)
        isSystemInDarkTheme() -> DarkColors
        else -> LightColors
    }
    MaterialTheme(
        colorScheme = colors,
        shapes = Shapes(
            extraSmall = RoundedCornerShape(10.dp),
            small = RoundedCornerShape(14.dp),
            medium = RoundedCornerShape(20.dp),
            large = RoundedCornerShape(28.dp),
            extraLarge = RoundedCornerShape(36.dp)
        ),
        content = content
    )
}
