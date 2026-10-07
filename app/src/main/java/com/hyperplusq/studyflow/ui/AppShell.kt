package com.hyperplusq.studyflow.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Dashboard
import androidx.compose.material.icons.automirrored.outlined.LibraryBooks
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.TimeBlockEntity

enum class AppTab(val title: String) {
    DASHBOARD("概览"),
    ASSIGNMENTS("作业"),
    SCHEDULE("日程"),
    SUBJECTS("科目"),
    SETTINGS("设置")
}

@Composable
    /** 应用根组件，负责页面状态与弹窗协调。 */
fun StudyFlowAppUi(viewModel: AppViewModel) {
    val state by viewModel.uiState.collectAsState()
    val message by viewModel.message.collectAsState()
    var tab by remember { mutableStateOf(AppTab.DASHBOARD) }
    var selectedSubjectId by remember { mutableStateOf<Long?>(null) }

    var assignmentEditorOpen by remember { mutableStateOf(false) }
    var editingAssignmentId by remember { mutableStateOf<Long?>(null) }
    var detailAssignmentId by remember { mutableStateOf<Long?>(null) }
    var timeBlockEditorOpen by remember { mutableStateOf(false) }
    var editingTimeBlockId by remember { mutableStateOf<Long?>(null) }

    val editingAssignment = state.assignments.firstOrNull {
        it.assignment.id == editingAssignmentId
    }
    val detailAssignment = state.assignments.firstOrNull {
        it.assignment.id == detailAssignmentId
    }
    val editingTimeBlock = state.timeBlocks.firstOrNull { it.id == editingTimeBlockId }

    fun openNewAssignment() {
        editingAssignmentId = null
        assignmentEditorOpen = true
    }

    fun openAssignment(id: Long?) {
        editingAssignmentId = id
        assignmentEditorOpen = true
    }

    fun openNewTimeBlock() {
        editingTimeBlockId = null
        timeBlockEditorOpen = true
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val compactPortrait = maxWidth < 600.dp && maxHeight >= maxWidth
        // A compact, icon-only floating rail keeps more room for content in landscape.
        val panelWidth = 88.dp

        AppBackground()

        if (compactPortrait) {
            CompactLayout(
                viewModel = viewModel,
                state = state,
                tab = tab,
                onTab = { tab = it },
                selectedSubjectId = selectedSubjectId,
                onSelectSubject = { selectedSubjectId = it },
                message = message,
                onOpenAssignment = { detailAssignmentId = it },
                onEditAssignment = { openAssignment(it) },
                onNewAssignment = ::openNewAssignment,
                onEditTimeBlock = {
                    editingTimeBlockId = it
                    timeBlockEditorOpen = true
                },
                onNewTimeBlock = ::openNewTimeBlock
            )
        } else {
            LargeLayout(
                viewModel = viewModel,
                state = state,
                tab = tab,
                onTab = { tab = it },
                selectedSubjectId = selectedSubjectId,
                onSelectSubject = { selectedSubjectId = it },
                message = message,
                panelWidth = panelWidth,
                onOpenAssignment = { detailAssignmentId = it },
                onEditAssignment = { openAssignment(it) },
                onNewAssignment = ::openNewAssignment,
                onEditTimeBlock = {
                    editingTimeBlockId = it
                    timeBlockEditorOpen = true
                },
                onNewTimeBlock = ::openNewTimeBlock
            )
        }
    }

    if (assignmentEditorOpen) {
        AssignmentEditorDialog(
            initial = editingAssignment,
            state = state,
            onDismiss = { assignmentEditorOpen = false },
            onSave = { assignment: AssignmentEntity, attachments ->
                viewModel.saveAssignment(assignment, attachments)
                assignmentEditorOpen = false
            }
        )
    }

    detailAssignment?.let { item ->
        AssignmentDetailDialog(
            item = item,
            state = state,
            onDismiss = { detailAssignmentId = null },
            onEdit = {
                detailAssignmentId = null
                openAssignment(item.assignment.id)
            },
            onDelete = { viewModel.deleteAssignment(item.assignment.id) },
            onToggleComplete = { viewModel.setAssignmentCompleted(item.assignment.id, it) },
            onSaveSubtask = { viewModel.saveSubtask(it) },
            onDeleteSubtask = { viewModel.deleteSubtask(it) },
            onToggleSubtask = { subtask, completed ->
                viewModel.setSubtaskCompleted(subtask.id, completed)
            },
            onCancelCalendarSync = { viewModel.cancelCalendarSync(item.assignment.id) }
        )
    }

    if (timeBlockEditorOpen) {
        TimeBlockEditorDialog(
            initial = editingTimeBlock,
            state = state,
            onDismiss = { timeBlockEditorOpen = false },
            onSave = { viewModel.saveTimeBlock(it) },
            onDelete = { viewModel.deleteTimeBlock(it) }
        )
    }
}

