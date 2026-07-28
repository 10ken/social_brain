package com.example.ui.screens

import android.graphics.Bitmap
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.api.*
import com.example.data.*
import com.example.ui.AppScreen
import com.example.ui.AppViewModel
import com.example.ui.theme.*
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import java.text.SimpleDateFormat
import java.util.*

import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.foundation.text.ClickableText
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppContainer(viewModel: AppViewModel) {
    val currentScreen by viewModel.currentScreen.collectAsStateWithLifecycle()
    val navStack by viewModel.navigationStack.collectAsStateWithLifecycle()
    val isExtracting by viewModel.isExtracting.collectAsStateWithLifecycle()

    // Override back behavior for Notifications -> Home requirement
    val onBack: () -> Unit = {
        if (currentScreen is AppScreen.Notifications) {
            viewModel.setTab(AppScreen.Home)
        } else {
            viewModel.navigateBack()
        }
    }

    // Handle system back press
    BackHandler(enabled = navStack.size > 1) {
        onBack()
    }

    Scaffold(
        topBar = {
            if (currentScreen != AppScreen.Home) {
                TopAppBar(
                    navigationIcon = {
                        if (navStack.size > 1 || currentScreen == AppScreen.Notifications) {
                            IconButton(onClick = onBack) {
                                Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = SocialMemoryColors.textPrimary)
                            }
                        }
                    },
                    title = {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = "Private Storage",
                                tint = SocialMemoryColors.primary,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = "Social Brain",
                                fontWeight = FontWeight.Bold,
                                color = SocialMemoryColors.textPrimary,
                                fontSize = 20.sp
                            )
                        }
                    },
                    actions = {},
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = SocialMemoryColors.background,
                        titleContentColor = SocialMemoryColors.textPrimary
                    )
                )
            }
        },
        containerColor = SocialMemoryColors.background
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Staggered crossfade animation based on screen state
            AnimatedContent(
                targetState = if (currentScreen is AppScreen.Settings && navStack.size > 1) {
                    navStack[navStack.size - 2]
                } else {
                    currentScreen
                },
                transitionSpec = {
                    fadeIn() togetherWith fadeOut()
                },
                label = "ScreenTransition"
            ) { screen ->
                BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                    val maxWidth = maxWidth
                    val adaptiveModifier = if (maxWidth > 600.dp) {
                        Modifier
                            .widthIn(max = 600.dp)
                            .align(Alignment.TopCenter)
                    } else {
                        Modifier.fillMaxSize()
                    }

                    when (screen) {
                        is AppScreen.Home -> HomeScreen(viewModel, adaptiveModifier)
                        is AppScreen.Communities -> CommunitiesScreen(viewModel, adaptiveModifier)
                        is AppScreen.Calendar -> CalendarScreen(viewModel, adaptiveModifier)
                        is AppScreen.Capture -> CaptureScreen(viewModel, adaptiveModifier)
                        is AppScreen.Ask -> AskScreen(viewModel, adaptiveModifier)
                        is AppScreen.PersonDetail -> PersonDetailScreen(screen.personId, viewModel, adaptiveModifier)
                        is AppScreen.EditPerson -> EditPersonScreen(screen.personId, viewModel, adaptiveModifier)
                        is AppScreen.GroupDetail -> GroupDetailScreen(screen.groupId, viewModel, adaptiveModifier)
                        is AppScreen.ReviewExtraction -> ReviewExtractionScreen(screen.captureId, viewModel, adaptiveModifier)
                        is AppScreen.AddPerson -> AddPersonScreen(viewModel, adaptiveModifier)
                        is AppScreen.AddGroup -> AddGroupScreen(viewModel, adaptiveModifier)
                        is AppScreen.EditGroup -> AddGroupScreen(viewModel, adaptiveModifier)
                        is AppScreen.AddEvent -> AddEventScreen(viewModel, adaptiveModifier)
                        is AppScreen.Settings -> SettingsScreen(viewModel, adaptiveModifier)
                        is AppScreen.Notifications -> NotificationsScreen(viewModel, adaptiveModifier)
                    }
                }
            }
            
            // Settings Overlay
            if (currentScreen is AppScreen.Settings) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.5f))
                        .clickable { viewModel.setTab(AppScreen.Home) }
                ) {
                    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                        val settingsMaxWidth = maxWidth
                        val settingsAdaptiveModifier = if (settingsMaxWidth > 600.dp) {
                            Modifier
                                .widthIn(max = 600.dp)
                                .align(Alignment.Center)
                        } else {
                            Modifier.fillMaxSize()
                        }
                        
                        SettingsScreen(
                            viewModel = viewModel, 
                            modifier = settingsAdaptiveModifier
                                .clickable(enabled = false) { } // prevent click-through
                        )
                    }
                }
            }
            
            // Floating transparent gradient to keep bottom nav readable
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                SocialMemoryColors.background.copy(alpha = 0.0f),
                                SocialMemoryColors.background.copy(alpha = 0.9f)
                            )
                        )
                    )
            )

            Box(
                modifier = Modifier.align(Alignment.BottomCenter)
            ) {
                BottomNavBar(
                    currentScreen = currentScreen,
                    onTabSelected = { tab -> viewModel.setTab(tab) }
                )
            }

            if (isExtracting) {
                // Dimming progress overlay
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(SocialMemoryColors.background.copy(alpha = 0.7f))
                        .clickable(enabled = false) {},
                    contentAlignment = Alignment.Center
                ) {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = SocialMemoryColors.surface),
                        shape = RoundedCornerShape(24.dp),
                        modifier = Modifier
                            .padding(24.dp)
                            .widthIn(max = 320.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            CircularProgressIndicator(color = SocialMemoryColors.primary)
                            Text(
                                text = "AI Social Memory Brain",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = SocialMemoryColors.textPrimary
                            )
                            Text(
                                text = "Extracting social entities, updates, dates, and connections from Capture...",
                                fontSize = 13.sp,
                                color = SocialMemoryColors.textSecondary,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 1. HOME TAB SCREEN (WEEKLY OVERVIEW)
// ==========================================

@Composable
fun BottomNavBar(
    currentScreen: AppScreen,
    onTabSelected: (AppScreen) -> Unit
) {
    val tabs = listOf(
        Triple(AppScreen.Home, Icons.Default.Home, "Home"),
        Triple(AppScreen.Calendar, Icons.Default.Event, "Calendar"),
        Triple(AppScreen.Capture, Icons.Default.Add, "Capture"),
        Triple(AppScreen.Communities, Icons.Default.Group, "Circle"),
        Triple(AppScreen.Ask, Icons.AutoMirrored.Filled.Message, "Recall")
    )
    
    val hasPendingReview = true // Stub for pending review indicator
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 24.dp)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(84.dp),
            color = SocialMemoryColors.navGlass,
            shape = RoundedCornerShape(999.dp),
            border = BorderStroke(1.dp, SocialMemoryColors.navBorder),
            shadowElevation = if (SocialMemoryColors.isLightMode) 12.dp else 4.dp
        ) {
            Row(
                modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.SpaceAround,
                verticalAlignment = Alignment.CenterVertically
            ) {
                tabs.forEach { (tabScreen, icon, label) ->
                    val isSelected = when (tabScreen) {
                        AppScreen.Capture -> currentScreen is AppScreen.Capture || currentScreen is AppScreen.ReviewExtraction
                        AppScreen.Home -> currentScreen is AppScreen.Home
                        AppScreen.Communities -> currentScreen is AppScreen.Communities || currentScreen is AppScreen.GroupDetail || currentScreen == AppScreen.AddGroup
                        AppScreen.Calendar -> currentScreen is AppScreen.Calendar || currentScreen == AppScreen.AddEvent
                        AppScreen.Ask -> currentScreen is AppScreen.Ask || currentScreen is AppScreen.PersonDetail || currentScreen == AppScreen.AddPerson || currentScreen is AppScreen.EditPerson
                        else -> false
                    }

                    val isPrimary = tabScreen == AppScreen.Capture
                    val badgeColor: Color? = null

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clickable(
                                indication = null,
                                interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                            ) { onTabSelected(tabScreen) },
                        contentAlignment = Alignment.Center
                    ) {
                        val containerWidth = if (isPrimary) 64.dp else if (isSelected) 78.dp else 56.dp
                        val containerHeight = if (isPrimary) 64.dp else 58.dp

                        Box(
                            modifier = Modifier
                                .size(width = containerWidth, height = containerHeight)
                                .clip(RoundedCornerShape(999.dp))
                                .background(
                                    when {
                                        isPrimary -> SocialMemoryColors.primary
                                        isSelected -> SocialMemoryColors.primaryContainer
                                        else -> Color.Transparent
                                    }
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            val targetSize = if (isPrimary) 32.dp else 28.dp
                            val animatedSize by androidx.compose.animation.core.animateDpAsState(targetValue = targetSize, label = "iconSize")

                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Icon(
                                    imageVector = icon,
                                    contentDescription = label,
                                    tint = when {
                                        isPrimary -> SocialMemoryColors.textOnStrongAccent
                                        isSelected -> SocialMemoryColors.primaryStrong
                                        else -> SocialMemoryColors.navInactive
                                    },
                                    modifier = Modifier.size(animatedSize)
                                )
                                
                                if (!isPrimary) {
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = label,
                                        color = if (isSelected) SocialMemoryColors.primaryStrong else SocialMemoryColors.navInactive,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                        fontSize = 11.sp,
                                        maxLines = 1,
                                        modifier = Modifier.widthIn(max = containerWidth)
                                    )
                                }
                            }

                            if (badgeColor != null) {
                                Box(
                                    modifier = Modifier
                                        .align(Alignment.TopEnd)
                                        .padding(top = if (isPrimary) 12.dp else 10.dp, end = if (isPrimary) 13.dp else 10.dp)
                                        .size(10.dp)
                                        .background(badgeColor, CircleShape)
                                        .border(2.dp, SocialMemoryColors.navGlass, CircleShape)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun HomeHeader(
    onNavigateNotifications: () -> Unit,
    onNavigateSettings: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .testTag("home_header"),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Lock,
                contentDescription = "Private Storage",
                tint = SocialMemoryColors.primary,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "Social Brain",
                fontWeight = FontWeight.Bold,
                color = SocialMemoryColors.textPrimary,
                fontSize = 22.sp
            )
        }
        
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            IconButton(onClick = onNavigateNotifications) {
                BadgedBox(
                    badge = {
                        Badge(containerColor = SocialMemoryColors.warning) { 
                            Text("1", color = SocialMemoryColors.textOnAccent, fontSize = 10.sp) 
                        }
                    }
                ) {
                    Icon(imageVector = Icons.Default.Notifications, contentDescription = "Notifications", tint = SocialMemoryColors.textMuted)
                }
            }
            IconButton(onClick = onNavigateSettings) {
                Icon(imageVector = Icons.Default.Settings, contentDescription = "Settings", tint = SocialMemoryColors.textMuted)
            }
        }
    }
}

@Composable
fun SevenDayOutlookHeader(
    dateRange: String,
    selectedGroupText: String,
    onFilterClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .testTag("seven_day_outlook_header"),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                text = "7-Day Outlook",
                fontSize = 30.sp,
                fontWeight = FontWeight.ExtraBold,
                color = SocialMemoryColors.textPrimary,
                letterSpacing = (-0.5).sp
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = dateRange,
                fontSize = 15.sp,
                color = SocialMemoryColors.textSecondary,
                fontWeight = FontWeight.Medium
            )
        }

        Surface(
            color = if (SocialMemoryColors.isLightMode) SocialMemoryColors.surface else SocialMemoryColors.surfaceRaised,
            shape = RoundedCornerShape(100),
            border = BorderStroke(1.dp, if (SocialMemoryColors.isLightMode) SocialMemoryColors.borderStrong else SocialMemoryColors.borderSubtle),
            shadowElevation = if (SocialMemoryColors.isLightMode) 2.dp else 0.dp,
            modifier = Modifier.clickable { onFilterClick() }.testTag("group_filter_trigger")
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.FilterList,
                    contentDescription = "Filter",
                    tint = SocialMemoryColors.info,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = selectedGroupText,
                    color = SocialMemoryColors.textPrimary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = "Drop Down",
                    tint = SocialMemoryColors.textMuted,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

@Composable
fun NeedsReviewCard(
    unresolvedCount: Int,
    onReviewClick: () -> Unit,
    onDismissClick: () -> Unit
) {
    Surface(
        color = SocialMemoryColors.warningContainer,
        border = BorderStroke(1.dp, SocialMemoryColors.warning.copy(alpha = 0.5f)),
        shape = RoundedCornerShape(24.dp),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("needs_review_card")
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = "Action Required",
                    tint = SocialMemoryColors.warning,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "Needs Review",
                    color = SocialMemoryColors.textPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp
                )
            }

            Text(
                text = "$unresolvedCount AI suggestions need confirmation",
                fontSize = 14.sp,
                color = SocialMemoryColors.textSecondary,
                lineHeight = 18.sp
            )

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = onReviewClick,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.warning,
                        contentColor = SocialMemoryColors.textOnAccent
                    ),
                    shape = RoundedCornerShape(100),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    modifier = Modifier
                        .height(40.dp)
                        .testTag("action_confirm_btn")
                ) {
                    Text("Review Suggestions", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }

                OutlinedButton(
                    onClick = onDismissClick,
                    border = BorderStroke(1.dp, SocialMemoryColors.warning),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = Color.Transparent,
                        contentColor = SocialMemoryColors.warning
                    ),
                    shape = RoundedCornerShape(100),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    modifier = Modifier
                        .height(40.dp)
                        .testTag("action_dismiss_btn")
                ) {
                    Text("Dismiss", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun EventCard(
    event: SocialEvent,
    occurrenceCount: Int,
    viewModel: AppViewModel
) {
    val dateStr = event.startTime?.let {
        SimpleDateFormat("EEE h:mm a", Locale.getDefault()).format(Date(it))
    } ?: "Unscheduled"
    
    val attendeesState = viewModel.getEventAttendees(event.id).collectAsStateWithLifecycle(emptyList())

    Surface(
        color = SocialMemoryColors.surface,
        border = BorderStroke(1.dp, if (SocialMemoryColors.isLightMode) SocialMemoryColors.borderStrong else SocialMemoryColors.borderSubtle),
        shape = RoundedCornerShape(24.dp),
        shadowElevation = if (SocialMemoryColors.isLightMode) 8.dp else 0.dp,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("next_up_event_card")
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(SocialMemoryColors.primary, CircleShape)
                    )
                    Text(
                        text = "Next Up",
                        color = SocialMemoryColors.textSecondary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp
                    )
                }
                
                if (occurrenceCount > 1) {
                    Surface(
                        color = SocialMemoryColors.infoContainer,
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = "+${occurrenceCount - 1} related entries",
                            color = SocialMemoryColors.infoStrong,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            Text(
                text = event.title,
                color = SocialMemoryColors.textPrimary,
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold
            )

            Text(
                text = "${event.location ?: "Hybrid"} · $dateStr",
                color = SocialMemoryColors.textSecondary,
                fontSize = 14.sp
            )

            if (attendeesState.value.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    attendeesState.value.take(3).forEach { person ->
                        Surface(
                            color = SocialMemoryColors.infoContainer,
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.info.copy(alpha = 0.25f))
                        ) {
                            Text(
                                text = person.fullName,
                                fontSize = 11.sp,
                                color = SocialMemoryColors.infoStrong,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }
                    if (attendeesState.value.size > 3) {
                        Text(
                            text = "+${attendeesState.value.size - 3}",
                            color = SocialMemoryColors.textMuted,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun CompactEventRow(
    event: SocialEvent,
    occurrenceCount: Int,
    viewModel: AppViewModel
) {
    val dateStr = event.startTime?.let {
        SimpleDateFormat("EEE h:mm a", Locale.getDefault()).format(Date(it))
    } ?: "Unscheduled"
    
    val attendeesState = viewModel.getEventAttendees(event.id).collectAsStateWithLifecycle(emptyList())

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("upcoming_event_row"),
        color = SocialMemoryColors.surface,
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
        shadowElevation = if (SocialMemoryColors.isLightMode) 4.dp else 0.dp
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = event.title,
                        fontWeight = FontWeight.Bold,
                        color = SocialMemoryColors.textPrimary,
                        fontSize = 14.sp
                    )
                    
                    if (occurrenceCount > 1) {
                        Surface(
                            color = SocialMemoryColors.infoContainer,
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "+${occurrenceCount - 1} related",
                                color = SocialMemoryColors.infoStrong,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "${event.location ?: "Hybrid"} · $dateStr",
                    color = SocialMemoryColors.textSecondary,
                    fontSize = 12.sp
                )
                
                if (attendeesState.value.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        attendeesState.value.take(3).forEach { person ->
                            Surface(
                                color = SocialMemoryColors.infoContainer,
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.info.copy(alpha = 0.25f))
                            ) {
                                Text(
                                    text = person.fullName,
                                    fontSize = 10.sp,
                                    color = SocialMemoryColors.infoStrong,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }
                }
            }

            Text(
                text = event.startTime?.let {
                    SimpleDateFormat("EEEE", Locale.getDefault()).format(Date(it)).take(3)
                } ?: "",
                color = SocialMemoryColors.info,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

@Composable
fun NextSevenDaysSection(
    eventsList: List<SocialEvent>,
    viewModel: AppViewModel,
    onViewFullCalendarClick: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "NEXT 7 DAYS",
            color = SocialMemoryColors.textSecondary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
            modifier = Modifier.padding(horizontal = 4.dp)
        )

        if (eventsList.isEmpty()) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = SocialMemoryColors.surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                shadowElevation = if (SocialMemoryColors.isLightMode) 4.dp else 0.dp
            ) {
                Box(
                    modifier = Modifier.padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Event,
                            contentDescription = "No Events",
                            tint = SocialMemoryColors.textMuted,
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = "No social events scheduled this week.",
                            color = SocialMemoryColors.textSecondary,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        } else {
            val groupedByDayAndTitle = eventsList.groupBy { event ->
                val dayKey = event.startTime?.let {
                    SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(it))
                } ?: "unscheduled"
                "${event.title.trim().lowercase()}_${dayKey}"
            }
            
            val deduplicatedList = groupedByDayAndTitle.values.map {
                Pair(it.first(), it.size)
            }.sortedBy { it.first.startTime ?: Long.MAX_VALUE }

            val nextUp = deduplicatedList.first()
            val upcoming = deduplicatedList.drop(1).take(2)

            EventCard(
                event = nextUp.first,
                occurrenceCount = nextUp.second,
                viewModel = viewModel
            )

            upcoming.forEach { pair ->
                CompactEventRow(
                    event = pair.first,
                    occurrenceCount = pair.second,
                    viewModel = viewModel
                )
            }
            
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.CenterStart
            ) {
                Text(
                    text = "View Full Calendar",
                    color = SocialMemoryColors.primary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .clickable { onViewFullCalendarClick() }
                        .padding(vertical = 4.dp, horizontal = 4.dp)
                        .testTag("view_full_calendar_link")
                )
            }
        }
    }
}

@Composable
fun FollowUpRow(
    reminder: Reminder,
    linkedPersonName: String,
    onCheckedChange: () -> Unit,
    onDeleteClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clickable { onCheckedChange() }
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .testTag("followup_${reminder.id}")
    ) {
        Box(
            modifier = Modifier
                .minimumInteractiveComponentSize()
                .size(24.dp)
                .background(if (reminder.completed) SocialMemoryColors.primary else Color.Transparent, CircleShape)
                .border(BorderStroke(2.dp, SocialMemoryColors.primary), CircleShape)
                .clickable { onCheckedChange() },
            contentAlignment = Alignment.Center
        ) {
            if (reminder.completed) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Done",
                    tint = SocialMemoryColors.background,
                    modifier = Modifier.size(12.dp)
                )
            }
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = linkedPersonName,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                color = if (reminder.completed) SocialMemoryColors.textMuted else SocialMemoryColors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = reminder.title,
                fontSize = 13.sp,
                color = SocialMemoryColors.textSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        IconButton(
            onClick = onDeleteClick,
            modifier = Modifier
                .minimumInteractiveComponentSize()
                .size(24.dp)
                .testTag("delete_followup_${reminder.id}")
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Delete",
                tint = SocialMemoryColors.textMuted,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
fun FollowUpSection(
    followupsList: List<Reminder>,
    peopleList: List<Person>,
    onReminderAction: (Reminder) -> Unit,
    onReminderDelete: (Reminder) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            text = "FOLLOW UP",
            color = SocialMemoryColors.textSecondary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
            modifier = Modifier.padding(horizontal = 4.dp)
        )

        Surface(
            color = SocialMemoryColors.surface,
            border = BorderStroke(1.dp, if (SocialMemoryColors.isLightMode) SocialMemoryColors.borderStrong else SocialMemoryColors.borderSubtle),
            shape = RoundedCornerShape(24.dp),
            shadowElevation = if (SocialMemoryColors.isLightMode) 6.dp else 0.dp,
            modifier = Modifier.fillMaxWidth().testTag("follow_up_section_card")
        ) {
            Column {
                if (followupsList.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No active follow-ups. Outstanding!",
                            color = SocialMemoryColors.textMuted,
                            fontSize = 13.sp
                        )
                    }
                } else {
                    followupsList.forEachIndexed { index, reminder ->
                        val linkedPersonName = reminder.personId?.let { pid ->
                            peopleList.find { it.id == pid }?.fullName
                        } ?: "Contact Link"

                        FollowUpRow(
                            reminder = reminder,
                            linkedPersonName = linkedPersonName,
                            onCheckedChange = { onReminderAction(reminder) },
                            onDeleteClick = { onReminderDelete(reminder) }
                        )

                        if (index < followupsList.size - 1) {
                            HorizontalDivider(
                                color = SocialMemoryColors.borderSubtle,
                                thickness = 1.dp,
                                modifier = Modifier.padding(horizontal = 14.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun RecentUpdateRow(
    memory: Memory,
    personName: String
) {
    val dateStr = SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(memory.createdAt))
    val contentLower = memory.content.lowercase(Locale.getDefault())
    val (categoryColor, categoryLabel) = when {
        contentLower.contains("role") || contentLower.contains("architect") || contentLower.contains("work") || contentLower.contains("job") ->
            Pair(Sky500, "Work Update")
            
        contentLower.contains("injury") || contentLower.contains("injured") || contentLower.contains("shoulder") || contentLower.contains("health") || contentLower.contains("doctor") ->
            Pair(Amber500, "Health Update")
            
        contentLower.contains("japan") || contentLower.contains("travel") || contentLower.contains("trip") || contentLower.contains("moving") || contentLower.contains("out of town") ->
            Pair(Sky500, "Travel Update")
            
        else ->
            Pair(Teal500, "Confirmed Memory")
    }

    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp, horizontal = 14.dp)
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(36.dp)
                .background(categoryColor, RoundedCornerShape(100))
        )

        Column(modifier = Modifier.weight(1f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = personName,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = SocialMemoryColors.textPrimary
                )
                
                Text(
                    text = dateStr,
                    fontSize = 12.sp,
                    color = SocialMemoryColors.textMuted
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = memory.content,
                fontSize = 13.sp,
                color = SocialMemoryColors.textSecondary,
                lineHeight = 18.sp
            )
            
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .background(
                        when(categoryLabel) {
                            "Work Update", "Travel Update" -> SocialMemoryColors.infoContainer
                            "Health Update", "Review Update" -> SocialMemoryColors.warningContainer
                            else -> SocialMemoryColors.primaryContainer
                        }, 
                        RoundedCornerShape(8.dp)
                    )
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    text = categoryLabel,
                    color = when(categoryLabel) {
                        "Work Update", "Travel Update" -> SocialMemoryColors.infoStrong
                        "Health Update", "Review Update" -> SocialMemoryColors.warningStrong
                        else -> SocialMemoryColors.primaryStrong
                    },
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun RecentUpdatesSection(
    recentMemories: List<Memory>,
    peopleList: List<Person>
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            text = "RECENT UPDATES",
            color = SocialMemoryColors.textSecondary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
            modifier = Modifier.padding(horizontal = 4.dp)
        )

        Surface(
            color = SocialMemoryColors.surface,
            border = BorderStroke(1.dp, if (SocialMemoryColors.isLightMode) SocialMemoryColors.borderStrong else SocialMemoryColors.borderSubtle),
            shape = RoundedCornerShape(24.dp),
            shadowElevation = if (SocialMemoryColors.isLightMode) 6.dp else 0.dp,
            modifier = Modifier.fillMaxWidth().testTag("recent_updates_section_card")
        ) {
            Column {
                if (recentMemories.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Capture notes to record social memories securely.",
                            color = SocialMemoryColors.textMuted,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                } else {
                    recentMemories.forEachIndexed { index, memory ->
                        val personName = memory.personId?.let { pid ->
                            peopleList.find { it.id == pid }?.fullName
                        } ?: "General Update"

                        RecentUpdateRow(
                            memory = memory,
                            personName = personName
                        )

                        if (index < recentMemories.size - 1) {
                            HorizontalDivider(
                                color = SocialMemoryColors.borderSubtle,
                                thickness = 1.dp,
                                modifier = Modifier.padding(horizontal = 14.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun HomeScreen(viewModel: AppViewModel, modifier: Modifier) {
    val people by viewModel.allPeople.collectAsStateWithLifecycle()
    val events by viewModel.allEvents.collectAsStateWithLifecycle()
    val memories by viewModel.allMemories.collectAsStateWithLifecycle()
    val reminders by viewModel.activeReminders.collectAsStateWithLifecycle()
    val relationships by viewModel.allRelationships.collectAsStateWithLifecycle()
    val allGroups by viewModel.allGroups.collectAsStateWithLifecycle()
    val groupMembersState by viewModel.allGroupMembers.collectAsStateWithLifecycle()

    var selectedGroupId by remember { mutableStateOf<Int?>(null) }
    var showGroupFilterDialog by remember { mutableStateOf(false) }
    var actioningReminder by remember { mutableStateOf<Reminder?>(null) }
    var dismissedReviewCard by remember { mutableStateOf(false) }

    val currentTimestamp = System.currentTimeMillis()
    val sevenDaysFromNow = currentTimestamp + (7 * 24 * 60 * 60 * 1000)

    val filteredPersonIds = remember(groupMembersState, selectedGroupId) {
        if (selectedGroupId == null) emptySet()
        else groupMembersState.filter { it.groupId == selectedGroupId }.map { it.personId }.toSet()
    }
    
    val connectedCals by viewModel.connectedExternalCalendars.collectAsStateWithLifecycle()

    val next7DaysEvents = remember(events, selectedGroupId, filteredPersonIds, connectedCals) {
        val filtered = if (selectedGroupId == null) {
            events
        } else {
            events.filter { event ->
                event.groupId == selectedGroupId
            }
        }
        
        val baseEvents = filtered.filter { event ->
            event.startTime != null && event.startTime >= (currentTimestamp - 2 * 3600 * 1000) && event.startTime <= sevenDaysFromNow
        }.toMutableList()
        
        // Mock external events based on connected calendars
        if (connectedCals.isNotEmpty()) {
            connectedCals.forEachIndexed { index, calName ->
                baseEvents.add(
                    com.example.data.SocialEvent(
                        id = -(index + 1), // Negative IDs for mock external
                        title = "External Event ($calName)",
                        startTime = currentTimestamp + (24 * 3600 * 1000) + (index * 3600 * 1000), // Sometime tomorrow
                        confidenceState = "confirmed"
                    )
                )
            }
        }
        
        baseEvents.sortedBy { it.startTime }
    }

    val upcomingFollowups = remember(reminders, selectedGroupId, filteredPersonIds) {
        val active = reminders.filter { !it.completed }
        if (selectedGroupId == null) {
            active.take(4)
        } else {
            active.filter { reminder ->
                reminder.personId != null && filteredPersonIds.contains(reminder.personId)
            }
        }
    }

    val unresolvedCount = remember(events, memories) {
        events.count { it.confidenceState != "confirmed" } + memories.count { it.confidenceState != "confirmed" }
    }

    val recentMemories = remember(memories, selectedGroupId, filteredPersonIds) {
        if (selectedGroupId == null) {
            memories.take(4)
        } else {
            memories.filter { memory ->
                memory.groupId == selectedGroupId ||
                (memory.personId != null && filteredPersonIds.contains(memory.personId))
            }
        }
    }

    val sdfRange = remember {
        val cal = Calendar.getInstance()
        val startStr = SimpleDateFormat("MMM d", Locale.getDefault()).format(cal.time)
        cal.add(Calendar.DAY_OF_YEAR, 6)
        val endStr = SimpleDateFormat("MMM d", Locale.getDefault()).format(cal.time)
        "$startStr — $endStr"
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(SocialMemoryColors.background)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 168.dp)
    ) {
        item {
            HomeHeader(
                onNavigateNotifications = { viewModel.setTab(AppScreen.Notifications) },
                onNavigateSettings = { viewModel.setTab(AppScreen.Settings) }
            )
        }

        item {
            val selectedGroupName = if (selectedGroupId == null) {
                "All Circles"
            } else {
                allGroups.find { it.id == selectedGroupId }?.groupName?.uppercase() ?: "CIRCLE BOARD"
            }
            SevenDayOutlookHeader(
                dateRange = sdfRange,
                selectedGroupText = selectedGroupName,
                onFilterClick = { showGroupFilterDialog = true }
            )
        }

        if (unresolvedCount > 0 && !dismissedReviewCard) {
            item {
                NeedsReviewCard(
                    unresolvedCount = unresolvedCount,
                    onReviewClick = { viewModel.setTab(AppScreen.Capture) },
                    onDismissClick = { dismissedReviewCard = true }
                )
            }
        }

        item {
            NextSevenDaysSection(
                eventsList = next7DaysEvents,
                viewModel = viewModel,
                onViewFullCalendarClick = { viewModel.setTab(AppScreen.Calendar) }
            )
        }

        item {
            FollowUpSection(
                followupsList = upcomingFollowups,
                peopleList = people,
                onReminderAction = { actioningReminder = it },
                onReminderDelete = { viewModel.deleteReminder(it) }
            )
        }

        item {
            RecentUpdatesSection(
                recentMemories = recentMemories,
                peopleList = people
            )
        }
    }

    if (showGroupFilterDialog) {
        AlertDialog(
            onDismissRequest = { showGroupFilterDialog = false },
            containerColor = SocialMemoryColors.surfaceRaised,
            title = {
                Text(
                    text = "Select Circle Filter",
                    color = SocialMemoryColors.textPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "Filter dashboard events, follow-ups, and notes by a specific group context:",
                        color = SocialMemoryColors.textMuted,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    
                    // Option All
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                selectedGroupId = null
                                showGroupFilterDialog = false
                            }
                            .testTag("filter_all_groups"),
                        color = if (selectedGroupId == null) SocialMemoryColors.primary.copy(alpha = 0.12f) else SocialMemoryColors.surfaceRaised,
                        shape = RoundedCornerShape(12.dp),
                        border = if (selectedGroupId == null) BorderStroke(1.dp, SocialMemoryColors.primary.copy(alpha = 0.2f)) else BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Groups,
                                contentDescription = "All Groups",
                                tint = if (selectedGroupId == null) SocialMemoryColors.primary else SocialMemoryColors.textMuted,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = "All Circles",
                                color = if (selectedGroupId == null) SocialMemoryColors.primary else SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }
                    }

                    // Option for each Group
                    allGroups.forEach { group ->
                        val isSelected = selectedGroupId == group.id
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    selectedGroupId = group.id
                                    showGroupFilterDialog = false
                                }
                                .testTag("filter_group_${group.id}"),
                            color = if (isSelected) SocialMemoryColors.primary.copy(alpha = 0.12f) else SocialMemoryColors.surfaceRaised,
                            shape = RoundedCornerShape(12.dp),
                            border = if (isSelected) BorderStroke(1.dp, SocialMemoryColors.primary.copy(alpha = 0.2f)) else BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                        ) {
                            Row(
                                modifier = Modifier.padding(14.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.GroupWork,
                                    contentDescription = "Group",
                                    tint = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textMuted,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = group.groupName.uppercase(),
                                        color = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textPrimary,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                    if (!group.description.isNullOrEmpty()) {
                                        Text(
                                            text = group.description,
                                            color = SocialMemoryColors.textMuted,
                                            fontSize = 11.sp
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showGroupFilterDialog = false }) {
                    Text("Close", color = SocialMemoryColors.primary, fontWeight = FontWeight.Bold)
                }
            },
            shape = RoundedCornerShape(28.dp)
        )
    }

    if (actioningReminder != null) {
        val reminder = actioningReminder!!
        val linkedPerson = people.find { it.id == reminder.personId }
        
        var followupNotes by remember { mutableStateOf("") }
        var selectEventOpen by remember { mutableStateOf(false) }
        var selectedEventId by remember { mutableStateOf<Int?>(null) }
        var eventLocationInput by remember { mutableStateOf("") }

        val selectedEvent = remember(selectedEventId, events) {
            events.find { it.id == selectedEventId }
        }

        // Set initial event location input when an event is selected
        LaunchedEffect(selectedEvent) {
            if (selectedEvent != null) {
                eventLocationInput = selectedEvent.location ?: ""
            }
        }

        AlertDialog(
            onDismissRequest = { actioningReminder = null },
            containerColor = SocialMemoryColors.surfaceRaised,
            title = {
                Column {
                    Text(
                        text = "Log Action Details",
                        color = SocialMemoryColors.textPrimary,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = reminder.title,
                        color = SocialMemoryColors.primary,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    if (linkedPerson != null) {
                        Surface(
                            color = SocialMemoryColors.surfaceRaised,
                            border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(SocialMemoryColors.primary.copy(alpha = 0.12f), CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = linkedPerson.fullName.take(1).uppercase(),
                                        color = SocialMemoryColors.primary,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Text(
                                    text = "Actioned with: ${linkedPerson.fullName}",
                                    color = SocialMemoryColors.textSecondary,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    // Notes input
                    Text(
                        text = "WHAT DID THEY SAY?", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 10.sp, 
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp
                    )
                    OutlinedTextField(
                        value = followupNotes,
                        onValueChange = { followupNotes = it },
                        placeholder = {
                            Text(
                                text = "E.g. She said Kyoto hotels were great.",
                                color = SocialMemoryColors.textMuted,
                                fontSize = 12.sp
                            )
                        },
                        modifier = Modifier.fillMaxWidth().testTag("followup_additional_notes"),
                        textStyle = TextStyle(fontSize = 13.sp, color = SocialMemoryColors.textPrimary),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp),
                        maxLines = 4
                    )

                    // Event Selector header
                    Text(
                        text = "LINK TO UPDATE AN EVENT (OPTIONAL)", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 10.sp, 
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp
                    )
                    
                    // Simulating a custom dropdown select
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectEventOpen = !selectEventOpen },
                        color = SocialMemoryColors.surfaceRaised,
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = selectedEvent?.title ?: "Select Event to link location/info",
                                color = if (selectedEvent != null) SocialMemoryColors.textPrimary else SocialMemoryColors.textMuted,
                                fontSize = 13.sp,
                                fontWeight = if (selectedEvent != null) FontWeight.Medium else FontWeight.Normal
                            )
                            Icon(
                                imageVector = if (selectEventOpen) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                                contentDescription = "Expand",
                                tint = SocialMemoryColors.textMuted,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }

                    if (selectEventOpen) {
                        Surface(
                            color = SocialMemoryColors.surfaceRaised,
                            border = BorderStroke(1.dp, SocialMemoryColors.primary.copy(alpha = 0.2f)),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth(),
                            shadowElevation = 4.dp
                        ) {
                            Column {
                                // None trigger
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            selectedEventId = null
                                            selectEventOpen = false
                                        }
                                        .padding(14.dp)
                                ) {
                                    Text(
                                        text = "None (Do not link event)", 
                                        color = SocialMemoryColors.primary, 
                                        fontSize = 12.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                events.forEach { ev ->
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                selectedEventId = ev.id
                                                selectEventOpen = false
                                            }
                                            .padding(14.dp)
                                    ) {
                                        Text(
                                            text = ev.title, 
                                            color = SocialMemoryColors.textPrimary, 
                                            fontSize = 13.sp
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // If event is selected, allow location field
                    if (selectedEvent != null) {
                        Text(
                            text = "UPDATE EVENT LOCATION", 
                            color = SocialMemoryColors.textMuted, 
                            fontSize = 10.sp, 
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 0.5.sp
                        )
                        OutlinedTextField(
                            value = eventLocationInput,
                            onValueChange = { eventLocationInput = it },
                            placeholder = { 
                                Text(
                                    text = "E.g. Bar Isabel, Hanlan's Point", 
                                    color = SocialMemoryColors.textMuted, 
                                    fontSize = 12.sp
                                ) 
                            },
                            modifier = Modifier.fillMaxWidth().testTag("followup_event_location_input"),
                            textStyle = TextStyle(fontSize = 13.sp, color = SocialMemoryColors.textPrimary),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SocialMemoryColors.primary,
                                unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                                focusedTextColor = SocialMemoryColors.textPrimary,
                                unfocusedTextColor = SocialMemoryColors.textPrimary
                            ),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.actionReminder(
                            reminder = reminder,
                            notes = followupNotes,
                            eventId = selectedEventId,
                            eventLocation = if (selectedEventId != null) eventLocationInput else null
                        )
                        actioningReminder = null
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.primary, 
                        contentColor = SocialMemoryColors.textOnAccent
                    ),
                    modifier = Modifier.testTag("confirm_action_followup_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Save & Complete", fontWeight = FontWeight.Black)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { actioningReminder = null }
                ) {
                    Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                }
            },
            shape = RoundedCornerShape(28.dp)
        )
    }
}

// ==========================================
// NEW: COMMUNITIES SCREEN (PEOPLE & GROUPS)
// ==========================================

@Composable
fun CommunitiesScreen(viewModel: AppViewModel, modifier: Modifier) {
    var selectedTab by remember { mutableStateOf(0) }
    Column(modifier = modifier.fillMaxSize().background(SocialMemoryColors.background)) {
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = SocialMemoryColors.background,
            contentColor = SocialMemoryColors.primary,
            indicator = { tabPositions ->
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                    color = SocialMemoryColors.primary
                )
            },
            divider = {
                HorizontalDivider(color = SocialMemoryColors.borderSubtle)
            }
        ) {
            Tab(
                selected = selectedTab == 0,
                onClick = { selectedTab = 0 },
                text = { 
                    Text(
                        text = "People", 
                        color = if (selectedTab == 0) SocialMemoryColors.primary else SocialMemoryColors.textMuted, 
                        fontWeight = if (selectedTab == 0) FontWeight.Black else FontWeight.Bold,
                        fontSize = 15.sp
                    ) 
                }
            )
            Tab(
                selected = selectedTab == 1,
                onClick = { selectedTab = 1 },
                text = { 
                    Text(
                        text = "Friend Circles", 
                        color = if (selectedTab == 1) SocialMemoryColors.primary else SocialMemoryColors.textMuted, 
                        fontWeight = if (selectedTab == 1) FontWeight.Black else FontWeight.Bold,
                        fontSize = 15.sp
                    ) 
                }
            )
        }

        Box(modifier = Modifier.weight(1f)) {
            // Reusing existing screens, but passing an empty modifier so they handle their own layouts properly.
            // We strip any outer padded modifiers since Scaffold handles padding internally.
            if (selectedTab == 0) {
                PeopleScreen(viewModel, Modifier)
            } else {
                GroupsScreen(viewModel, Modifier)
            }
        }
    }
}

// ==========================================
// NEW: ASK ME SCREEN (CHAT)
// ==========================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AskScreen(viewModel: AppViewModel, modifier: Modifier) {
    val chatHistory by viewModel.recallChatHistory.collectAsStateWithLifecycle()
    val people by viewModel.allPeople.collectAsStateWithLifecycle()
    
    var question by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val listState = androidx.compose.foundation.lazy.rememberLazyListState()
    var driftPromptMessage by remember { mutableStateOf<String?>(null) }
    var reportIssueDialogVisible by remember { mutableStateOf(false) }
    var upgradeDialogVisible by remember { mutableStateOf(false) }
    val clipboardManager = androidx.compose.ui.platform.LocalClipboardManager.current

    val executeQuery = { queryText: String ->
        if (chatHistory.count { it.isUser } >= 3) {
            upgradeDialogVisible = true
        } else {
            question = "" // Clear the input UI
            isLoading = true
            scope.launch {
                viewModel.askQuestionOnline(queryText)
                val currentHistory = viewModel.recallChatHistory.value
                val lastMsg = currentHistory.lastOrNull()
                if (lastMsg != null && lastMsg.isDriftMessage) {
                    driftPromptMessage = lastMsg.text
                }
                isLoading = false
                listState.animateScrollToItem(viewModel.recallChatHistory.value.size) // scroll to latest
            }
        }
    }

    Scaffold(
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        val density = androidx.compose.ui.platform.LocalDensity.current
        val isImeVisible = androidx.compose.foundation.layout.WindowInsets.ime.getBottom(density) > 0
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = innerPadding.calculateTopPadding())
                .padding(horizontal = 16.dp)
                .padding(bottom = if (isImeVisible) 12.dp else 120.dp)
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header Row with Clear Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Recall Social Insights", color = SocialMemoryColors.textPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                
                if (chatHistory.isNotEmpty()) {
                    IconButton(onClick = { viewModel.clearRecallChat() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Clear Chat", tint = SocialMemoryColors.primary)
                    }
                }
            }

            if (chatHistory.isEmpty()) {
                // Intro text & recommendations
                Text(
                    "Instantly query and recall key updates, timeline milestones, or shared moments across your friends and trusted circles.",
                    color = SocialMemoryColors.textSecondary,
                    fontSize = 14.sp
                )

                Spacer(modifier = Modifier.weight(1f))

                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "SUGGESTED RECALLS",
                        color = SocialMemoryColors.textMuted,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        style = TextStyle(letterSpacing = 1.sp)
                    )

                    val suggestions = listOf(
                        "Who in my circles should I follow up with soon?",
                        "What are the latest updates captured regarding Michelle or Alex?",
                        "Are there any upcoming circle events or active review items?"
                    )

                    suggestions.forEach { suggestion ->
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { executeQuery(suggestion) },
                            color = SocialMemoryColors.surface,
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                            shadowElevation = if (SocialMemoryColors.isLightMode) 2.dp else 0.dp
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ChatBubbleOutline,
                                    contentDescription = "Suggested prompt",
                                    tint = SocialMemoryColors.primary,
                                    modifier = Modifier.size(18.dp)
                                )
                                Text(
                                    text = suggestion,
                                    color = SocialMemoryColors.textPrimary,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            } else {
                // Chat sequence
                androidx.compose.foundation.lazy.LazyColumn(
                    state = listState,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(chatHistory.size) { index ->
                        val msg = chatHistory[index]
                        var showMenu by remember { mutableStateOf(false) }
                        
                        Box {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = if (msg.isUser) Arrangement.End else Arrangement.Start
                            ) {
                                FormattedChatBubble(
                                    text = msg.text,
                                    isUser = msg.isUser,
                                    peopleList = people,
                                    onPersonClick = { personId -> viewModel.navigateTo(AppScreen.PersonDetail(personId)) },
                                    onLongPress = { showMenu = true }
                                )
                            }
                            
                            androidx.compose.material3.DropdownMenu(
                                expanded = showMenu,
                                onDismissRequest = { showMenu = false }
                            ) {
                                if (msg.isUser) {
                                    androidx.compose.material3.DropdownMenuItem(
                                        text = { Text("Edit") },
                                        onClick = { 
                                            question = msg.text
                                            showMenu = false 
                                        }
                                    )
                                    androidx.compose.material3.DropdownMenuItem(
                                        text = { Text("Copy Text") },
                                        onClick = { 
                                            clipboardManager.setText(androidx.compose.ui.text.AnnotatedString(msg.text))
                                            showMenu = false 
                                        }
                                    )
                                } else {
                                    androidx.compose.material3.DropdownMenuItem(
                                        text = { Text("Copy Text") },
                                        onClick = { 
                                            clipboardManager.setText(androidx.compose.ui.text.AnnotatedString(msg.text))
                                            showMenu = false 
                                        }
                                    )
                                    androidx.compose.material3.DropdownMenuItem(
                                        text = { Text("Report an Issue") },
                                        onClick = { 
                                            reportIssueDialogVisible = true
                                            showMenu = false 
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if (isLoading) {
                        item {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
                                Surface(
                                    color = SocialMemoryColors.surfaceRaised,
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.padding(vertical = 4.dp).padding(end = 40.dp)
                                ) {
                                    Box(modifier = Modifier.padding(16.dp)) {
                                        CircularProgressIndicator(modifier = Modifier.size(20.dp), color = SocialMemoryColors.primary, strokeWidth = 2.dp)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Input Row
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = question,
                    onValueChange = { question = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Ask about someone (@)...", color = SocialMemoryColors.textMuted) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SocialMemoryColors.primary,
                        unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                        focusedTextColor = SocialMemoryColors.textPrimary,
                        unfocusedTextColor = SocialMemoryColors.textPrimary,
                        focusedContainerColor = SocialMemoryColors.surfaceRaised,
                        unfocusedContainerColor = SocialMemoryColors.surfaceRaised
                    ),
                    maxLines = 3,
                    shape = RoundedCornerShape(24.dp)
                )
                
                IconButton(
                    onClick = { 
                        if (question.isNotBlank()) {
                            executeQuery(question)
                        }
                    },
                    modifier = Modifier
                        .size(48.dp)
                        .background(if (question.isNotBlank()) SocialMemoryColors.primary else SocialMemoryColors.surfaceRaised, CircleShape),
                    enabled = question.isNotBlank() && !isLoading
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send, 
                        contentDescription = "Send", 
                        tint = if (question.isNotBlank()) SocialMemoryColors.background else SocialMemoryColors.textMuted
                    )
                }
            }
        }

        if (driftPromptMessage != null) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { driftPromptMessage = null },
                title = { Text("Topic Changed?") },
                text = { Text("It looks like this question is unrelated to the previous chat. Would you like to clear the chat history and start a new topic, or continue in this thread?") },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = { 
                        viewModel.clearRecallChatKeepLastTwo()
                        driftPromptMessage = null 
                    }) {
                        Text("Reset & Start New")
                    }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { driftPromptMessage = null }) {
                        Text("Continue")
                    }
                }
            )
        }
        
        if (reportIssueDialogVisible) {
            var issueText by remember { mutableStateOf("") }
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { reportIssueDialogVisible = false },
                title = { Text("Report an Issue") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("What was wrong with this response?", fontSize = 14.sp)
                        OutlinedTextField(
                            value = issueText,
                            onValueChange = { issueText = it },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = { 
                        reportIssueDialogVisible = false 
                    }) {
                        Text("Submit")
                    }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { reportIssueDialogVisible = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        if (upgradeDialogVisible) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { upgradeDialogVisible = false },
                title = { Text("Usage Limit Reached") },
                text = { Text("You have reached your maximum limit of 3 prompts for this session. Please upgrade your usage limit to continue.") },
                confirmButton = {
                    androidx.compose.material3.Button(onClick = { upgradeDialogVisible = false }) {
                        Text("Upgrade")
                    }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { upgradeDialogVisible = false }) {
                        Text("Later")
                    }
                }
            )
        }
    }
}

sealed class ChatBlock {
    data class Heading(val level: Int, val text: String) : ChatBlock()
    data class Bullet(val text: String) : ChatBlock()
    data class Numbered(val number: String, val text: String) : ChatBlock()
    data class Paragraph(val text: String) : ChatBlock()
}

fun parseTextToBlocks(text: String): List<ChatBlock> {
    val lines = text.split("\n")
    val blocks = mutableListOf<ChatBlock>()
    for (line in lines) {
        val trimmed = line.trim()
        if (trimmed.isEmpty()) {
            continue
        }
        if (trimmed.startsWith("###")) {
            blocks.add(ChatBlock.Heading(3, trimmed.removePrefix("###").trim()))
        } else if (trimmed.startsWith("##")) {
            blocks.add(ChatBlock.Heading(2, trimmed.removePrefix("##").trim()))
        } else if (trimmed.startsWith("#")) {
            blocks.add(ChatBlock.Heading(1, trimmed.removePrefix("#").trim()))
        } else if (trimmed.startsWith("* ") || trimmed.startsWith("- ")) {
            blocks.add(ChatBlock.Bullet(trimmed.substring(2).trim()))
        } else {
            val numberedMatch = "^(\\d+)\\.\\s+(.*)$".toRegex().matchEntire(trimmed)
            if (numberedMatch != null) {
                val num = numberedMatch.groupValues[1]
                val content = numberedMatch.groupValues[2]
                blocks.add(ChatBlock.Numbered(num, content))
            } else {
                blocks.add(ChatBlock.Paragraph(line))
            }
        }
    }
    return blocks
}

@Composable
fun renderInlineMarkdown(text: String): AnnotatedString {
    return buildAnnotatedString {
        var currentIndex = 0
        while (currentIndex < text.length) {
            val nextPerson = text.indexOf("[@", currentIndex)
            val nextBold = text.indexOf("**", currentIndex)
            val nextItalic = text.indexOf("*", currentIndex)
            
            var activeBold = if (nextBold != -1) nextBold else Int.MAX_VALUE
            var activePerson = if (nextPerson != -1) nextPerson else Int.MAX_VALUE
            
            var activeItalic = Int.MAX_VALUE
            if (nextItalic != -1) {
                if (nextItalic == nextBold) {
                    val lookAheadItalic = text.indexOf("*", nextBold + 2)
                    if (lookAheadItalic != -1) {
                        activeItalic = lookAheadItalic
                    }
                } else {
                    activeItalic = nextItalic
                }
            }
            
            val minIndex = minOf(activePerson, activeBold, activeItalic)
            if (minIndex == Int.MAX_VALUE) {
                append(text.substring(currentIndex))
                break
            }
            
            if (minIndex > currentIndex) {
                append(text.substring(currentIndex, minIndex))
                currentIndex = minIndex
            }
            
            if (minIndex == activePerson) {
                val closingBracket = text.indexOf("]", currentIndex)
                if (closingBracket != -1) {
                    val name = text.substring(currentIndex + 2, closingBracket)
                    pushStringAnnotation(tag = "person", annotation = name)
                    withStyle(style = SpanStyle(color = SocialMemoryColors.info, fontWeight = FontWeight.Bold)) {
                        append("@$name")
                    }
                    pop()
                    currentIndex = closingBracket + 1
                } else {
                    append("[@")
                    currentIndex += 2
                }
            } else if (minIndex == activeBold) {
                val closingBold = text.indexOf("**", currentIndex + 2)
                if (closingBold != -1) {
                    val boldContent = text.substring(currentIndex + 2, closingBold)
                    withStyle(style = SpanStyle(fontWeight = FontWeight.Bold)) {
                        append(boldContent)
                    }
                    currentIndex = closingBold + 2
                } else {
                    append("**")
                    currentIndex += 2
                }
            } else {
                val closingItalic = text.indexOf("*", currentIndex + 1)
                if (closingItalic != -1) {
                    val italicContent = text.substring(currentIndex + 1, closingItalic)
                    withStyle(style = SpanStyle(fontStyle = FontStyle.Italic)) {
                        append(italicContent)
                    }
                    currentIndex = closingItalic + 1
                } else {
                    append("*")
                    currentIndex += 1
                }
            }
        }
    }
}

@Composable
fun FormattedChatBubble(text: String, isUser: Boolean, peopleList: List<Person>, onPersonClick: (Int) -> Unit, onLongPress: () -> Unit = {}) {
    val bubbleColor = if (isUser) SocialMemoryColors.primary else SocialMemoryColors.surfaceRaised
    val textColor = if (isUser) SocialMemoryColors.background else SocialMemoryColors.textPrimary

    Surface(
        color = bubbleColor,
        shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = if (isUser) 16.dp else 4.dp, bottomEnd = if (isUser) 4.dp else 16.dp),
        border = if (isUser) null else BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
        shadowElevation = if (SocialMemoryColors.isLightMode) 1.dp else 0.dp,
        modifier = Modifier
            .padding(vertical = 4.dp)
            .widthIn(max = 300.dp)
            .pointerInput(text) {
                detectTapGestures(
                    onLongPress = { onLongPress() }
                )
            }
    ) {
        if (isUser) {
            Text(
                text = text,
                color = textColor,
                fontSize = 15.sp,
                lineHeight = 22.sp,
                modifier = Modifier.padding(14.dp)
            )
        } else {
            val blocks = remember(text) { parseTextToBlocks(text) }
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                blocks.forEach { block ->
                    when (block) {
                        is ChatBlock.Heading -> {
                            val headingSize = when (block.level) {
                                1 -> 20.sp
                                2 -> 18.sp
                                else -> 16.sp
                            }
                            val headingColor = if (block.level <= 2) SocialMemoryColors.primary else SocialMemoryColors.textPrimary
                            val annotatedHeading = renderInlineMarkdown(block.text)
                            
                            ClickableText(
                                text = annotatedHeading,
                                onClick = { offset ->
                                    annotatedHeading.getStringAnnotations(tag = "person", start = offset, end = offset)
                                        .firstOrNull()?.let { annotation ->
                                            val nameStr = annotation.item
                                            val matchedPerson = peopleList.find { 
                                                it.fullName.equals(nameStr, ignoreCase = true) || 
                                                (!it.nickname.isNullOrBlank() && it.nickname.equals(nameStr, ignoreCase = true)) 
                                            }
                                            if (matchedPerson != null) {
                                                onPersonClick(matchedPerson.id)
                                            }
                                        }
                                },
                                style = TextStyle(
                                    color = headingColor,
                                    fontSize = headingSize,
                                    fontWeight = FontWeight.Bold,
                                    lineHeight = (headingSize.value + 6).sp
                                )
                            )
                        }
                        is ChatBlock.Bullet -> {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "•",
                                    color = SocialMemoryColors.primary,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                val annotatedBullet = renderInlineMarkdown(block.text)
                                ClickableText(
                                    text = annotatedBullet,
                                    onClick = { offset ->
                                        annotatedBullet.getStringAnnotations(tag = "person", start = offset, end = offset)
                                            .firstOrNull()?.let { annotation ->
                                                val nameStr = annotation.item
                                                val matchedPerson = peopleList.find { 
                                                    it.fullName.equals(nameStr, ignoreCase = true) || 
                                                    (!it.nickname.isNullOrBlank() && it.nickname.equals(nameStr, ignoreCase = true)) 
                                                }
                                                if (matchedPerson != null) {
                                                    onPersonClick(matchedPerson.id)
                                                }
                                            }
                                    },
                                    modifier = Modifier.weight(1f),
                                    style = TextStyle(
                                        color = textColor,
                                        fontSize = 15.sp,
                                        lineHeight = 22.sp
                                    )
                                )
                            }
                        }
                        is ChatBlock.Numbered -> {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "${block.number}.",
                                    color = SocialMemoryColors.info,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                val annotatedNumbered = renderInlineMarkdown(block.text)
                                ClickableText(
                                    text = annotatedNumbered,
                                    onClick = { offset ->
                                        annotatedNumbered.getStringAnnotations(tag = "person", start = offset, end = offset)
                                            .firstOrNull()?.let { annotation ->
                                                val nameStr = annotation.item
                                                val matchedPerson = peopleList.find { 
                                                    it.fullName.equals(nameStr, ignoreCase = true) || 
                                                    (!it.nickname.isNullOrBlank() && it.nickname.equals(nameStr, ignoreCase = true)) 
                                                }
                                                if (matchedPerson != null) {
                                                    onPersonClick(matchedPerson.id)
                                                }
                                            }
                                    },
                                    modifier = Modifier.weight(1f),
                                    style = TextStyle(
                                        color = textColor,
                                        fontSize = 15.sp,
                                        lineHeight = 22.sp
                                    )
                                )
                            }
                        }
                        is ChatBlock.Paragraph -> {
                            val annotatedText = renderInlineMarkdown(block.text)
                            ClickableText(
                                text = annotatedText,
                                onClick = { offset ->
                                    annotatedText.getStringAnnotations(tag = "person", start = offset, end = offset)
                                        .firstOrNull()?.let { annotation ->
                                            val nameStr = annotation.item
                                            val matchedPerson = peopleList.find { 
                                                it.fullName.equals(nameStr, ignoreCase = true) || 
                                                (!it.nickname.isNullOrBlank() && it.nickname.equals(nameStr, ignoreCase = true)) 
                                            }
                                            if (matchedPerson != null) {
                                                onPersonClick(matchedPerson.id)
                                            }
                                        }
                                },
                                style = TextStyle(
                                    color = textColor,
                                    fontSize = 15.sp,
                                    lineHeight = 22.sp
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 2. PEOPLE TAB SCREEN
// ==========================================

@Composable
fun PeopleScreen(viewModel: AppViewModel, modifier: Modifier) {
    val appSettings by viewModel.appSettings.collectAsStateWithLifecycle()
    val isLightMode = appSettings?.themeMode == "LIGHT"
    val people by viewModel.allPeople.collectAsStateWithLifecycle()
    var searchQuery by remember { mutableStateOf("") }
    var showContactPrivacyDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val filteredPeople = remember(searchQuery, people) {
        val filtered = if (searchQuery.isEmpty()) {
            people
        } else {
            people.filter {
                it.fullName.contains(searchQuery, ignoreCase = true) ||
                        (it.nickname?.contains(searchQuery, ignoreCase = true) ?: false) ||
                        (it.location?.contains(searchQuery, ignoreCase = true) ?: false)
            }
        }
        filtered.sortedByDescending { it.isSelf }
    }

    if (showContactPrivacyDialog) {
        AlertDialog(
            onDismissRequest = { showContactPrivacyDialog = false },
            containerColor = SocialMemoryColors.surfaceRaised,
            confirmButton = {
                Button(
                    onClick = {
                        showContactPrivacyDialog = false
                        viewModel.importContacts(context) { count ->
                            // Success callback hook
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.primary,
                        contentColor = SocialMemoryColors.textOnAccent
                    ),
                    modifier = Modifier.testTag("accept_privacy_promise")
                ) {
                    Text("I Agree, Import Contacts", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showContactPrivacyDialog = false }
                ) {
                    Text("Reject / Go Back", color = SocialMemoryColors.textMuted)
                }
            },
            icon = {
                Icon(
                    imageVector = Icons.Default.Contacts,
                    contentDescription = "Contacts Sync Protection",
                    tint = SocialMemoryColors.primary,
                    modifier = Modifier.size(36.dp)
                )
            },
            title = {
                Text(
                    "Contacts Integration Privacy Promise",
                    color = SocialMemoryColors.textPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "Social Brain tracks your friends offline. To make capture fast and tag details flawlessly, you can optionally sync your device address book.",
                        color = SocialMemoryColors.textSecondary,
                        fontSize = 13.sp,
                        lineHeight = 18.sp
                    )
                    Surface(
                        color = SocialMemoryColors.surface,
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text("🔒 100% Offline Promise", color = SocialMemoryColors.primary, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            Text(
                                "Your contacts directory is processed entirely within your device's sandbox. We NEVER upload, analyze, or lease your family's or friends' data to any remote cloud databases or centralized servers.",
                                color = SocialMemoryColors.textMuted,
                                fontSize = 11.sp,
                                lineHeight = 15.sp
                            )
                        }
                    }
                    Text(
                        "Opt-in is required to request contact reading permission.",
                        color = SocialMemoryColors.textMuted,
                        fontSize = 11.sp
                    )
                }
            },
            shape = RoundedCornerShape(24.dp)
        )
    }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.navigateTo(AppScreen.AddPerson) },
                containerColor = SocialMemoryColors.primary,
                contentColor = SocialMemoryColors.textOnAccent
            ) {
                Icon(Icons.Default.Add, "Add Person")
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("People Index", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, color = SocialMemoryColors.textPrimary)
                Button(
                    onClick = { showContactPrivacyDialog = true },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.primary.copy(alpha = 0.1f), 
                        contentColor = SocialMemoryColors.primary
                    ),
                    border = BorderStroke(1.dp, SocialMemoryColors.primary),
                    shape = RoundedCornerShape(100),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    modifier = Modifier.height(32.dp).testTag("sync_contacts_btn")
                ) {
                    Icon(Icons.Default.Contacts, contentDescription = "Sync", modifier = Modifier.size(14.dp), tint = SocialMemoryColors.primary)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Sync Contacts", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }

            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("Search friends, locations, nicknames...", color = SocialMemoryColors.textMuted) },
                leadingIcon = { Icon(Icons.Default.Search, "Search", tint = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp),
                singleLine = true
            )

            if (filteredPeople.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.PeopleOutline, "Empty", tint = SocialMemoryColors.textMuted, modifier = Modifier.size(48.dp))
                        Text("No friends or connections found here.", color = SocialMemoryColors.textMuted, fontSize = 14.sp)
                    }
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 168.dp)
                ) {
                    items(filteredPeople) { person ->
                        Surface(
                            color = SocialMemoryColors.surface,
                            shape = RoundedCornerShape(20.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                            shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { viewModel.navigateTo(AppScreen.PersonDetail(person.id)) }
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    // Custom Adaptive Colored Avatar
                                    Box(
                                        modifier = Modifier
                                            .size(44.dp)
                                            .background(
                                                Brush.linearGradient(listOf(SocialMemoryColors.primary, SocialMemoryColors.info)),
                                                CircleShape
                                            ),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            person.fullName.take(1).uppercase(),
                                            color = SocialMemoryColors.textOnAccent,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 18.sp
                                        )
                                    }

                                    Column {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                                        ) {
                                            val displayName = if (person.isSelf) "${person.fullName} (me)" else person.fullName
                                            Text(displayName, color = SocialMemoryColors.textPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                                            if (!person.nickname.isNullOrEmpty()) {
                                                Text("(${person.nickname})", color = SocialMemoryColors.textMuted, fontSize = 12.sp)
                                            }
                                        }
                                        if (!person.location.isNullOrEmpty()) {
                                            Text(person.location, color = SocialMemoryColors.textSecondary, fontSize = 12.sp)
                                        }
                                    }
                                }

                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "View Details", tint = SocialMemoryColors.textMuted)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 3. GROUPS TAB SCREEN
// ==========================================

@Composable
fun GroupsScreen(viewModel: AppViewModel, modifier: Modifier) {
    val appSettings by viewModel.appSettings.collectAsStateWithLifecycle()
    val isLightMode = appSettings?.themeMode == "LIGHT"
    val groups by viewModel.allGroups.collectAsStateWithLifecycle()

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.navigateTo(AppScreen.AddGroup) },
                containerColor = SocialMemoryColors.primary,
                contentColor = SocialMemoryColors.textOnAccent
            ) {
                Icon(Icons.Default.Add, "Add Group")
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "Friend Circles", 
                fontSize = 24.sp, 
                fontWeight = FontWeight.ExtraBold, 
                color = SocialMemoryColors.textPrimary
            )
            Text(
                "Host collective memory buffers, recurring groups, and communities.", 
                fontSize = 14.sp, 
                color = SocialMemoryColors.textSecondary
            )

            if (groups.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.GroupWork, "Empty", tint = SocialMemoryColors.textMuted, modifier = Modifier.size(48.dp))
                        Text("No circles built yet.", color = SocialMemoryColors.textMuted, fontSize = 14.sp)
                    }
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 168.dp)
                ) {
                    items(groups) { group ->
                        val membersState = viewModel.getGroupMembers(group.id).collectAsStateWithLifecycle(emptyList())

                        Surface(
                            color = SocialMemoryColors.surface,
                            shape = RoundedCornerShape(20.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                            shadowElevation = if (SocialMemoryColors.isLightMode) 4.dp else 0.dp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { viewModel.navigateTo(AppScreen.GroupDetail(group.id)) }
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .background(SocialMemoryColors.info.copy(alpha = 0.1f), CircleShape)
                                                .padding(10.dp)
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Group, 
                                                contentDescription = "Group Icon", 
                                                tint = SocialMemoryColors.info, 
                                                modifier = Modifier.size(20.dp)
                                            )
                                        }
                                        Column {
                                            Text(
                                                group.groupName.uppercase(), 
                                                fontWeight = FontWeight.Bold, 
                                                fontSize = 15.sp, 
                                                color = SocialMemoryColors.textPrimary,
                                                letterSpacing = 0.5.sp
                                            )
                                            Text(
                                                "${membersState.value.size} members connected", 
                                                fontSize = 12.sp, 
                                                color = SocialMemoryColors.textSecondary
                                            )
                                        }
                                    }
                                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "View Profile", tint = SocialMemoryColors.textMuted)
                                }

                                if (!group.description.isNullOrEmpty()) {
                                    Text(
                                        group.description, 
                                        fontSize = 13.sp, 
                                        color = SocialMemoryColors.textSecondary,
                                        lineHeight = 18.sp
                                    )
                                }

                                // Render current member names
                                if (membersState.value.isNotEmpty()) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        membersState.value.take(4).forEach { person ->
                                            Surface(
                                                color = SocialMemoryColors.infoContainer,
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier.height(24.dp)
                                            ) {
                                                Box(
                                                    contentAlignment = Alignment.Center,
                                                    modifier = Modifier.padding(horizontal = 8.dp)
                                                ) {
                                                    Text(
                                                        person.fullName, 
                                                        fontSize = 10.sp, 
                                                        color = SocialMemoryColors.infoStrong, 
                                                        fontWeight = FontWeight.Bold
                                                    )
                                                }
                                            }
                                        }
                                        if (membersState.value.size > 4) {
                                            Text(
                                                "+${membersState.value.size - 4} more", 
                                                fontSize = 11.sp, 
                                                color = SocialMemoryColors.textMuted, 
                                                modifier = Modifier.align(Alignment.CenterVertically)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 4. CALENDAR TAB SCREEN
// ==========================================

@Composable
fun CalendarScreen(viewModel: AppViewModel, modifier: Modifier) {
    val events by viewModel.allEvents.collectAsStateWithLifecycle()
    val reminders by viewModel.allReminders.collectAsStateWithLifecycle()
    val people by viewModel.allPeople.collectAsStateWithLifecycle()

    var calendarYear by remember { mutableStateOf(Calendar.getInstance().get(Calendar.YEAR)) }
    var calendarMonth by remember { mutableStateOf(Calendar.getInstance().get(Calendar.MONTH)) }
    var selectedDay by remember { mutableStateOf<Int?>(null) }
    var showMonthYearPickerDialog by remember { mutableStateOf(false) }

    val monthsFull = remember {
        listOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        )
    }

    val todayCal = Calendar.getInstance()
    val todayYear = todayCal.get(Calendar.YEAR)
    val todayMonth = todayCal.get(Calendar.MONTH)
    val todayDay = todayCal.get(Calendar.DAY_OF_MONTH)

    // Calculate calendar parameters for chosen year/month
    val calendar = remember(calendarYear, calendarMonth) {
        Calendar.getInstance().apply {
            set(Calendar.YEAR, calendarYear)
            set(Calendar.MONTH, calendarMonth)
            set(Calendar.DAY_OF_MONTH, 1)
        }
    }
    val firstDayOfWeek = remember(calendar) { calendar.get(Calendar.DAY_OF_WEEK) }
    val daysInMonth = remember(calendar) { calendar.getActualMaximum(Calendar.DAY_OF_MONTH) }

    // Map day to count of items (events or tasks) on that day
    val itemsMap = remember(events, reminders, calendarYear, calendarMonth) {
        val map = mutableMapOf<Int, Int>()
        val cal = Calendar.getInstance()

        events.forEach { event ->
            if (event.startTime != null) {
                cal.timeInMillis = event.startTime
                if (cal.get(Calendar.YEAR) == calendarYear && cal.get(Calendar.MONTH) == calendarMonth) {
                    val d = cal.get(Calendar.DAY_OF_MONTH)
                    map[d] = (map[d] ?: 0) + 1
                }
            }
        }

        reminders.forEach { reminder ->
            if (reminder.dueDate != null) {
                cal.timeInMillis = reminder.dueDate
                if (cal.get(Calendar.YEAR) == calendarYear && cal.get(Calendar.MONTH) == calendarMonth) {
                    val d = cal.get(Calendar.DAY_OF_MONTH)
                    map[d] = (map[d] ?: 0) + 1
                }
            }
        }
        map
    }

    // Filter events and reminders for this month
    val filteredMonthEvents = remember(events, calendarYear, calendarMonth) {
        val cal = Calendar.getInstance()
        events.filter { event ->
            if (event.startTime != null) {
                cal.timeInMillis = event.startTime
                cal.get(Calendar.YEAR) == calendarYear && cal.get(Calendar.MONTH) == calendarMonth
            } else {
                false
            }
        }.sortedBy { it.startTime }
    }

    val filteredMonthReminders = remember(reminders, calendarYear, calendarMonth) {
        val cal = Calendar.getInstance()
        reminders.filter { reminder ->
            if (reminder.dueDate != null) {
                cal.timeInMillis = reminder.dueDate
                cal.get(Calendar.YEAR) == calendarYear && cal.get(Calendar.MONTH) == calendarMonth
            } else {
                false
            }
        }.sortedBy { it.dueDate ?: 0L }
    }

    // Filter events and reminders for displayed items depending on selectedDay
    val displayedEvents = remember(filteredMonthEvents, selectedDay) {
        if (selectedDay == null) {
            filteredMonthEvents
        } else {
            val cal = Calendar.getInstance()
            filteredMonthEvents.filter { event ->
                if (event.startTime != null) {
                    cal.timeInMillis = event.startTime
                    cal.get(Calendar.DAY_OF_MONTH) == selectedDay
                } else {
                    false
                }
            }
        }
    }

    val displayedReminders = remember(filteredMonthReminders, selectedDay) {
        if (selectedDay == null) {
            filteredMonthReminders
        } else {
            val cal = Calendar.getInstance()
            filteredMonthReminders.filter { reminder ->
                if (reminder.dueDate != null) {
                    cal.timeInMillis = reminder.dueDate
                    cal.get(Calendar.DAY_OF_MONTH) == selectedDay
                } else {
                    false
                }
            }
        }
    }

    val getDayStyles: @Composable (Int, Boolean) -> Pair<Color, Color> = { count, isSel ->
        calendarCellColors(count, isSel)
    }
    
    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.navigateTo(AppScreen.AddEvent) },
                containerColor = SocialMemoryColors.primary,
                contentColor = SocialMemoryColors.textOnAccent
            ) {
                Icon(Icons.Default.Add, "Add Event")
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(top = 16.dp, bottom = 168.dp)
        ) {
            // Title & Header Info
            item {
                var showConnectDialog by remember { mutableStateOf(false) }
                val connectedCals by viewModel.connectedExternalCalendars.collectAsStateWithLifecycle()

                Row(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    Column(modifier = Modifier.weight(1f).padding(end = 16.dp)) {
                        Text(
                            "Social Calendar", 
                            fontSize = 24.sp, 
                            fontWeight = FontWeight.ExtraBold, 
                            color = SocialMemoryColors.textPrimary
                        )
                        Text(
                            "Coordinating dinners, milestones, circles, and checklists offline.", 
                            fontSize = 14.sp, 
                            color = SocialMemoryColors.textSecondary
                        )
                    }
                    
                    IconButton(
                        onClick = { showConnectDialog = true },
                        modifier = Modifier
                            .background(SocialMemoryColors.surfaceRaised, CircleShape)
                            .size(48.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.EditCalendar,
                                contentDescription = "Connect Calendar",
                                tint = SocialMemoryColors.primary,
                                modifier = Modifier.size(24.dp)
                            )
                            if (connectedCals.isNotEmpty()) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .background(Color.Green, CircleShape)
                                        .align(Alignment.TopEnd)
                                )
                            }
                        }
                    }
                }

                if (showConnectDialog) {
                    AlertDialog(
                        onDismissRequest = { showConnectDialog = false },
                        title = { Text("Connect External Calendar") },
                        text = {
                            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                Text(
                                    "Connect your external calendars to view upcoming events directly on your Home screen over the next 7 days.",
                                    fontSize = 14.sp,
                                    color = SocialMemoryColors.textSecondary
                                )
                                
                                val isGoogleConnected = connectedCals.contains("Google")
                                Button(
                                    onClick = { 
                                        viewModel.toggleExternalCalendar("Google")
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = if (isGoogleConnected) SocialMemoryColors.surfaceRaised else Color(0xFF4285F4))
                                ) {
                                    Text(if (isGoogleConnected) "Disconnect Google Calendar" else "Connect Google Calendar", color = if (isGoogleConnected) SocialMemoryColors.textPrimary else Color.White)
                                }
                                
                                val isOutlookConnected = connectedCals.contains("Outlook")
                                Button(
                                    onClick = { viewModel.toggleExternalCalendar("Outlook") },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = if (isOutlookConnected) SocialMemoryColors.surfaceRaised else Color(0xFF0078D4))
                                ) {
                                    Text(if (isOutlookConnected) "Disconnect Outlook" else "Connect Outlook", color = if (isOutlookConnected) SocialMemoryColors.textPrimary else Color.White)
                                }
                                
                                val isICloudConnected = connectedCals.contains("iCloud")
                                Button(
                                    onClick = { viewModel.toggleExternalCalendar("iCloud") },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = if (isICloudConnected) SocialMemoryColors.surfaceRaised else Color.Black)
                                ) {
                                    Text(if (isICloudConnected) "Disconnect iCloud Calendar" else "Connect iCloud Calendar", color = if (isICloudConnected) SocialMemoryColors.textPrimary else Color.White)
                                }
                            }
                        },
                        confirmButton = {},
                        dismissButton = {
                            TextButton(onClick = { showConnectDialog = false }) {
                                Text("Close")
                            }
                        }
                    )
                }
            }

            // Month Selection Control Row
            item {
                Surface(
                    color = SocialMemoryColors.surface,
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = {
                                selectedDay = null
                                if (calendarMonth == 0) {
                                    calendarMonth = 11
                                    calendarYear -= 1
                                } else {
                                    calendarMonth -= 1
                                }
                            },
                            modifier = Modifier.testTag("prev_month_btn")
                        ) {
                            Icon(
                                Icons.Default.ChevronLeft, 
                                contentDescription = "Previous Month", 
                                tint = SocialMemoryColors.textPrimary
                            )
                        }

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .clickable { showMonthYearPickerDialog = true }
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                                .testTag("month_year_selector_trigger")
                        ) {
                            val sdfMonthName = monthsFull[calendarMonth]
                            Text(
                                text = "$sdfMonthName $calendarYear",
                                fontSize = 17.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = SocialMemoryColors.textPrimary
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                Icons.Default.ArrowDropDown, 
                                contentDescription = "Choose Date", 
                                tint = SocialMemoryColors.textMuted, 
                                modifier = Modifier.size(22.dp)
                            )
                        }

                        IconButton(
                            onClick = {
                                selectedDay = null
                                if (calendarMonth == 11) {
                                    calendarMonth = 0
                                    calendarYear += 1
                                } else {
                                    calendarMonth += 1
                                }
                            },
                            modifier = Modifier.testTag("next_month_btn")
                        ) {
                            Icon(
                                imageVector = Icons.Default.ChevronRight, 
                                contentDescription = "Next Month", 
                                tint = SocialMemoryColors.textPrimary
                            )
                        }
                    }
                }
            }

            // Days of the week header
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    val daysOfWeek = listOf("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
                    daysOfWeek.forEach { dayStr ->
                        Text(
                            text = dayStr,
                            color = SocialMemoryColors.textMuted,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.weight(1f),
                            letterSpacing = 0.5.sp
                        )
                    }
                }
            }

            // Calendar dates grid
            item {
                Column(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                ) {
                    val totalCells = (firstDayOfWeek - 1) + daysInMonth
                    val rowsCount = (totalCells + 6) / 7

                    for (weekIndex in 0 until rowsCount) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            for (dayOfWeekIdx in 0..6) {
                                val cellIndex = weekIndex * 7 + dayOfWeekIdx
                                val dayNumber = cellIndex - (firstDayOfWeek - 2)

                                if (dayNumber in 1..daysInMonth) {
                                    val count = itemsMap[dayNumber] ?: 0
                                    val isSelected = selectedDay == dayNumber
                                    val isToday = calendarYear == todayYear && calendarMonth == todayMonth && dayNumber == todayDay
                                    
                                    val isLightMode = SocialMemoryColors.isLightMode
                                    val gradientLight = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFFE0F7FA), Color(0xFF80DEEA))) // Cyan Light: #E0F7FA, #80DEEA
                                    val gradientMedium = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFF4DD0E1), Color(0xFF00ACC1))) // Cyan Medium: #4DD0E1, #00ACC1
                                    val gradientDark = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFF00838F), Color(0xFF006064))) // Cyan Dark: #00838F, #006064

                                    val brush1 = if (isLightMode) gradientLight else gradientDark
                                    val brush2 = gradientMedium
                                    val brush3 = if (isLightMode) gradientDark else gradientLight
                                    
                                    val cellBgBrush = when {
                                        count >= 3 -> brush3
                                        count == 2 -> brush2
                                        count == 1 -> brush1
                                        else -> androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                                    }
                                    
                                    val cellTextColor = when {
                                        count >= 3 -> if (isLightMode) Color.White else Color.Black
                                        count == 2 -> Color.White
                                        count == 1 -> if (isLightMode) Color.Black else Color.White
                                        else -> SocialMemoryColors.textPrimary
                                    }
                                    
                                    Surface(
                                        modifier = Modifier
                                            .weight(1f)
                                            .aspectRatio(1f)
                                            .clickable {
                                                selectedDay = if (selectedDay == dayNumber) null else dayNumber
                                            },
                                        color = Color.Transparent,
                                        shape = RoundedCornerShape(12.dp),
                                        border = if (isSelected) BorderStroke(2.dp, SocialMemoryColors.infoStrong) else BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                        shadowElevation = 0.dp
                                    ) {
                                        Box(
                                            modifier = Modifier.fillMaxSize().background(cellBgBrush),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                                Text(
                                                    text = dayNumber.toString(),
                                                    color = cellTextColor,
                                                    fontWeight = if (isSelected || isToday) FontWeight.ExtraBold else FontWeight.Medium,
                                                    fontSize = 14.sp
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    Spacer(modifier = Modifier.weight(1f).aspectRatio(1f))
                                }
                            }
                        }
                    }
                }
            }
                // Heatmap Legend
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Daily Activity Level:", fontSize = 11.sp, color = SocialMemoryColors.textSecondary, fontWeight = FontWeight.Medium)
                        Spacer(modifier = Modifier.width(12.dp))
                        
                        val isLightMode = SocialMemoryColors.isLightMode
                        val gradientLight = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFFE0F7FA), Color(0xFF80DEEA)))
                        val gradientMedium = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFF4DD0E1), Color(0xFF00ACC1)))
                        val gradientDark = androidx.compose.ui.graphics.Brush.linearGradient(listOf(Color(0xFF00838F), Color(0xFF006064)))
                        
                        val brush1 = if (isLightMode) gradientLight else gradientDark
                        val brush2 = gradientMedium
                        val brush3 = if (isLightMode) gradientDark else gradientLight
                        
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(14.dp).background(brush1, RoundedCornerShape(4.dp)).border(1.dp, SocialMemoryColors.borderSubtle, RoundedCornerShape(4.dp)))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("1 Item", fontSize = 11.sp, color = SocialMemoryColors.textPrimary, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(16.dp))
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(14.dp).background(brush2, RoundedCornerShape(4.dp)).border(1.dp, SocialMemoryColors.borderSubtle, RoundedCornerShape(4.dp)))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("2 Items", fontSize = 11.sp, color = SocialMemoryColors.textPrimary, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(16.dp))
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(14.dp).background(brush3, RoundedCornerShape(4.dp)).border(1.dp, SocialMemoryColors.borderSubtle, RoundedCornerShape(4.dp)))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("3+ Items", fontSize = 11.sp, color = SocialMemoryColors.textPrimary, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(16.dp))
                        }
                    }
                }

                // Selected Day / Monthly Outlook Header
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Text(
                            text = if (selectedDay == null) "Monthly Outlook" else "Agenda: ${monthsFull[calendarMonth]} $selectedDay",
                            color = SocialMemoryColors.textPrimary,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                        if (selectedDay != null) {
                            Button(
                                onClick = { selectedDay = null },
                                colors = ButtonDefaults.buttonColors(containerColor = SocialMemoryColors.primary, contentColor = SocialMemoryColors.textOnAccent),
                                shape = RoundedCornerShape(100),
                                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                                modifier = Modifier.height(36.dp)
                            ) {
                                Text("Show Month", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }

                // Empty agenda state
                if (displayedEvents.isEmpty() && displayedReminders.isEmpty()) {
                    item {
                        Surface(
                            color = SocialMemoryColors.surface,
                            shape = RoundedCornerShape(20.dp),
                            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                        ) {
                            Column(
                                modifier = Modifier.padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Icon(
                                    imageVector = Icons.Default.EventAvailable, 
                                    contentDescription = null, 
                                    tint = SocialMemoryColors.textMuted, 
                                    modifier = Modifier.size(32.dp)
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                                Text(
                                    text = "No plans or reminders for this selection.", 
                                    color = SocialMemoryColors.textMuted, 
                                    fontSize = 14.sp
                                )
                            }
                        }
                    }
                } else {
                    // List Events
                    if (displayedEvents.isNotEmpty()) {
                        item {
                            Text(
                                text = "EVENTS",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = SocialMemoryColors.primary,
                                letterSpacing = 1.sp,
                                modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                            )
                        }
                        items(displayedEvents) { event ->
                            val timeStr = event.startTime?.let {
                                SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(it))
                            } ?: ""

                            Surface(
                                color = SocialMemoryColors.surface,
                                shape = RoundedCornerShape(16.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                                shadowElevation = if (SocialMemoryColors.isLightMode) 2.dp else 0.dp,
                                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
                            ) {
                                Row(
                                    modifier = Modifier.padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(40.dp)
                                            .background(SocialMemoryColors.info.copy(alpha = 0.1f), CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.CalendarToday, 
                                            contentDescription = null, 
                                            tint = SocialMemoryColors.info, 
                                            modifier = Modifier.size(20.dp)
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Column {
                                        Text(
                                            text = event.title, 
                                            color = SocialMemoryColors.textPrimary, 
                                            fontWeight = FontWeight.Bold, 
                                            fontSize = 15.sp
                                        )
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = timeStr, 
                                                color = SocialMemoryColors.info, 
                                                fontSize = 12.sp, 
                                                fontWeight = FontWeight.SemiBold
                                            )
                                            if (!event.location.isNullOrEmpty()) {
                                                Text(
                                                    text = " • ${event.location}", 
                                                    color = SocialMemoryColors.textSecondary, 
                                                    fontSize = 12.sp
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // List Reminders
                    if (displayedReminders.isNotEmpty()) {
                        item {
                            Text(
                                text = "FOLLOW UPS",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = SocialMemoryColors.primary,
                                letterSpacing = 1.sp,
                                modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                            )
                        }
                        items(displayedReminders) { reminder ->
                            Surface(
                                color = SocialMemoryColors.surface,
                                shape = RoundedCornerShape(16.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
                            ) {
                                Row(
                                    modifier = Modifier.padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(40.dp)
                                            .background(
                                                if (reminder.completed) SocialMemoryColors.success.copy(alpha = 0.1f) 
                                                else SocialMemoryColors.warning.copy(alpha = 0.1f), 
                                                CircleShape
                                            )
                                            .clickable { viewModel.toggleReminderCompleted(reminder) },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = if (reminder.completed) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                                            contentDescription = null,
                                            tint = if (reminder.completed) SocialMemoryColors.success else SocialMemoryColors.warning,
                                            modifier = Modifier.size(20.dp)
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Column {
                                        Text(
                                            text = reminder.title,
                                            color = if (reminder.completed) SocialMemoryColors.textMuted else SocialMemoryColors.textPrimary,
                                            fontWeight = FontWeight.SemiBold,
                                            fontSize = 14.sp,
                                            textDecoration = if (reminder.completed) TextDecoration.LineThrough else null
                                        )
                                        Text("Follow Up", color = SocialMemoryColors.textMuted, fontSize = 11.sp)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    // Custom Month/Year Picker Dialog
        if (showMonthYearPickerDialog) {
        var selectedLocalYear by remember { mutableStateOf(calendarYear) }
        var selectedLocalMonth by remember { mutableStateOf(calendarMonth) }

        val monthsAbbr = listOf(
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        )

        AlertDialog(
            onDismissRequest = { showMonthYearPickerDialog = false },
            containerColor = SocialMemoryColors.surfaceRaised,
            title = {
                Text(
                    text = "Go to Month & Year",
                    color = SocialMemoryColors.textPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Jump directly to any historic or future month:",
                        color = SocialMemoryColors.textSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Year selection controls
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = { selectedLocalYear -= 1 }) {
                            Icon(Icons.Default.ChevronLeft, contentDescription = "Previous Year", tint = SocialMemoryColors.primary)
                        }
                        Text(
                            text = selectedLocalYear.toString(),
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = SocialMemoryColors.textPrimary
                        )
                        IconButton(onClick = { selectedLocalYear += 1 }) {
                            Icon(Icons.Default.ChevronRight, contentDescription = "Next Year", tint = SocialMemoryColors.primary)
                        }
                    }

                    HorizontalDivider(color = SocialMemoryColors.borderSubtle)

                    // 12-Month grid (3x4)
                    Column(
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        for (row in 0 until 4) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                for (col in 0 until 3) {
                                    val monthIdx = row * 3 + col
                                    val monthAbbr = monthsAbbr[monthIdx]
                                    val isSelectedMonth = selectedLocalMonth == monthIdx

                                    Surface(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clickable { selectedLocalMonth = monthIdx },
                                        color = if (isSelectedMonth) SocialMemoryColors.primary else SocialMemoryColors.surface,
                                        shape = RoundedCornerShape(8.dp),
                                        border = BorderStroke(
                                            1.dp,
                                            if (isSelectedMonth) SocialMemoryColors.primary else SocialMemoryColors.borderSubtle
                                        )
                                    ) {
                                        Box(
                                            modifier = Modifier.padding(vertical = 12.dp),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text(
                                                text = monthAbbr,
                                                color = if (isSelectedMonth) SocialMemoryColors.textOnAccent else SocialMemoryColors.textPrimary,
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 14.sp
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        calendarYear = selectedLocalYear
                        calendarMonth = selectedLocalMonth
                        selectedDay = null
                        showMonthYearPickerDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = SocialMemoryColors.primary, contentColor = SocialMemoryColors.background)
                ) {
                    Text("Select", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showMonthYearPickerDialog = false }) {
                    Text("Cancel", color = SocialMemoryColors.textMuted)
                }
            },
            shape = RoundedCornerShape(24.dp)
        )
    }
}

// ==========================================
// 5. CAPTURE & EXTRACTION SCREEN
// ==========================================

@Composable
fun CaptureScreen(viewModel: AppViewModel, modifier: Modifier) {
    var notepadText by remember { mutableStateOf("") }
    val captures by viewModel.allCaptures.collectAsStateWithLifecycle()
    val peopleState by viewModel.allPeople.collectAsStateWithLifecycle()
    val selectedTaggedPersonIdState by viewModel.taggedPersonIdForCapture.collectAsStateWithLifecycle()
    val groupsState by viewModel.allGroups.collectAsStateWithLifecycle()
    val selectedTaggedGroupIdState by viewModel.taggedGroupIdForCapture.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(SocialMemoryColors.background)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 16.dp, bottom = 168.dp)
    ) {
        item {
            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                Text(
                    text = "Zero Friction Capture", 
                    fontSize = 24.sp, 
                    fontWeight = FontWeight.ExtraBold, 
                    color = SocialMemoryColors.textPrimary
                )
                Text(
                    text = "Turn text chunks, simulated audio transcripts, or chat screenshots into structured mappings instantly.", 
                    fontSize = 14.sp, 
                    color = SocialMemoryColors.textSecondary
                )
            }
        }

        // Notepad Input
        item {
            Surface(
                color = SocialMemoryColors.surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                shadowElevation = if (SocialMemoryColors.isLightMode) 1.dp else 0.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        "CAPTURE TEXT OR PASTE MESSAGES",
                        color = SocialMemoryColors.primary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )

                    OutlinedTextField(
                        value = notepadText,
                        onValueChange = { notepadText = it },
                        placeholder = { 
                            Text(
                                "E.g. Michelle birthday dinner is next Saturday at 7pm at Bar Isabel. Michelle and Alex and Sarah are coming. Sarah is moving so she can't make it.", 
                                color = SocialMemoryColors.textMuted, 
                                fontSize = 13.sp
                            ) 
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(110.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary,
                            cursorColor = SocialMemoryColors.primary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Text(
                        "TAG TO PROFILE (SAVES RAW CAPTURED DETAILS UNDER PROFILE HISTORY):",
                        color = SocialMemoryColors.primary,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp,
                        modifier = Modifier.padding(top = 4.dp)
                    )

                    if (peopleState.isEmpty()) {
                        Text(
                            "No profiles available to tag. Go to People index or sync contacts first.", 
                            color = SocialMemoryColors.textMuted, 
                            fontSize = 11.sp
                        )
                    } else {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState())
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            val isGeneralSelected = selectedTaggedPersonIdState == null
                            Surface(
                                modifier = Modifier
                                    .clickable { viewModel.setTaggedPersonIdForCapture(null) }
                                    .testTag("tag_none"),
                                color = if (isGeneralSelected) SocialMemoryColors.primary.copy(alpha = 0.15f) else SocialMemoryColors.surfaceVariant,
                                shape = RoundedCornerShape(100),
                                border = BorderStroke(1.dp, if (isGeneralSelected) SocialMemoryColors.primary else SocialMemoryColors.borderSubtle)
                            ) {
                                Text(
                                    text = "General (No Profile)",
                                    color = if (isGeneralSelected) SocialMemoryColors.primary else SocialMemoryColors.textSecondary,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                )
                            }

                            peopleState.forEach { person ->
                                val isSelected = selectedTaggedPersonIdState == person.id
                                Surface(
                                    modifier = Modifier
                                        .clickable { viewModel.setTaggedPersonIdForCapture(person.id) }
                                        .testTag("tag_profile_${person.id}"),
                                    color = if (isSelected) SocialMemoryColors.primary.copy(alpha = 0.15f) else SocialMemoryColors.surfaceVariant,
                                    shape = RoundedCornerShape(100),
                                    border = BorderStroke(1.dp, if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.borderSubtle)
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(6.dp)
                                                .background(if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textMuted, CircleShape)
                                        )
                                        Text(
                                            text = person.fullName,
                                            color = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textPrimary,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Text(
                        "TAG TO CIRCLE:",
                        color = SocialMemoryColors.primary,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp,
                        modifier = Modifier.padding(top = 4.dp)
                    )

                    if (groupsState.isEmpty()) {
                        Text("No circles available to tag.", color = SocialMemoryColors.textMuted, fontSize = 11.sp)
                    } else {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState())
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            val isGroupGeneralSelected = selectedTaggedGroupIdState == null
                            Surface(
                                modifier = Modifier
                                    .clickable { viewModel.setTaggedGroupIdForCapture(null) }
                                    .testTag("tag_group_none"),
                                color = if (isGroupGeneralSelected) SocialMemoryColors.primary.copy(alpha = 0.15f) else SocialMemoryColors.surfaceVariant,
                                shape = RoundedCornerShape(100),
                                border = BorderStroke(1.dp, if (isGroupGeneralSelected) SocialMemoryColors.primary else SocialMemoryColors.borderSubtle)
                            ) {
                                Text(
                                    text = "General (No Circle)",
                                    color = if (isGroupGeneralSelected) SocialMemoryColors.primary else SocialMemoryColors.textSecondary,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                )
                            }

                            groupsState.forEach { group ->
                                val isSelected = selectedTaggedGroupIdState == group.id
                                Surface(
                                    modifier = Modifier
                                        .clickable { viewModel.setTaggedGroupIdForCapture(group.id) }
                                        .testTag("tag_group_${group.id}"),
                                    color = if (isSelected) SocialMemoryColors.primary.copy(alpha = 0.15f) else SocialMemoryColors.surfaceVariant,
                                    shape = RoundedCornerShape(100),
                                    border = BorderStroke(1.dp, if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.borderSubtle)
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(6.dp)
                                                .background(if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textMuted, CircleShape)
                                        )
                                        Text(
                                            text = group.groupName.uppercase(),
                                            color = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textPrimary,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(2.dp))

                        Button(
                            onClick = {
                                if (notepadText.isNotBlank()) {
                                    viewModel.performCaptureAnalysis("text", notepadText, null, selectedTaggedPersonIdState, selectedTaggedGroupIdState)
                                    notepadText = ""
                                }
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = SocialMemoryColors.primary, 
                                contentColor = SocialMemoryColors.textOnAccent
                            ),
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            enabled = notepadText.isNotBlank()
                        ) {
                            Text("Analyze Capture Chunk", fontWeight = FontWeight.ExtraBold)
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            val buttonColors = ButtonDefaults.buttonColors(
                                containerColor = SocialMemoryColors.surfaceRaised, 
                                contentColor = SocialMemoryColors.textPrimary,
                                disabledContainerColor = SocialMemoryColors.surfaceVariant,
                                disabledContentColor = SocialMemoryColors.textMuted
                            )
                            val buttonShape = RoundedCornerShape(12.dp)
                            
                            Button(
                                onClick = {
                                    if (notepadText.isNotBlank()) {
                                        viewModel.addDirectDetail(notepadText, selectedTaggedPersonIdState, selectedTaggedGroupIdState)
                                        notepadText = ""
                                    }
                                },
                                colors = buttonColors,
                                modifier = Modifier.weight(1f),
                                shape = buttonShape,
                                enabled = notepadText.isNotBlank(),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                contentPadding = PaddingValues(horizontal = 4.dp)
                            ) {
                                Text("Add Detail", fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
                            }
                            Button(
                                onClick = {
                                    if (notepadText.isNotBlank()) {
                                        viewModel.addDirectEvent(notepadText, selectedTaggedPersonIdState, selectedTaggedGroupIdState)
                                        notepadText = ""
                                    }
                                },
                                colors = buttonColors,
                                modifier = Modifier.weight(1f),
                                shape = buttonShape,
                                enabled = notepadText.isNotBlank(),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                contentPadding = PaddingValues(horizontal = 4.dp)
                            ) {
                                Text("Add Event", fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
                            }
                            Button(
                                onClick = {
                                    if (notepadText.isNotBlank()) {
                                        viewModel.addDirectTask(notepadText, selectedTaggedPersonIdState)
                                        notepadText = ""
                                    }
                                },
                                colors = buttonColors,
                                modifier = Modifier.weight(1f),
                                shape = buttonShape,
                                enabled = notepadText.isNotBlank(),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                contentPadding = PaddingValues(horizontal = 4.dp)
                            ) {
                                Text("Add Task", fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
                            }
                        }
                }
            }
        }

        // Simulators Container
        item {
            Text(
                text = "SIMULATOR LAUNCHERS",
                color = SocialMemoryColors.textMuted,
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 1.sp
            )
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Screenshot Simulation Card
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            val mockText = """
                                [WhatsApp Screenshot Chat Log]
                                Alex: Let's do paddlers BBQ this Sunday at 2pm at Hanlan's Point!
                                Michelle: Count me in. I'm bringing fruit.
                                Brian: Sweet, but need to watch my injured shoulder. No paddling, just BBQ.
                            """.trimIndent()
                            viewModel.performCaptureAnalysis("screenshot", mockText, null, selectedTaggedPersonIdState, selectedTaggedGroupIdState)
                        }
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.PhotoSizeSelectActual, 
                            contentDescription = "Screenshot", 
                            tint = SocialMemoryColors.info, 
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = "Simulate Chat Screenshot", 
                            fontWeight = FontWeight.Bold, 
                            fontSize = 13.sp, 
                            color = SocialMemoryColors.textPrimary
                        )
                        Text(
                            text = "Upload Chat logs & let LLM parse links.", 
                            fontSize = 11.sp, 
                            color = SocialMemoryColors.textMuted
                        )
                    }
                }

                // Voice Note Simulation Card
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            val mockTranscript = "Record: Alex Chen and Michelle are going to Japan in September. Remember to check on Kyoto hotels next time we meet up."
                            viewModel.performCaptureAnalysis("voice", mockTranscript, null, selectedTaggedPersonIdState, selectedTaggedGroupIdState)
                        }
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Mic, 
                            contentDescription = "Voice recorder", 
                            tint = SocialMemoryColors.destructive, 
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = "Simulate Voice Recorder", 
                            fontWeight = FontWeight.Bold, 
                            fontSize = 13.sp, 
                            color = SocialMemoryColors.textPrimary
                        )
                        Text(
                            text = "Speaks social feedback or callbacks.", 
                            fontSize = 11.sp, 
                            color = SocialMemoryColors.textMuted
                        )
                    }
                }
            }
        }

        // Recent Capture Backlogs
        item {
            Text(
                text = "CAPTURE CAPTIONS HISTORY",
                color = SocialMemoryColors.textMuted,
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 1.sp
            )
        }

        if (captures.isEmpty()) {
            item {
                Surface(
                    color = SocialMemoryColors.surfaceVariant,
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(modifier = Modifier.padding(20.dp), contentAlignment = Alignment.Center) {
                        Text(
                            text = "No capture history available yet.", 
                            color = SocialMemoryColors.textMuted, 
                            fontSize = 12.sp
                        )
                    }
                }
            }
        } else {
            items(captures) { capture ->
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                    shadowElevation = if (SocialMemoryColors.isLightMode) 1.dp else 0.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                                val (icon, color) = when (capture.type) {
                                    "screenshot" -> Pair(Icons.Default.PhotoSizeSelectActual, SocialMemoryColors.info)
                                    "voice" -> Pair(Icons.Default.Mic, SocialMemoryColors.destructive)
                                    else -> Pair(Icons.Default.Description, SocialMemoryColors.primary)
                                }

                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(color.copy(alpha = 0.12f), CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = icon, 
                                    contentDescription = null, 
                                    tint = color, 
                                    modifier = Modifier.size(18.dp)
                                )
                            }

                            Column {
                                Text(
                                    text = capture.rawContent,
                                    fontSize = 13.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    color = SocialMemoryColors.textPrimary,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(Date(capture.createdAt)) + " • " + if (capture.processed) "PROCESSED" else "PENDING",
                                    fontSize = 11.sp,
                                    color = SocialMemoryColors.textMuted
                                )
                            }
                        }

                        if (!capture.processed && !capture.analyzedJson.isNullOrEmpty()) {
                            IconButton(
                                onClick = { viewModel.navigateTo(AppScreen.ReviewExtraction(capture.id)) },
                                modifier = Modifier
                                    .background(SocialMemoryColors.primary.copy(alpha = 0.1f), CircleShape)
                                    .size(32.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ChevronRight, 
                                    contentDescription = "Review Suggestions", 
                                    tint = SocialMemoryColors.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 6. REVIEW EXTRACTION SCREEN
// ==========================================

@Composable
fun ReviewExtractionScreen(captureId: Int, viewModel: AppViewModel, modifier: Modifier) {
    val captureFlow = remember(captureId) { viewModel.getCaptureById(captureId) }
    val capture by captureFlow.collectAsStateWithLifecycle(initialValue = null)

    var hasInitialized by remember { mutableStateOf(false) }

    // Check confirmed lists
    val confirmedPeople = remember { mutableStateListOf<ExtractedPerson>() }
    val confirmedEvents = remember { mutableStateListOf<ExtractedEvent>() }
    val confirmedMemories = remember { mutableStateListOf<ExtractedMemory>() }
    val confirmedRelationships = remember { mutableStateListOf<ExtractedRelationship>() }
    val confirmedReminders = remember { mutableStateListOf<ExtractedReminder>() }

    LaunchedEffect(capture) {
        val json = capture?.analyzedJson
        if (json != null && !hasInitialized) {
            try {
                val moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
                val adapter = moshi.adapter(ExtractionResult::class.java)
                val parsed = adapter.fromJson(json)
                if (parsed != null) {
                    confirmedPeople.addAll(parsed.people)
                    confirmedEvents.addAll(parsed.events)
                    confirmedMemories.addAll(parsed.memories)
                    confirmedRelationships.addAll(parsed.relationships)
                    confirmedReminders.addAll(parsed.reminders)
                    hasInitialized = true
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { viewModel.navigateBack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                            contentDescription = "Back", 
                            tint = SocialMemoryColors.textPrimary
                        )
                    }
                    Text(
                        text = "Review Suggestions", 
                        fontWeight = FontWeight.Bold, 
                        fontSize = 18.sp, 
                        color = SocialMemoryColors.textPrimary
                    )
                }

                Button(
                    onClick = {
                        val finalResult = ExtractionResult(
                            people = confirmedPeople.toList(),
                            events = confirmedEvents.toList(),
                            memories = confirmedMemories.toList(),
                            relationships = confirmedRelationships.toList(),
                            reminders = confirmedReminders.toList()
                        )
                        viewModel.saveConfirmedSuggestions(captureId, finalResult)
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.primary, 
                        contentColor = SocialMemoryColors.textOnAccent
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Save Confirmed", fontWeight = FontWeight.ExtraBold)
                }
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Source Log Banner
            item {
                capture?.let {
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(20.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(
                                text = "SOURCE EVIDENCE CAPTURED", 
                                fontSize = 10.sp, 
                                fontWeight = FontWeight.Bold, 
                                color = SocialMemoryColors.primary,
                                letterSpacing = 0.5.sp
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = it.rawContent, 
                                fontSize = 12.sp, 
                                color = SocialMemoryColors.textSecondary, 
                                maxLines = 3, 
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }

            // A. PEOPLE DETECTED
            item {
                Text(
                    text = "PEOPLE EXTRACTED", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (confirmedPeople.isEmpty()) {
                item { 
                    Text(
                        text = "No people parsed.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(confirmedPeople) { item ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Checkbox(
                                    checked = true,
                                    onCheckedChange = { confirmedPeople.remove(item) },
                                    colors = CheckboxDefaults.colors(
                                        checkedColor = SocialMemoryColors.confirm,
                                        uncheckedColor = SocialMemoryColors.borderSubtle
                                    )
                                )
                                Column {
                                    Text(
                                        text = item.name, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 14.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                    item.evidence?.let { 
                                        Text(
                                            text = "Evidence: $it", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 11.sp 
                                        ) 
                                    }
                                }
                            }
                            Surface(
                                color = SocialMemoryColors.confirm.copy(alpha = 0.12f),
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    text = item.confidence_state.uppercase(), 
                                    color = SocialMemoryColors.confirm, 
                                    fontSize = 9.sp, 
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                )
                            }
                        }
                    }
                }
            }

            // B. EVENTS DETECTED
            item {
                Text(
                    text = "EVENTS EXTRACTED", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (confirmedEvents.isEmpty()) {
                item { 
                    Text(
                        text = "No events parsed.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(confirmedEvents) { item ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Checkbox(
                                    checked = true,
                                    onCheckedChange = { confirmedEvents.remove(item) },
                                    colors = CheckboxDefaults.colors(
                                        checkedColor = SocialMemoryColors.confirm,
                                        uncheckedColor = SocialMemoryColors.borderSubtle
                                    )
                                )
                                Column {
                                    Text(
                                        text = item.title, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 14.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(vertical = 2.dp)) {
                                        Text(
                                            text = "Date: ${item.date_text ?: "TBD"}", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 11.sp
                                        )
                                        Text(
                                            text = "•", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 11.sp
                                        )
                                        Text(
                                            text = "Time: ${item.time_text ?: "TBD"}", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 11.sp
                                        )
                                    }
                                    if (item.people.isNotEmpty()) {
                                        Text(
                                            text = "Attendees: " + item.people.joinToString(), 
                                            fontSize = 11.sp, 
                                            color = SocialMemoryColors.primary, 
                                            fontWeight = FontWeight.Bold,
                                            modifier = Modifier.padding(top = 2.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // C. MEMORIES/LIFE UPDATES DETECTED
            item {
                Text(
                    text = "MEMORIES & PREFERENCES", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (confirmedMemories.isEmpty()) {
                item { 
                    Text(
                        text = "No memories parsed.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(confirmedMemories) { item ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Checkbox(
                        checked = true,
                        onCheckedChange = { confirmedMemories.remove(item) },
                        colors = CheckboxDefaults.colors(
                            checkedColor = SocialMemoryColors.confirm,
                            uncheckedColor = SocialMemoryColors.borderSubtle
                        )
                    )
                                Column {
                                    Text(
                                        text = item.person ?: "General Circle Update", 
                                        color = SocialMemoryColors.primary, 
                                        fontSize = 12.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = item.content, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 13.sp
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Surface(
                                        color = SocialMemoryColors.info.copy(alpha = 0.12f),
                                        shape = RoundedCornerShape(6.dp)
                                    ) {
                                        Text(
                                            text = item.memory_type.uppercase(), 
                                            color = SocialMemoryColors.info, 
                                            fontSize = 9.sp, 
                                            fontWeight = FontWeight.Bold,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // D. RELATIONSHIPS DETECTED
            item {
                Text(
                    text = "RELATIONSHIPS MAP SUGGESTED", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (confirmedRelationships.isEmpty()) {
                item { 
                    Text(
                        text = "No relationships parsed.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(confirmedRelationships) { item ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Checkbox(
                                    checked = true,
                                    onCheckedChange = { confirmedRelationships.remove(item) },
                                    colors = CheckboxDefaults.colors(
                                        checkedColor = SocialMemoryColors.confirm,
                                        uncheckedColor = SocialMemoryColors.borderSubtle
                                    )
                                )
                                Column {
                                    Text(
                                        text = "${item.person_a} • ${item.relationship_type.replace("_", " ").uppercase()} • ${item.person_b}", 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 13.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // E. REMINDERS DETECTED
            item {
                Text(
                    text = "REMINDERS & ACTIONS EXTRACTED", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (confirmedReminders.isEmpty()) {
                item { 
                    Text(
                        text = "No reminders parsed.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(confirmedReminders) { item ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Checkbox(
                                    checked = true,
                                    onCheckedChange = { confirmedReminders.remove(item) },
                                    colors = CheckboxDefaults.colors(
                                        checkedColor = SocialMemoryColors.confirm,
                                        uncheckedColor = SocialMemoryColors.borderSubtle
                                    )
                                )
                                Column {
                                    Text(
                                        text = item.title, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 13.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                    item.due_text?.let { 
                                        Text(
                                            text = "Due text: $it", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 11.sp 
                                        ) 
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 7. PERSON PROFILE DETAIL SCREEN
// ==========================================

@Composable
fun PersonDetailScreen(personId: Int, viewModel: AppViewModel, modifier: Modifier) {
    val people by viewModel.allPeople.collectAsStateWithLifecycle()
    val person = remember(people) { people.find { it.id == personId } }

    val events by viewModel.allEvents.collectAsStateWithLifecycle()
    val reminders by viewModel.allReminders.collectAsStateWithLifecycle()

    val groupState = viewModel.getGroupsForPerson(personId).collectAsStateWithLifecycle(emptyList())
    val memoriesState = viewModel.getMemoriesForPerson(personId).collectAsStateWithLifecycle(emptyList())

    val personEventsState = viewModel.getEventsForPerson(personId).collectAsStateWithLifecycle(emptyList())
    val personEvents = personEventsState.value

    var editingMemory by remember { mutableStateOf<Memory?>(null) }
    var editingReminder by remember { mutableStateOf<Reminder?>(null) }
    var editingEvent by remember { mutableStateOf<SocialEvent?>(null) }

    val completedReminders = remember(reminders, personId) {
        reminders.filter { it.personId == personId && it.completed }
    }
    val notActionedReminders = remember(reminders, personId) {
        reminders.filter { it.personId == personId && !it.completed }
    }

    var activePersonReminderAction by remember { mutableStateOf<Reminder?>(null) }

    var showQuickMemoryDialog by remember { mutableStateOf(false) }
    var quickMemoryText by remember { mutableStateOf("") }
    var showAllMemories by remember { mutableStateOf(false) }

    if (person == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Person not found in Social Brain.", color = SocialMemoryColors.textMuted)
        }
        return
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    IconButton(onClick = { viewModel.navigateBack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                            contentDescription = "Back", 
                            tint = SocialMemoryColors.textPrimary
                        )
                    }
                    Text(
                        text = person.fullName, 
                        fontWeight = FontWeight.Bold, 
                        fontSize = 20.sp, 
                        color = SocialMemoryColors.textPrimary
                    )
                }
            }
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showQuickMemoryDialog = true },
                containerColor = SocialMemoryColors.primary,
                contentColor = SocialMemoryColors.textOnAccent,
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Default.AddComment, "Fast Note")
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header card
            item {
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(24.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                    shadowElevation = if (SocialMemoryColors.isLightMode) 4.dp else 0.dp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.navigateTo(AppScreen.EditPerson(personId)) }
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically, 
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Box(
                                    modifier = Modifier
                                        .size(64.dp)
                                        .background(
                                            Brush.linearGradient(listOf(SocialMemoryColors.primary, SocialMemoryColors.info)),
                                            CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = person.fullName.take(1).uppercase(), 
                                        color = SocialMemoryColors.textOnAccent, 
                                        fontSize = 28.sp, 
                                        fontWeight = FontWeight.Black
                                    )
                                }
                                Column {
                                    Text(
                                        text = person.fullName, 
                                        fontSize = 22.sp, 
                                        fontWeight = FontWeight.ExtraBold, 
                                        color = SocialMemoryColors.textPrimary
                                    )
                                    if (person.isImported) {
                                        Surface(
                                            color = SocialMemoryColors.primary.copy(alpha = 0.12f),
                                            shape = RoundedCornerShape(6.dp),
                                            modifier = Modifier.padding(top = 4.dp)
                                        ) {
                                            Text(
                                                text = "Imported", 
                                                color = SocialMemoryColors.primary, 
                                                fontSize = 10.sp, 
                                                fontWeight = FontWeight.Bold,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                            }
                            
                            IconButton(onClick = { viewModel.navigateTo(AppScreen.EditPerson(personId)) }) {
                                Icon(
                                    imageVector = Icons.Default.Edit, 
                                    contentDescription = "Edit Person", 
                                    tint = SocialMemoryColors.textPrimary
                                )
                            }
                        }

                        val fields = listOfNotNull(
                            person.nickname.takeIf { !it.isNullOrBlank() }?.let { Triple("NICKNAME", it, Icons.Default.Face) },
                            person.email.takeIf { !it.isNullOrBlank() }?.let { Triple("EMAIL ADDRESS", it, Icons.Default.Email) },
                            person.phoneNumber.takeIf { !it.isNullOrBlank() }?.let { Triple("PHONE NUMBER", it, Icons.Default.Phone) },
                            person.birthday.takeIf { !it.isNullOrBlank() }?.let { Triple("BIRTHDAY", it, Icons.Default.Cake) },
                            person.location.takeIf { !it.isNullOrBlank() }?.let { Triple("ADDRESS / LOCATION", it, Icons.Default.Place) }
                        )

                        if (fields.isNotEmpty()) {
                            HorizontalDivider(color = SocialMemoryColors.borderSubtle, modifier = Modifier.padding(vertical = 8.dp))
                            fields.forEachIndexed { idx, pair ->
                                val (label, value, icon) = pair
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Icon(
                                        imageVector = icon,
                                        contentDescription = label,
                                        tint = SocialMemoryColors.textMuted,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(label, fontSize = 9.sp, color = SocialMemoryColors.textMuted, fontWeight = FontWeight.SemiBold)
                                        Text(value, fontSize = 14.sp, color = SocialMemoryColors.textPrimary)
                                    }
                                }
                            }
                        }

                        if (!person.notes.isNullOrEmpty()) {
                            HorizontalDivider(color = SocialMemoryColors.borderSubtle, modifier = Modifier.padding(vertical = 8.dp))
                            Text(
                                text = "NOTES", 
                                color = SocialMemoryColors.textMuted, 
                                fontSize = 9.sp, 
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = person.notes, 
                                fontSize = 14.sp, 
                                color = SocialMemoryColors.textSecondary,
                                lineHeight = 20.sp
                            )
                        }
                    }
                }
            }

            // A. ASSOCIATED CIRCLES
            item {
                Text(
                    text = "CONNECTED CIRCLES", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (groupState.value.isEmpty()) {
                item { 
                    Text(
                        text = "No associated circles.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                item {
                    @OptIn(ExperimentalLayoutApi::class)
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        groupState.value.forEach { group ->
                            Surface(
                                color = SocialMemoryColors.info.copy(alpha = 0.12f),
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.info.copy(alpha = 0.2f)),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            ) {
                                Box(
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = group.groupName.uppercase(),
                                        color = SocialMemoryColors.info,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.sp,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        letterSpacing = 0.5.sp
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // B. MEMORIES HISTORY
            item {
                Text(
                    text = "TIMELINE & UPDATES", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (memoriesState.value.isEmpty()) {
                item { 
                    Text(
                        text = "No memory history recorded yet. Add some note above or capture logs.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                val sortedMemories = memoriesState.value.sortedByDescending { it.createdAt }
                val displayMemories = if (showAllMemories) sortedMemories else sortedMemories.take(5)

                itemsIndexed(displayMemories) { index, memory ->
                    val isLast = index == displayMemories.size - 1
                    val hasMore = !showAllMemories && sortedMemories.size > 5
                    
                    val firstSentence = memory.content.split(Regex("(?<=[.!?])\\s+")).firstOrNull() ?: memory.content

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(IntrinsicSize.Min)
                    ) {
                        // Timeline line & dot rail
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.width(28.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .padding(top = 4.dp)
                                    .size(14.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Box(modifier = Modifier.size(14.dp).background(SocialMemoryColors.primary.copy(alpha = 0.2f), CircleShape))
                                Box(modifier = Modifier.size(10.dp).background(SocialMemoryColors.primary, CircleShape))
                            }
                            if (!isLast || hasMore) {
                                Box(
                                    modifier = Modifier
                                        .width(2.dp)
                                        .fillMaxHeight()
                                        .background(SocialMemoryColors.borderStrong)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(12.dp))

                        // Content
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .padding(bottom = 28.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault()).format(java.util.Date(memory.createdAt)),
                                    fontSize = 14.sp,
                                    color = SocialMemoryColors.textMuted,
                                    fontWeight = FontWeight.Bold
                                )
                                IconButton(
                                    onClick = { editingMemory = memory },
                                    modifier = Modifier.size(24.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Edit, 
                                        contentDescription = "Edit Note", 
                                        tint = SocialMemoryColors.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = firstSentence.trim(),
                                color = SocialMemoryColors.textPrimary,
                                fontSize = 16.sp,
                                lineHeight = 24.sp
                            )
                            
                            if (isLast && hasMore) {
                                Spacer(modifier = Modifier.height(16.dp))
                                TextButton(
                                    onClick = { showAllMemories = true },
                                    contentPadding = PaddingValues(0.dp),
                                    modifier = Modifier.height(24.dp)
                                ) {
                                    Text(
                                        text = "View more", 
                                        color = SocialMemoryColors.primary, 
                                        fontSize = 14.sp, 
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // C. REMINDER & FOLLOW-UP LOG
            item {
                Text(
                    text = "REMINDER & FOLLOW-UP LOG", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (completedReminders.isEmpty() && notActionedReminders.isEmpty()) {
                item { 
                    Text(
                        text = "No follow-up action logs found.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                // First list the Uncompleted (Not Actioned/Pending) ones
                if (notActionedReminders.isNotEmpty()) {
                    item {
                        Text(
                            text = "PENDING (NOT ACTIONED)", 
                            color = SocialMemoryColors.info, 
                            fontSize = 10.sp, 
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 0.5.sp
                        )
                    }
                    items(notActionedReminders) { rem ->
                        Surface(
                            color = SocialMemoryColors.surface,
                            shape = RoundedCornerShape(16.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                            shadowElevation = if (SocialMemoryColors.isLightMode) 2.dp else 0.dp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .weight(1f)
                                        .clickable { activePersonReminderAction = rem }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Circle,
                                        contentDescription = "Pending",
                                        tint = SocialMemoryColors.borderSubtle,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(
                                        text = rem.title, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                                
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    IconButton(
                                        onClick = { editingReminder = rem },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Edit,
                                            contentDescription = "Edit Reminder",
                                            tint = SocialMemoryColors.primary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                    IconButton(
                                        onClick = { viewModel.deleteReminder(rem) },
                                        modifier = Modifier
                                            .size(32.dp)
                                            .testTag("delete_person_rem_${rem.id}")
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Close,
                                            contentDescription = "Delete",
                                            tint = SocialMemoryColors.textMuted,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Second list the Completed (Actioned) logs
                if (completedReminders.isNotEmpty()) {
                    item {
                        Text(
                            text = "COMPLETED (ACTIONED LOGS)", 
                            color = SocialMemoryColors.confirm, 
                            fontSize = 10.sp, 
                            fontWeight = FontWeight.Bold, 
                            modifier = Modifier.padding(top = 12.dp),
                            letterSpacing = 0.5.sp
                        )
                    }
                    items(completedReminders) { rem ->
                        Surface(
                            color = SocialMemoryColors.surfaceSubtle.copy(alpha = 0.3f),
                            shape = RoundedCornerShape(16.dp),
                            border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                            shadowElevation = 0.dp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                    Icon(
                                        imageVector = Icons.Default.CheckCircle,
                                        contentDescription = "Completed",
                                        tint = SocialMemoryColors.confirm,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(
                                            text = rem.title, 
                                            color = SocialMemoryColors.textSecondary, 
                                            fontSize = 14.sp,
                                            textDecoration = TextDecoration.LineThrough
                                        )
                                        Text(
                                            text = "Status: Actioned & Logged", 
                                            color = SocialMemoryColors.confirm, 
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                                
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    IconButton(
                                        onClick = { editingReminder = rem },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Edit,
                                            contentDescription = "Edit Reminder",
                                            tint = SocialMemoryColors.primary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                    IconButton(
                                        onClick = { viewModel.deleteReminder(rem) },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Delete,
                                            contentDescription = "Delete Log",
                                            tint = SocialMemoryColors.textMuted,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // D. UPCOMING & LINKED EVENTS
            item {
                Text(
                    text = "UPCOMING & LINKED EVENTS", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    modifier = Modifier.padding(top = 16.dp),
                    letterSpacing = 0.5.sp
                )
            }

            if (personEvents.isEmpty()) {
                item { 
                    Text(
                        text = "No linked events for this profile.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(personEvents) { event ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 2.dp else 0.dp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .background(SocialMemoryColors.primary.copy(alpha = 0.12f), CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Event,
                                        contentDescription = "Event",
                                        tint = SocialMemoryColors.primary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = event.title, 
                                        color = SocialMemoryColors.textPrimary, 
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    event.location?.let { loc ->
                                        if (loc.isNotBlank()) {
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                                modifier = Modifier.padding(top = 2.dp)
                                            ) {
                                                Icon(
                                                    imageVector = Icons.Default.Place,
                                                    contentDescription = "Place",
                                                    tint = SocialMemoryColors.textMuted,
                                                    modifier = Modifier.size(12.dp)
                                                )
                                                Text(
                                                    text = loc, 
                                                    color = SocialMemoryColors.textSecondary, 
                                                    fontSize = 12.sp
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            
                            IconButton(
                                onClick = { editingEvent = event },
                                modifier = Modifier.size(32.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "Edit Event",
                                    tint = SocialMemoryColors.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        // Quick memory adding popup dialog
        if (showQuickMemoryDialog) {
            AlertDialog(
                onDismissRequest = { showQuickMemoryDialog = false },
                containerColor = SocialMemoryColors.surfaceRaised,
                title = { 
                    Text(
                        text = "Log New Memory for ${person.fullName}", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 18.sp, 
                        fontWeight = FontWeight.Bold
                    ) 
                },
                text = {
                    OutlinedTextField(
                        value = quickMemoryText,
                        onValueChange = { quickMemoryText = it },
                        placeholder = { 
                            Text(
                                text = "E.g. Traveled to Boston, likes IPA beers, etc.", 
                                color = SocialMemoryColors.textMuted 
                            ) 
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            cursorColor = SocialMemoryColors.primary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (quickMemoryText.isNotBlank()) {
                                viewModel.addMemory(quickMemoryText, personId, null, null, "life_update")
                                quickMemoryText = ""
                                showQuickMemoryDialog = false
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.primary, 
                            contentColor = SocialMemoryColors.textOnAccent
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Save note", fontWeight = FontWeight.ExtraBold)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showQuickMemoryDialog = false }) {
                        Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                    }
                },
                shape = RoundedCornerShape(24.dp)
            )
        }

        if (editingMemory != null) {
            val originalMemory = editingMemory!!
            var editMemoryText by remember(originalMemory) { mutableStateOf(originalMemory.content) }
            AlertDialog(
                onDismissRequest = { editingMemory = null },
                containerColor = SocialMemoryColors.surfaceRaised,
                title = {
                    Text(
                        text = "Edit Memory", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 18.sp, 
                        fontWeight = FontWeight.Bold
                    ) 
                },
                text = {
                    OutlinedTextField(
                        value = editMemoryText,
                        onValueChange = { editMemoryText = it },
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            cursorColor = SocialMemoryColors.primary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (editMemoryText.isNotBlank()) {
                                viewModel.updateMemory(originalMemory.copy(content = editMemoryText))
                                editingMemory = null
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.primary, 
                            contentColor = SocialMemoryColors.textOnAccent
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Save note", fontWeight = FontWeight.ExtraBold)
                    }
                },
                dismissButton = {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        TextButton(
                            onClick = {
                                viewModel.deleteMemory(originalMemory)
                                editingMemory = null
                            }
                        ) {
                            Text("Delete", color = Color(0xFFD32F2F), fontWeight = FontWeight.Bold)
                        }
                        TextButton(onClick = { editingMemory = null }) {
                            Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                        }
                    }
                },
                shape = RoundedCornerShape(24.dp)
            )
        }

        if (editingReminder != null) {
            val originalReminder = editingReminder!!
            var editReminderTitle by remember(originalReminder) { mutableStateOf(originalReminder.title) }
            AlertDialog(
                onDismissRequest = { editingReminder = null },
                containerColor = SocialMemoryColors.surfaceRaised,
                title = {
                    Text(
                        text = "Edit Reminder", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 18.sp, 
                        fontWeight = FontWeight.Bold
                    ) 
                },
                text = {
                    OutlinedTextField(
                        value = editReminderTitle,
                        onValueChange = { editReminderTitle = it },
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            cursorColor = SocialMemoryColors.primary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (editReminderTitle.isNotBlank()) {
                                viewModel.updateReminderDetails(originalReminder.copy(title = editReminderTitle))
                                editingReminder = null
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.primary, 
                            contentColor = SocialMemoryColors.textOnAccent
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Save reminder", fontWeight = FontWeight.ExtraBold)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { editingReminder = null }) {
                        Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                    }
                },
                shape = RoundedCornerShape(24.dp)
            )
        }

        if (editingEvent != null) {
            val originalEvent = editingEvent!!
            var editEventTitle by remember(originalEvent) { mutableStateOf(originalEvent.title) }
            var editEventLocation by remember(originalEvent) { mutableStateOf(originalEvent.location ?: "") }
            AlertDialog(
                onDismissRequest = { editingEvent = null },
                containerColor = SocialMemoryColors.surfaceRaised,
                title = {
                    Text(
                        text = "Edit Event Details", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 18.sp, 
                        fontWeight = FontWeight.Bold
                    ) 
                },
                text = {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        OutlinedTextField(
                            value = editEventTitle,
                            onValueChange = { editEventTitle = it },
                            label = { Text("Event Name", color = SocialMemoryColors.textMuted) },
                            modifier = Modifier.fillMaxWidth(),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SocialMemoryColors.primary,
                                unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                                cursorColor = SocialMemoryColors.primary
                            ),
                            shape = RoundedCornerShape(12.dp)
                        )
                        OutlinedTextField(
                            value = editEventLocation,
                            onValueChange = { editEventLocation = it },
                            label = { Text("Event Location", color = SocialMemoryColors.textMuted) },
                            modifier = Modifier.fillMaxWidth(),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SocialMemoryColors.primary,
                                unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                                cursorColor = SocialMemoryColors.primary
                            ),
                            shape = RoundedCornerShape(12.dp)
                        )
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (editEventTitle.isNotBlank()) {
                                viewModel.updateEvent(originalEvent.copy(
                                    title = editEventTitle,
                                    location = editEventLocation.takeIf { it.isNotBlank() }
                                ))
                                editingEvent = null
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.primary, 
                            contentColor = SocialMemoryColors.textOnAccent
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Save updates", fontWeight = FontWeight.ExtraBold)
                    }
                },
                dismissButton = {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        TextButton(
                            onClick = {
                                viewModel.deleteEvent(originalEvent)
                                editingEvent = null
                            }
                        ) {
                            Text("Delete", color = Color(0xFFD32F2F), fontWeight = FontWeight.Bold)
                        }
                        TextButton(onClick = { editingEvent = null }) {
                            Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                        }
                    }
                },
                shape = RoundedCornerShape(24.dp)
            )
        }

        if (activePersonReminderAction != null) {
            val reminder = activePersonReminderAction!!
            var followupNotes by remember { mutableStateOf("") }
            var selectEventOpen by remember { mutableStateOf(false) }
            var selectedEventId by remember { mutableStateOf<Int?>(null) }
            var eventLocationInput by remember { mutableStateOf("") }

            val selectedEvent = remember(selectedEventId, events) {
                events.find { it.id == selectedEventId }
            }

            LaunchedEffect(selectedEvent) {
                if (selectedEvent != null) {
                    eventLocationInput = selectedEvent.location ?: ""
                }
            }

            AlertDialog(
                onDismissRequest = { activePersonReminderAction = null },
                containerColor = SocialMemoryColors.surfaceRaised,
                title = {
                    Column {
                        Text(
                            text = "Log Action Details",
                            color = SocialMemoryColors.textPrimary,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = reminder.title,
                            color = SocialMemoryColors.primary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                },
                text = {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Surface(
                            color = SocialMemoryColors.surfaceRaised,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(SocialMemoryColors.primary.copy(alpha = 0.12f), CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = person.fullName.take(1).uppercase(),
                                        color = SocialMemoryColors.primary,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Black
                                    )
                                }
                                Text(
                                    text = "Actioned with: ${person.fullName}",
                                    color = SocialMemoryColors.textSecondary,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }

                        // Notes input
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "WHAT DID THEY SAY?", 
                                color = SocialMemoryColors.textMuted, 
                                fontSize = 11.sp, 
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 0.5.sp
                            )
                            OutlinedTextField(
                                value = followupNotes,
                                onValueChange = { followupNotes = it },
                                placeholder = {
                                    Text(
                                        text = "E.g. She said Kyoto hotels were great, especially near Gion.",
                                        color = SocialMemoryColors.textMuted,
                                        fontSize = 13.sp
                                    )
                                },
                                modifier = Modifier.fillMaxWidth().testTag("person_followup_additional_notes"),
                                textStyle = TextStyle(fontSize = 14.sp, color = SocialMemoryColors.textPrimary),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = SocialMemoryColors.primary,
                                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                                ),
                                shape = RoundedCornerShape(12.dp),
                                minLines = 3
                            )
                        }

                        // Event Selector header
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "LINK TO UPDATE AN EVENT (OPTIONAL)", 
                                color = SocialMemoryColors.textMuted, 
                                fontSize = 11.sp, 
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 0.5.sp
                            )
                            
                            // Dropdown select
                            Surface(
                                color = SocialMemoryColors.surface,
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                shadowElevation = if (SocialMemoryColors.isLightMode) 1.dp else 0.dp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { selectEventOpen = !selectEventOpen }
                            ) {
                                Row(
                                    modifier = Modifier.padding(14.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = selectedEvent?.title ?: "Select Event to link location/info",
                                        color = if (selectedEvent != null) SocialMemoryColors.textPrimary else SocialMemoryColors.textMuted,
                                        fontSize = 14.sp
                                    )
                                    Icon(
                                        imageVector = if (selectEventOpen) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                                        contentDescription = "Expand",
                                        tint = SocialMemoryColors.textMuted,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }

                        if (selectEventOpen) {
                            Surface(
                                color = SocialMemoryColors.surface,
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                selectedEventId = null
                                                selectEventOpen = false
                                            }
                                            .padding(14.dp)
                                    ) {
                                        Text(
                                            text = "None (Do not link event)", 
                                            color = SocialMemoryColors.primary, 
                                            fontSize = 13.sp, 
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                    
                                    // Let's filter events to those involving this person, or show all events if fallback
                                    val filteredEvs = if (personEvents.isNotEmpty()) personEvents else events
                                    filteredEvs.forEach { ev ->
                                        HorizontalDivider(color = SocialMemoryColors.borderSubtle, thickness = 1.dp)
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clickable {
                                                    selectedEventId = ev.id
                                                    selectEventOpen = false
                                                }
                                                .padding(14.dp)
                                        ) {
                                            Text(ev.title, color = SocialMemoryColors.textPrimary, fontSize = 13.sp)
                                        }
                                    }
                                }
                            }
                        }

                        // If event is selected, allow location field
                        if (selectedEvent != null) {
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(
                                    text = "UPDATE EVENT LOCATION", 
                                    color = SocialMemoryColors.textMuted, 
                                    fontSize = 11.sp, 
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 0.5.sp
                                )
                                OutlinedTextField(
                                    value = eventLocationInput,
                                    onValueChange = { eventLocationInput = it },
                                    placeholder = { 
                                        Text(
                                            text = "E.g. Bar Isabel, Hanlan's Point Beach", 
                                            color = SocialMemoryColors.textMuted, 
                                            fontSize = 13.sp
                                        ) 
                                    },
                                    modifier = Modifier.fillMaxWidth().testTag("person_followup_event_location_input"),
                                    textStyle = TextStyle(fontSize = 14.sp, color = SocialMemoryColors.textPrimary),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = SocialMemoryColors.primary,
                                        unfocusedBorderColor = SocialMemoryColors.borderSubtle
                                    ),
                                    shape = RoundedCornerShape(12.dp),
                                    singleLine = true
                                )
                            }
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            viewModel.actionReminder(
                                reminder = reminder,
                                notes = followupNotes,
                                eventId = selectedEventId,
                                eventLocation = if (selectedEventId != null) eventLocationInput else null
                            )
                            activePersonReminderAction = null
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.primary, 
                            contentColor = SocialMemoryColors.textOnAccent
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.testTag("person_confirm_action_followup_btn")
                    ) {
                        Text("Save & Complete", fontWeight = FontWeight.Black)
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = { activePersonReminderAction = null }
                    ) {
                        Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                    }
                },
                shape = RoundedCornerShape(28.dp)
            )
        }
    }
}

// Custom padding helper
fun Modifier.fillPaddingSafe() = this
    .fillMaxWidth()
    .statusBarsPadding()

val Slate850: Color @Composable get() = SocialMemoryColors.surfaceRaised
val Slate600: Color @Composable get() = SocialMemoryColors.borderStrong

// ==========================================
// 8. GROUP DETAIL PROFILE SCREEN
// ==========================================

@Composable
fun GroupDetailScreen(groupId: Int, viewModel: AppViewModel, modifier: Modifier) {
    val groups by viewModel.allGroups.collectAsStateWithLifecycle()
    val group = remember(groups) { groups.find { it.id == groupId } }

    val membersState = viewModel.getGroupMembers(groupId).collectAsStateWithLifecycle(emptyList())
    val memoriesState = viewModel.getMemoriesForGroup(groupId).collectAsStateWithLifecycle(emptyList())
    var showAllMemories by remember { mutableStateOf(false) }

    if (group == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Friend Circle not found.", color = SocialMemoryColors.textMuted)
        }
        return
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    IconButton(onClick = { viewModel.navigateBack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                            contentDescription = "Back", 
                            tint = SocialMemoryColors.textPrimary
                        )
                    }
                    Text(
                        text = group.groupName.uppercase(), 
                        fontWeight = FontWeight.Bold, 
                        fontSize = 20.sp, 
                        color = SocialMemoryColors.textPrimary
                    )
                }
                IconButton(onClick = { viewModel.navigateTo(AppScreen.EditGroup(groupId)) }) {
                    Icon(
                        imageVector = Icons.Default.Edit, 
                        contentDescription = "Edit Circle", 
                        tint = SocialMemoryColors.textPrimary
                    )
                }
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header card
            item {
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                    shadowElevation = if (SocialMemoryColors.isLightMode) 1.dp else 0.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp), 
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "CIRCLE DESCRIPTION", 
                            color = SocialMemoryColors.textMuted, 
                            fontSize = 10.sp, 
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 0.5.sp
                        )
                        Text(
                            text = group.description ?: "A private circle of members in Social Brain.", 
                            color = SocialMemoryColors.textSecondary, 
                            fontSize = 14.sp
                        )
                        
                        HorizontalDivider(color = SocialMemoryColors.borderSubtle, modifier = Modifier.padding(vertical = 4.dp))
                        
                        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                            Column {
                                Text("MEMBERS", color = SocialMemoryColors.textMuted, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                Text(membersState.value.size.toString(), color = SocialMemoryColors.primary, fontSize = 18.sp, fontWeight = FontWeight.Black)
                            }
                            Column {
                                Text("UPDATES", color = SocialMemoryColors.textMuted, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                Text(memoriesState.value.size.toString(), color = SocialMemoryColors.info, fontSize = 18.sp, fontWeight = FontWeight.Black)
                            }
                        }
                    }
                }
            }

            // Members indices
            item {
                Text(
                    text = "CIRCLE MEMBERS", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (membersState.value.isEmpty()) {
                item { 
                    Text(
                        text = "No members linked to this circle.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                items(membersState.value) { member ->
                    Surface(
                        color = SocialMemoryColors.surface,
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderStrong),
                        shadowElevation = if (SocialMemoryColors.isLightMode) 3.dp else 0.dp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clickable { viewModel.navigateTo(AppScreen.PersonDetail(member.id)) }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(
                                            Brush.linearGradient(listOf(SocialMemoryColors.primary, SocialMemoryColors.info)),
                                            CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = member.fullName.take(1).uppercase(), 
                                        color = SocialMemoryColors.textOnAccent, 
                                        fontSize = 14.sp, 
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Text(
                                    text = member.fullName, 
                                    fontWeight = FontWeight.Bold, 
                                    color = SocialMemoryColors.textPrimary, 
                                    fontSize = 14.sp
                                )
                            }
                            Icon(
                                imageVector = Icons.Default.ChevronRight, 
                                contentDescription = "View", 
                                tint = SocialMemoryColors.textMuted,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }

            // Collective Memories
            item {
                Text(
                    text = "TIMELINE & UPDATES", 
                    color = SocialMemoryColors.textPrimary, 
                    fontWeight = FontWeight.ExtraBold, 
                    fontSize = 14.sp,
                    letterSpacing = 0.5.sp
                )
            }

            if (memoriesState.value.isEmpty()) {
                item { 
                    Text(
                        text = "No circle-specific updates yet. Log screenshot chat logs or voice transcripts linked to this group.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp 
                    ) 
                }
            } else {
                val sortedMemories = memoriesState.value.sortedByDescending { it.createdAt }
                val displayMemories = if (showAllMemories) sortedMemories else sortedMemories.take(5)

                itemsIndexed(displayMemories) { index, memory ->
                    val isLast = index == displayMemories.size - 1
                    val hasMore = !showAllMemories && sortedMemories.size > 5
                    
                    val firstSentence = memory.content.split(Regex("(?<=[.!?])\\s+")).firstOrNull() ?: memory.content

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(IntrinsicSize.Min)
                    ) {
                        // Timeline line & dot rail
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.width(28.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .padding(top = 4.dp)
                                    .size(14.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Box(modifier = Modifier.size(14.dp).background(SocialMemoryColors.info.copy(alpha = 0.2f), CircleShape))
                                Box(modifier = Modifier.size(10.dp).background(SocialMemoryColors.info, CircleShape))
                            }
                            if (!isLast || hasMore) {
                                Box(
                                    modifier = Modifier
                                        .width(2.dp)
                                        .fillMaxHeight()
                                        .background(SocialMemoryColors.borderStrong)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(12.dp))

                        // Content
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .padding(bottom = 28.dp)
                        ) {
                            Text(
                                text = java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault()).format(java.util.Date(memory.createdAt)),
                                fontSize = 14.sp,
                                color = SocialMemoryColors.textMuted,
                                fontWeight = FontWeight.Bold
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = firstSentence.trim(),
                                color = SocialMemoryColors.textPrimary,
                                fontSize = 16.sp,
                                lineHeight = 24.sp
                            )
                            
                            if (isLast && hasMore) {
                                Spacer(modifier = Modifier.height(16.dp))
                                TextButton(
                                    onClick = { showAllMemories = true },
                                    contentPadding = PaddingValues(0.dp),
                                    modifier = Modifier.height(24.dp)
                                ) {
                                    Text(
                                        text = "View more circle updates", 
                                        color = SocialMemoryColors.info, 
                                        fontSize = 14.sp, 
                                        fontWeight = FontWeight.ExtraBold
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// 9. NEW/ADD SCREENS FOR PROMPT MVP
// ==========================================

@Composable
fun AddPersonScreen(viewModel: AppViewModel, modifier: Modifier) {
    var fullName by remember { mutableStateOf("") }
    var nickname by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var isSelf by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf("") }
    var birthday by remember { mutableStateOf("") }
    val selectedGroupIds = remember { mutableStateListOf<Int>() }
    var showGroupPicker by remember { mutableStateOf(false) }

    val groups by viewModel.allGroups.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(onClick = { viewModel.navigateBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                        contentDescription = "Back", 
                        tint = SocialMemoryColors.textPrimary
                    )
                }
                Text(
                    text = "Add Person Profile", 
                    fontWeight = FontWeight.Bold, 
                    fontSize = 20.sp, 
                    color = SocialMemoryColors.textPrimary
                )
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = fullName,
                onValueChange = { fullName = it },
                label = { Text("Full Name (Required)", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = nickname,
                onValueChange = { nickname = it },
                label = { Text("Nickname", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = location,
                onValueChange = { location = it },
                label = { Text("Address / Location", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email Address", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
            )

            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = { Text("Phone Number", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
            )

            OutlinedTextField(
                value = birthday,
                onValueChange = { birthday = it },
                label = { Text("Birthday (e.g. YYYY-MM-DD)", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "This is my self profile", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 16.sp, 
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "Creates an alias so mentions connect to you.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp
                    )
                }
                Switch(
                    checked = isSelf,
                    onCheckedChange = { isSelf = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = SocialMemoryColors.primary, 
                        checkedTrackColor = SocialMemoryColors.primary.copy(alpha = 0.5f)
                    )
                )
            }

            if (groups.isNotEmpty()) {
                Text(
                    text = "Link to Friend Circle(s):", 
                    fontWeight = FontWeight.Bold, 
                    fontSize = 13.sp, 
                    color = SocialMemoryColors.textPrimary
                )
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val linkedGroups = groups.filter { selectedGroupIds.contains(it.id) }
                    if (linkedGroups.isEmpty()) {
                        Text(
                            text = "None", 
                            color = SocialMemoryColors.textMuted, 
                            fontSize = 14.sp
                        )
                    } else {
                        linkedGroups.forEach { group ->
                            Surface(
                                color = SocialMemoryColors.primary.copy(alpha = 0.12f),
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, SocialMemoryColors.primary.copy(alpha = 0.2f))
                            ) {
                                Text(
                                    text = group.groupName.uppercase(), 
                                    color = SocialMemoryColors.primary, 
                                    fontWeight = FontWeight.Bold, 
                                    fontSize = 12.sp,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                )
                            }
                        }
                    }

                    IconButton(
                        onClick = { showGroupPicker = true },
                        modifier = Modifier
                            .size(36.dp)
                            .background(SocialMemoryColors.surfaceRaised, CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add, 
                            contentDescription = "Add Friend Circle", 
                            tint = SocialMemoryColors.textPrimary, 
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }

            Button(
                onClick = {
                    if (fullName.isNotBlank()) {
                        viewModel.addPerson(
                            fullName = fullName,
                            nickname = nickname.takeIf { it.isNotBlank() },
                            location = location.takeIf { it.isNotBlank() },
                            birthday = birthday.takeIf { it.isNotBlank() },
                            notes = notes.takeIf { it.isNotBlank() },
                            groupIds = selectedGroupIds.toList(),
                            phoneNumber = phoneNumber.takeIf { it.isNotBlank() },
                            email = email.takeIf { it.isNotBlank() },
                            isImported = false,
                            contactIdOnDevice = null,
                            isSelf = isSelf
                        )
                        viewModel.navigateBack()
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SocialMemoryColors.primary, 
                    contentColor = SocialMemoryColors.textOnAccent
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = fullName.isNotBlank()
            ) {
                Text("Save Connections Profile", fontWeight = FontWeight.Black)
            }
        }
    }

    if (showGroupPicker) {
        var searchQuery by remember { mutableStateOf("") }
        val tempSelected = remember { mutableStateListOf<Int>().apply { addAll(selectedGroupIds) } }

        AlertDialog(
            onDismissRequest = { showGroupPicker = false },
            containerColor = SocialMemoryColors.surfaceRaised,
            title = {
                Text(
                    text = "Select Friend Circles", 
                    color = SocialMemoryColors.textPrimary,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        placeholder = { 
                            Text(
                                text = "Search circles...", 
                                color = SocialMemoryColors.textMuted 
                            ) 
                        },
                        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )

                    val filteredGroups = groups.filter { it.groupName.contains(searchQuery, ignoreCase = true) }

                    LazyColumn(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        items(filteredGroups) { group ->
                            val isSelected = tempSelected.contains(group.id)
                            Surface(
                                color = if (isSelected) SocialMemoryColors.primary.copy(alpha = 0.12f) else Color.Transparent,
                                shape = RoundedCornerShape(12.dp),
                                border = if (isSelected) BorderStroke(1.dp, SocialMemoryColors.primary.copy(alpha = 0.2f)) else null,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        if (isSelected) tempSelected.remove(group.id)
                                        else tempSelected.add(group.id)
                                    }
                            ) {
                                Row(
                                    modifier = Modifier
                                        .padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = group.groupName, 
                                        color = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textPrimary, 
                                        fontSize = 16.sp,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                    )
                                    if (isSelected) {
                                        Icon(
                                            imageVector = Icons.Default.Check, 
                                            contentDescription = "Selected", 
                                            tint = SocialMemoryColors.primary, 
                                            modifier = Modifier.size(24.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        selectedGroupIds.clear()
                        selectedGroupIds.addAll(tempSelected)
                        showGroupPicker = false
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SocialMemoryColors.primary, 
                        contentColor = SocialMemoryColors.textOnAccent
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Save Circles", fontWeight = FontWeight.Black)
                }
            },
            dismissButton = {
                TextButton(onClick = { showGroupPicker = false }) {
                    Text("Cancel", color = SocialMemoryColors.textMuted, fontWeight = FontWeight.Bold)
                }
            },
            shape = RoundedCornerShape(24.dp)
        )
    }
}

@Composable
fun EditPersonScreen(personId: Int, viewModel: AppViewModel, modifier: Modifier) {
    val people by viewModel.allPeople.collectAsStateWithLifecycle()
    val groups by viewModel.allGroups.collectAsStateWithLifecycle()
    val person = people.find { it.id == personId }

    if (person == null) {
        Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Person not found", color = Slate50) }
        return
    }

    var fullName by remember(person) { mutableStateOf(person.fullName) }
    var nickname by remember(person) { mutableStateOf(person.nickname ?: "") }
    var location by remember(person) { mutableStateOf(person.location ?: "") }
    var notes by remember(person) { mutableStateOf(person.notes ?: "") }
    var isSelf by remember(person) { mutableStateOf(person.isSelf) }
    var email by remember(person) { mutableStateOf(person.email ?: "") }
    var phoneNumber by remember(person) { mutableStateOf(person.phoneNumber ?: "") }
    var birthday by remember(person) { mutableStateOf(person.birthday ?: "") }
    
    val selectedGroupIds = remember { mutableStateListOf<Int>() }
    var showGroupPicker by remember { mutableStateOf(false) }

    LaunchedEffect(personId) {
        val personGroups = viewModel.getGroupsForPerson(personId).first()
        selectedGroupIds.clear()
        selectedGroupIds.addAll(personGroups.map { it.id })
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(onClick = { viewModel.navigateBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                        contentDescription = "Back", 
                        tint = SocialMemoryColors.textPrimary
                    )
                }
                Text(
                    text = if (personId == 0) "Add Person Profile" else "Edit Person Profile", 
                    fontWeight = FontWeight.Bold, 
                    fontSize = 20.sp, 
                    color = SocialMemoryColors.textPrimary
                )
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = fullName,
                onValueChange = { fullName = it },
                label = { Text("Full Name (Required)", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = nickname,
                onValueChange = { nickname = it },
                label = { Text("Nickname", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = location,
                onValueChange = { location = it },
                label = { Text("Address / Location", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email Address", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
            )

            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = { Text("Phone Number", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
            )

            OutlinedTextField(
                value = birthday,
                onValueChange = { birthday = it },
                label = { Text("Birthday (e.g. YYYY-MM-DD)", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "This is my self profile", 
                        color = SocialMemoryColors.textPrimary, 
                        fontSize = 16.sp, 
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "Creates an alias so mentions connect to you.", 
                        color = SocialMemoryColors.textMuted, 
                        fontSize = 12.sp
                    )
                }
                Switch(
                    checked = isSelf,
                    onCheckedChange = { isSelf = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = SocialMemoryColors.primary, 
                        checkedTrackColor = SocialMemoryColors.primary.copy(alpha = 0.5f)
                    )
                )
            }

            if (groups.isNotEmpty()) {
                Text("Link to Friend Circle(s):", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = SocialMemoryColors.textPrimary)
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val linkedGroups = groups.filter { selectedGroupIds.contains(it.id) }
                    if (linkedGroups.isEmpty()) {
                        Text("None", color = SocialMemoryColors.textMuted, fontSize = 14.sp)
                    } else {
                        linkedGroups.forEach { group ->
                            Box(
                                modifier = Modifier
                                    .background(SocialMemoryColors.primary, RoundedCornerShape(4.dp))
                                    .padding(horizontal = 10.dp, vertical = 6.dp)
                            ) {
                                Text(group.groupName.uppercase(), color = SocialMemoryColors.background, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }
                    }

                    IconButton(
                        onClick = { showGroupPicker = true },
                        modifier = Modifier
                            .size(32.dp)
                            .background(SocialMemoryColors.surfaceRaised, CircleShape)
                    ) {
                        Icon(Icons.Default.Add, "Add Friend Circle", tint = SocialMemoryColors.textPrimary, modifier = Modifier.size(20.dp))
                    }
                }
            }

            Button(
                onClick = {
                    if (fullName.isNotBlank()) {
                        viewModel.updatePerson(
                            personId = personId,
                            fullName = fullName,
                            nickname = nickname.takeIf { it.isNotBlank() },
                            location = location.takeIf { it.isNotBlank() },
                            birthday = birthday.takeIf { it.isNotBlank() },
                            notes = notes.takeIf { it.isNotBlank() },
                            groupIds = selectedGroupIds.toList(),
                            phoneNumber = phoneNumber.takeIf { it.isNotBlank() },
                            email = email.takeIf { it.isNotBlank() },
                            isSelf = isSelf
                        )
                        viewModel.navigateBack()
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SocialMemoryColors.primary, 
                    contentColor = SocialMemoryColors.textOnAccent
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = fullName.isNotBlank()
            ) {
                Text("Save Updates", fontWeight = FontWeight.Black)
            }
        }
    }

    if (showGroupPicker) {
        var searchQuery by remember { mutableStateOf("") }
        val tempSelected = remember { mutableStateListOf<Int>().apply { addAll(selectedGroupIds) } }

        AlertDialog(
            onDismissRequest = { showGroupPicker = false },
            containerColor = SocialMemoryColors.surfaceRaised,
            titleContentColor = SocialMemoryColors.textPrimary,
            textContentColor = SocialMemoryColors.textSecondary,
            title = {
                Text("Select Friend Circles", fontWeight = FontWeight.Bold)
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        placeholder = { Text("Search circles...", color = SocialMemoryColors.textMuted) },
                        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary
                        ),
                        singleLine = true
                    )

                    val filteredGroups = groups.filter { it.groupName.contains(searchQuery, ignoreCase = true) }

                    LazyColumn(modifier = Modifier.fillMaxWidth()) {
                        items(filteredGroups) { group ->
                            val isSelected = tempSelected.contains(group.id)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        if (isSelected) tempSelected.remove(group.id)
                                        else tempSelected.add(group.id)
                                    }
                                    .padding(vertical = 12.dp, horizontal = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(group.groupName, color = if (isSelected) SocialMemoryColors.primary else SocialMemoryColors.textPrimary, fontSize = 16.sp)
                                if (isSelected) {
                                    Icon(Icons.Default.Check, "Selected", tint = SocialMemoryColors.primary, modifier = Modifier.size(20.dp))
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    selectedGroupIds.clear()
                    selectedGroupIds.addAll(tempSelected)
                    showGroupPicker = false
                }) {
                    Text("Save", color = SocialMemoryColors.primary, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showGroupPicker = false }) {
                    Text("Cancel", color = SocialMemoryColors.textMuted)
                }
            }
        )
    }
}

@Composable
fun AddGroupScreen(viewModel: AppViewModel, modifier: Modifier) {
    val groups by viewModel.allGroups.collectAsStateWithLifecycle()
    var groupName by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }

    val isDuplicate = remember(groups, groupName) {
        val trimmed = groupName.trim()
        trimmed.isNotEmpty() && groups.any { it.groupName.trim().equals(trimmed, ignoreCase = true) }
    }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(onClick = { viewModel.navigateBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                        contentDescription = "Back", 
                        tint = SocialMemoryColors.textPrimary
                    )
                }
                Text(
                    text = "Create Friend Circle", 
                    fontWeight = FontWeight.Bold, 
                    fontSize = 20.sp, 
                    color = SocialMemoryColors.textPrimary
                )
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = groupName,
                onValueChange = { groupName = it.uppercase() },
                label = { 
                    Text(
                        text = "Circle Name (Required)", 
                        color = if (isDuplicate) SocialMemoryColors.rose else SocialMemoryColors.textMuted 
                    ) 
                },
                modifier = Modifier.fillMaxWidth().testTag("circle_name_input"),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = if (isDuplicate) SocialMemoryColors.rose else SocialMemoryColors.primary,
                    unfocusedBorderColor = if (isDuplicate) SocialMemoryColors.rose else SocialMemoryColors.borderSubtle,
                    errorBorderColor = SocialMemoryColors.rose,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                isError = isDuplicate,
                shape = RoundedCornerShape(12.dp)
            )

            if (isDuplicate) {
                Text(
                    text = "A Circle or Group with this name already exists.",
                    color = SocialMemoryColors.rose,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(start = 4.dp).testTag("duplicate_group_error")
                )
            }

            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("Description", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp).testTag("circle_desc_input"),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Button(
                onClick = {
                    if (groupName.isNotBlank() && !isDuplicate) {
                        viewModel.addGroup(groupName, description.takeIf { it.isNotBlank() }, emptyList())
                        viewModel.navigateBack()
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SocialMemoryColors.primary, 
                    contentColor = SocialMemoryColors.textOnAccent
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp).testTag("create_circle_button"),
                shape = RoundedCornerShape(12.dp),
                enabled = groupName.isNotBlank() && !isDuplicate
            ) {
                Text("Create Circle Board", fontWeight = FontWeight.Black)
            }
        }
    }
}

@Composable
fun AddEventScreen(viewModel: AppViewModel, modifier: Modifier) {
    var title by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            Row(
                modifier = Modifier
                    .fillPaddingSafe()
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(onClick = { viewModel.navigateBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                        contentDescription = "Back", 
                        tint = SocialMemoryColors.textPrimary
                    )
                }
                Text(
                    text = "Schedule Social Event", 
                    fontWeight = FontWeight.Bold, 
                    fontSize = 20.sp, 
                    color = SocialMemoryColors.textPrimary
                )
            }
        },
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Event Title (Required)", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = location,
                onValueChange = { location = it },
                label = { Text("Location", color = SocialMemoryColors.textMuted) },
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SocialMemoryColors.primary,
                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                    focusedTextColor = SocialMemoryColors.textPrimary,
                    unfocusedTextColor = SocialMemoryColors.textPrimary
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Button(
                onClick = {
                    if (title.isNotBlank()) {
                        viewModel.addEvent(title, System.currentTimeMillis() + (24 * 60 * 60 * 1000), location.takeIf { it.isNotBlank() }, null, emptyList())
                        viewModel.navigateBack()
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SocialMemoryColors.primary, 
                    contentColor = SocialMemoryColors.textOnAccent
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = title.isNotBlank()
            ) {
                Text("Schedule Event", fontWeight = FontWeight.Black)
            }
        }
    }
}

// ==========================================
// 10. SETTINGS & NOTIFICATIONS SCREENS
// ==========================================

@Composable
fun SettingsScreen(viewModel: AppViewModel, modifier: Modifier) {
    val appSettings by viewModel.appSettings.collectAsStateWithLifecycle()
    
    var email by remember(appSettings) { mutableStateOf(appSettings?.email ?: "") }
    var phone by remember(appSettings) { mutableStateOf(appSettings?.phoneNumber ?: "") }
    var themeMode by remember(appSettings) { mutableStateOf(appSettings?.themeMode ?: "DARK") }
    var timeZone by remember(appSettings) { mutableStateOf(appSettings?.timeZone ?: "EST") }

    Surface(
        modifier = modifier.padding(16.dp),
        color = SocialMemoryColors.background,
        shape = RoundedCornerShape(28.dp),
        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
        shadowElevation = 8.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Settings",
                    color = SocialMemoryColors.textPrimary,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                IconButton(
                    onClick = { viewModel.setTab(AppScreen.Home) },
                    modifier = Modifier.background(SocialMemoryColors.surfaceRaised, CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = SocialMemoryColors.textSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(28.dp)
            ) {
                // Profile
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        "Profile & Contact",
                        color = SocialMemoryColors.textPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        label = { Text("Email", color = SocialMemoryColors.textMuted) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
    
                    OutlinedTextField(
                        value = phone,
                        onValueChange = { phone = it },
                        label = { Text("Phone Number", color = SocialMemoryColors.textMuted) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SocialMemoryColors.primary,
                            unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                            focusedTextColor = SocialMemoryColors.textPrimary,
                            unfocusedTextColor = SocialMemoryColors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                }
    
                // Appearance
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        "Appearance",
                        color = SocialMemoryColors.textPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    
                    Surface(
                        color = SocialMemoryColors.surface,
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                "Theme Preference",
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                listOf("SYSTEM", "LIGHT", "DARK").forEach { mode ->
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically, 
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(8.dp))
                                            .clickable { themeMode = mode }
                                            .padding(vertical = 4.dp)
                                    ) {
                                        RadioButton(
                                            selected = themeMode == mode,
                                            onClick = { themeMode = mode },
                                            colors = RadioButtonDefaults.colors(
                                                selectedColor = SocialMemoryColors.primary,
                                                unselectedColor = SocialMemoryColors.textMuted
                                            )
                                        )
                                        Text(
                                            text = mode.lowercase().replaceFirstChar { it.uppercase() },
                                            color = SocialMemoryColors.textPrimary,
                                            fontSize = 15.sp,
                                            modifier = Modifier.padding(start = 8.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Calendars
                val connectedCals by viewModel.connectedExternalCalendars.collectAsStateWithLifecycle()
                
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        "External Calendars",
                        color = SocialMemoryColors.textPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    
                    Surface(
                        color = SocialMemoryColors.surface,
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                "Time Zone",
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            OutlinedTextField(
                                value = timeZone,
                                onValueChange = { timeZone = it },
                                modifier = Modifier.fillMaxWidth(),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = SocialMemoryColors.primary,
                                    unfocusedBorderColor = SocialMemoryColors.borderSubtle,
                                    focusedTextColor = SocialMemoryColors.textPrimary,
                                    unfocusedTextColor = SocialMemoryColors.textPrimary
                                ),
                                shape = RoundedCornerShape(12.dp)
                            )
                            
                            Spacer(modifier = Modifier.height(24.dp))
                            
                            Text(
                                "Connected Calendars",
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            val isGoogleConnected = connectedCals.contains("Google")
                            Button(
                                onClick = { viewModel.toggleExternalCalendar("Google") },
                                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = if (isGoogleConnected) SocialMemoryColors.surfaceRaised else Color(0xFF4285F4))
                            ) {
                                Text(if (isGoogleConnected) "Disconnect Google Calendar" else "Connect Google Calendar", color = if (isGoogleConnected) SocialMemoryColors.textPrimary else Color.White)
                            }
                            
                            val isOutlookConnected = connectedCals.contains("Outlook")
                            Button(
                                onClick = { viewModel.toggleExternalCalendar("Outlook") },
                                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = if (isOutlookConnected) SocialMemoryColors.surfaceRaised else Color(0xFF0078D4))
                            ) {
                                Text(if (isOutlookConnected) "Disconnect Outlook" else "Connect Outlook", color = if (isOutlookConnected) SocialMemoryColors.textPrimary else Color.White)
                            }
                            
                            val isICloudConnected = connectedCals.contains("iCloud")
                            Button(
                                onClick = { viewModel.toggleExternalCalendar("iCloud") },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(containerColor = if (isICloudConnected) SocialMemoryColors.surfaceRaised else Color.Black)
                            ) {
                                Text(if (isICloudConnected) "Disconnect iCloud Calendar" else "Connect iCloud Calendar", color = if (isICloudConnected) SocialMemoryColors.textPrimary else Color.White)
                            }
                            
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "If you have calendars connected, they will automatically sync once a day at 5:00 AM based on your specified Time Zone.",
                                color = SocialMemoryColors.textSecondary,
                                fontSize = 12.sp,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
                
                // Privacy & Data
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        "Privacy & Data",
                        color = SocialMemoryColors.textPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    
                    Surface(
                        color = SocialMemoryColors.surface,
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.Lock,
                                    contentDescription = null,
                                    tint = SocialMemoryColors.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    "Local-first storage",
                                    color = SocialMemoryColors.textPrimary,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Spacer(modifier = Modifier.weight(1f))
                                Text(
                                    "Enabled",
                                    color = SocialMemoryColors.primary,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "All data remains private and stored directly on your device. No cloud sync is used without your explicit authorization.", 
                                color = SocialMemoryColors.textSecondary, 
                                fontSize = 12.sp,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
                
                var showFeatureSuggestionDialog by remember { mutableStateOf(false) }
                
                // Feedback
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        "Feedback",
                        color = SocialMemoryColors.textPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    
                    Button(
                        onClick = { showFeatureSuggestionDialog = true },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SocialMemoryColors.surfaceRaised,
                            contentColor = SocialMemoryColors.primary
                        ),
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                        border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(Icons.Default.Lightbulb, contentDescription = "Suggest Feature")
                            Text("Suggest a Feature / Improvement", fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                
                if (showFeatureSuggestionDialog) {
                    var suggestionTitle by remember { mutableStateOf("") }
                    var suggestionDescription by remember { mutableStateOf("") }
                    
                    AlertDialog(
                        onDismissRequest = { showFeatureSuggestionDialog = false },
                        title = { Text("Suggest a Feature") },
                        text = {
                            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                Text("Have an idea to improve Social Memory? Let us know!", fontSize = 14.sp)
                                
                                OutlinedTextField(
                                    value = suggestionTitle,
                                    onValueChange = { suggestionTitle = it },
                                    label = { Text("Feature Title") },
                                    modifier = Modifier.fillMaxWidth()
                                )
                                
                                OutlinedTextField(
                                    value = suggestionDescription,
                                    onValueChange = { suggestionDescription = it },
                                    label = { Text("Description") },
                                    modifier = Modifier.fillMaxWidth().height(120.dp),
                                    maxLines = 5
                                )
                            }
                        },
                        confirmButton = {
                            TextButton(
                                onClick = { 
                                    // In a real app this would call an API or send an email
                                    showFeatureSuggestionDialog = false 
                                },
                                enabled = suggestionTitle.isNotBlank() && suggestionDescription.isNotBlank()
                            ) {
                                Text("Submit Idea")
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showFeatureSuggestionDialog = false }) {
                                Text("Cancel")
                            }
                        }
                    )
                }
            }
    
            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = {
                    viewModel.updateAppSettings(email, phone, themeMode, timeZone)
                    viewModel.setTab(AppScreen.Home)
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = SocialMemoryColors.primary,
                    contentColor = SocialMemoryColors.textOnAccent
                ),
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(100)
            ) {
                Text("Save Changes", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text(
                    "Social Brain",
                    color = SocialMemoryColors.textPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                )
                Text("Version 1.1.0", color = SocialMemoryColors.textMuted, fontSize = 11.sp)
            }
        }
    }
}

@Composable
fun NotificationsScreen(viewModel: AppViewModel, modifier: Modifier) {
    Scaffold(
        containerColor = SocialMemoryColors.background,
        modifier = modifier
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(top = 16.dp, bottom = 168.dp)
        ) {
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
                ) {
                    IconButton(
                        onClick = { viewModel.setTab(AppScreen.Home) }
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack, 
                            contentDescription = "Back", 
                            tint = SocialMemoryColors.textPrimary
                        )
                    }
                    Text(
                        text = "Notifications", 
                        color = SocialMemoryColors.textPrimary,
                        fontSize = 22.sp, 
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }

            // Needs Review Section
            item {
                Text(
                    text = "NEEDS REVIEW", 
                    color = SocialMemoryColors.textMuted,
                    fontSize = 11.sp, 
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Surface(
                            color = SocialMemoryColors.warningContainer,
                            shape = CircleShape,
                            modifier = Modifier.size(40.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.Info, 
                                    contentDescription = null, 
                                    tint = SocialMemoryColors.warning,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "3 AI suggestions need confirmation", 
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp
                            )
                            Text(
                                "Pending Review", 
                                color = SocialMemoryColors.textMuted,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }

            // Upcoming Section
            item {
                Text(
                    text = "UPCOMING", 
                    color = SocialMemoryColors.textMuted,
                    fontSize = 11.sp, 
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Surface(
                            color = SocialMemoryColors.infoContainer,
                            shape = CircleShape,
                            modifier = Modifier.size(40.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.CalendarToday, 
                                    contentDescription = null, 
                                    tint = SocialMemoryColors.info,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "Michelle Birthday Dinner", 
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp
                            )
                            Text(
                                "Sat 7:00 PM", 
                                color = SocialMemoryColors.textMuted,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }

            // System Section
            item {
                Text(
                    text = "SYSTEM", 
                    color = SocialMemoryColors.textMuted,
                    fontSize = 11.sp, 
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = SocialMemoryColors.surface,
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, SocialMemoryColors.borderSubtle)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Surface(
                            color = SocialMemoryColors.primary.copy(alpha = 0.1f),
                            shape = CircleShape,
                            modifier = Modifier.size(40.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle, 
                                    contentDescription = null, 
                                    tint = SocialMemoryColors.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "Data Sync Completed", 
                                color = SocialMemoryColors.textPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp
                            )
                            Text(
                                "All items saved locally.", 
                                color = SocialMemoryColors.textMuted,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