@Composable
private fun AppBackground() {
    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    )
}

@Composable
    /** 手机竖屏使用底栏和正常内容布局。 */
private fun CompactLayout(
    viewModel: AppViewModel,
    state: AppUiState,
    tab: AppTab,
    onTab: (AppTab) -> Unit,
    selectedSubjectId: Long?,
    onSelectSubject: (Long?) -> Unit,
    message: String?,
    onOpenAssignment: (Long) -> Unit,
    onEditAssignment: (Long) -> Unit,
    onNewAssignment: () -> Unit,
    onEditTimeBlock: (Long) -> Unit,
    onNewTimeBlock: () -> Unit
) {
    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            Surface(
                shape = RoundedCornerShape(40.dp),
                color = Color.Transparent,
                tonalElevation = 0.dp,
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 10.dp)
                    .navigationBarsPadding()
            ) {
                Box(Modifier.fillMaxWidth()) {
                    // A softly blurred translucent layer keeps the pill background airy
                    // without blurring the navigation icons themselves.
                    Box(
                        Modifier
                            .matchParentSize()
                            .clip(RoundedCornerShape(40.dp))
                            .blur(18.dp)
                            .background(
                                MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.72f)
                            )
                    )
                    NavigationBar(
                        containerColor = Color.Transparent,
                        tonalElevation = 0.dp
                    ) {
                        AppTab.entries.forEach { item ->
                            BottomNavigationItem(
                                selected = tab == item,
                                onClick = { onTab(item) },
                                icon = tabIcon(item),
                                contentDescription = item.title
                            )
                        }
                    }
                }
            }
        },
        floatingActionButton = {
            when (tab) {
                AppTab.ASSIGNMENTS -> FloatingActionButton(
                    onClick = onNewAssignment,
                    containerColor = MaterialTheme.colorScheme.primary
                ) { Icon(Icons.AutoMirrored.Outlined.Assignment, "新建作业") }

                AppTab.SCHEDULE -> FloatingActionButton(
                    onClick = onNewTimeBlock,
                    containerColor = MaterialTheme.colorScheme.primary
                ) { Icon(Icons.Outlined.CalendarMonth, "新建时间块") }
                else -> Unit
            }
        }
    ) { padding ->
        AppContent(
            viewModel = viewModel,
            state = state,
            tab = tab,
            selectedSubjectId = selectedSubjectId,
            onSelectSubject = onSelectSubject,
            modifier = Modifier.padding(padding),
            message = message,
            onOpenAssignment = onOpenAssignment,
            onEditAssignment = onEditAssignment,
            onEditTimeBlock = onEditTimeBlock
        )
    }
}

@Composable
private fun RowScope.BottomNavigationItem(
    selected: Boolean,
    onClick: () -> Unit,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()

    Box(
        modifier = Modifier
            .weight(1f)
            .height(64.dp),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(
                    when {
                        selected -> MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)
                        pressed -> MaterialTheme.colorScheme.primary.copy(alpha = 0.10f)
                        else -> Color.Transparent
                    }
                )
                .clickable(
                    interactionSource = interactionSource,
                    indication = null,
                    role = Role.Tab,
                    onClick = onClick
                )
                .semantics {
                    this.contentDescription = contentDescription
                    this.selected = selected
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (selected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

@Composable
    /** 大屏使用右侧悬浮侧边栏布局。 */
private fun LargeLayout(
    viewModel: AppViewModel,
    state: AppUiState,
    tab: AppTab,
    onTab: (AppTab) -> Unit,
    selectedSubjectId: Long?,
    onSelectSubject: (Long?) -> Unit,
    message: String?,
    panelWidth: Dp,
    onOpenAssignment: (Long) -> Unit,
    onEditAssignment: (Long) -> Unit,
    onNewAssignment: () -> Unit,
    onEditTimeBlock: (Long) -> Unit,
    onNewTimeBlock: () -> Unit
) {
    Box(Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = Color.Transparent,
            modifier = Modifier
                .fillMaxSize()
                .padding(end = panelWidth),
                floatingActionButton = {
                when (tab) {
                    AppTab.ASSIGNMENTS -> ExtendedFloatingActionButton(
                        onClick = onNewAssignment,
                        icon = { Icon(Icons.AutoMirrored.Outlined.Assignment, null) },
                        text = { Text("新建作业") }
                    )
                    AppTab.SCHEDULE -> ExtendedFloatingActionButton(
                        onClick = onNewTimeBlock,
                        icon = { Icon(Icons.Outlined.CalendarMonth, null) },
                        text = { Text("新建时间块") }
                    )
                    else -> Unit
                }
            }
        ) { padding ->
            AppContent(
                viewModel = viewModel,
                state = state,
                tab = tab,
                selectedSubjectId = selectedSubjectId,
                onSelectSubject = onSelectSubject,
                modifier = Modifier.padding(padding),
                message = message,
                onOpenAssignment = onOpenAssignment,
                onEditAssignment = onEditAssignment,
                onEditTimeBlock = onEditTimeBlock
            )
        }

        Surface(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(top = 14.dp, bottom = 14.dp, end = 14.dp)
                .width(panelWidth)
                .fillMaxHeight(),
            shape = RoundedCornerShape(34.dp),
            color = MaterialTheme.colorScheme.surfaceContainer,
            tonalElevation = 5.dp
        ) {
            SidebarContent(
                state = state,
                tab = tab,
                onTab = onTab,
                selectedSubjectId = selectedSubjectId,
                onSelectSubject = onSelectSubject,
                onNewAssignment = onNewAssignment,
                onNewTimeBlock = onNewTimeBlock
            )
        }
    }
}

@Composable
private fun SidebarContent(
    state: AppUiState,
    tab: AppTab,
    onTab: (AppTab) -> Unit,
    selectedSubjectId: Long?,
    onSelectSubject: (Long?) -> Unit,
    onNewAssignment: (() -> Unit)? = null,
    onNewTimeBlock: (() -> Unit)? = null
) {
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (onNewAssignment != null) {
            Spacer(Modifier.height(16.dp))
            FloatingActionButton(
                onClick = onNewAssignment,
                containerColor = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(56.dp)
            ) {
                Icon(Icons.AutoMirrored.Outlined.Assignment, "新建作业")
            }
            Spacer(Modifier.height(10.dp))
            if (onNewTimeBlock != null) {
                FloatingActionButton(
                    onClick = onNewTimeBlock,
                    containerColor = MaterialTheme.colorScheme.secondaryContainer,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(Icons.Outlined.CalendarMonth, "安排时间块")
                }
                Spacer(Modifier.height(14.dp))
            }
            HorizontalDivider(Modifier.padding(horizontal = 14.dp))
        }

        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(top = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            AppTab.entries.forEach { item ->
                IconNavigationItem(
                    selected = tab == item,
                    onClick = { onTab(item) },
                    contentDescription = item.title,
                    icon = { Icon(tabIcon(item), contentDescription = null) }
                )
            }

            if (tab == AppTab.ASSIGNMENTS) {
                Spacer(Modifier.height(8.dp))
                HorizontalDivider(Modifier.padding(horizontal = 14.dp))
                Spacer(Modifier.height(8.dp))
                SubjectFilterIcon(
                    selected = selectedSubjectId == null,
                    onClick = { onSelectSubject(null) },
                    contentDescription = "全部科目",
                    color = null
                )
                state.subjects.forEach { subject ->
                    SubjectFilterIcon(
                        selected = selectedSubjectId == subject.id,
                        onClick = { onSelectSubject(subject.id) },
                        contentDescription = subject.name,
                        color = subject.colorHex?.toComposeColorOrNull()
                    )
                }
            }
        }
    }
}

@Composable
private fun IconNavigationItem(
    selected: Boolean,
    onClick: () -> Unit,
    contentDescription: String,
    icon: @Composable () -> Unit
) {
    Box(
        Modifier
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .size(56.dp)
            .clip(CircleShape)
            .background(
                if (selected) MaterialTheme.colorScheme.primaryContainer
                else Color.Transparent
            )
            .clickable(onClick = onClick, role = Role.Button)
            .semantics {
                this.contentDescription = contentDescription
                this.selected = selected
            },
        contentAlignment = Alignment.Center
    ) {
        icon()
        if (selected) {
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 4.dp)
                    .size(4.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape)
            )
        }
    }
}

@Composable
private fun SubjectFilterIcon(
    selected: Boolean,
    onClick: () -> Unit,
    contentDescription: String,
    color: Color?
) {
    Box(
        Modifier
            .padding(horizontal = 16.dp, vertical = 5.dp)
            .size(48.dp)
            .clip(CircleShape)
            .background(
                if (selected) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surfaceContainerHigh
            )
            .clickable(onClick = onClick, role = Role.Button)
            .semantics {
                this.contentDescription = contentDescription
                this.selected = selected
            },
        contentAlignment = Alignment.Center
    ) {
        if (color == null) {
            Icon(
                Icons.Outlined.Layers,
                contentDescription = null,
                modifier = Modifier.size(22.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            Box(
                Modifier
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(color)
            )
        }
    }
}

@Composable
    /** 根据当前标签页渲染主要业务页面。 */
private fun AppContent(
    viewModel: AppViewModel,
    state: AppUiState,
    tab: AppTab,
    selectedSubjectId: Long?,
    onSelectSubject: (Long?) -> Unit,
    modifier: Modifier = Modifier,
    message: String?,
    onOpenAssignment: (Long) -> Unit,
    onEditAssignment: (Long) -> Unit,
    onEditTimeBlock: (Long) -> Unit
) {
    Box(modifier.fillMaxSize()) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "tab"
        ) { target ->
            when (target) {
                AppTab.DASHBOARD -> DashboardScreen(state)
                AppTab.ASSIGNMENTS -> AssignmentsScreen(
                    viewModel = viewModel,
                    state = state,
                    selectedSubjectId = selectedSubjectId,
                    onSelectSubject = onSelectSubject,
                    onOpen = onOpenAssignment,
                    onEdit = onEditAssignment
                )
                AppTab.SCHEDULE -> ScheduleScreen(
                    viewModel = viewModel,
                    state = state,
                    onEdit = onEditTimeBlock
                )
                AppTab.SUBJECTS -> SubjectsScreen(viewModel, state)
                AppTab.SETTINGS -> SettingsScreen(viewModel, state)
            }
        }

        message?.let {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 92.dp, start = 24.dp, end = 24.dp),
                shape = RoundedCornerShape(24.dp),
                color = MaterialTheme.colorScheme.inverseSurface,
                shadowElevation = 8.dp
            ) {
                Text(
                    it,
                    Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                    color = MaterialTheme.colorScheme.inverseOnSurface
                )
            }
        }
    }
}

private fun tabIcon(tab: AppTab) = when (tab) {
    AppTab.DASHBOARD -> Icons.Outlined.Dashboard
    AppTab.ASSIGNMENTS -> Icons.AutoMirrored.Outlined.Assignment
    AppTab.SCHEDULE -> Icons.Outlined.CalendarMonth
    AppTab.SUBJECTS -> Icons.AutoMirrored.Outlined.LibraryBooks
    AppTab.SETTINGS -> Icons.Outlined.Settings
}
