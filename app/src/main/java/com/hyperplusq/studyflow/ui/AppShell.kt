package com.hyperplusq.studyflow.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.WindowInsets
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource

// 竖屏底栏与横屏侧边栏统一使用真正的胶囊圆角。
private val PillShape = RoundedCornerShape(percent = 50)

// 底栏高度较 1.6.1 增大，给图标更宽裕的垂直空间。
private val BottomBarHeight = 64.dp

// 图标距上下边框 = (64dp 栏高 − 48dp 图标) / 2 = 8dp，左右使用同一留白。
private val BottomBarItemInset = 8.dp

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

    val imagePreviewState = remember { ImagePreviewState() }
    // 底栏背景的高斯模糊来源：被捕获的内容区域。
    val hazeState = remember { HazeState() }

    CompositionLocalProvider(LocalImagePreviewState provides imagePreviewState) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val compactPortrait = maxWidth < 600.dp && maxHeight >= maxWidth
            // A compact, icon-only floating rail keeps more room for content in landscape.
            val panelWidth = 88.dp

            if (compactPortrait) {
                CompactLayout(
                    viewModel = viewModel,
                    state = state,
                    tab = tab,
                    onTab = { tab = it },
                    selectedSubjectId = selectedSubjectId,
                    onSelectSubject = { selectedSubjectId = it },
                    message = message,
                    hazeState = hazeState,
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

        // 全屏图片预览：独立窗口，覆盖列表与各弹窗。
        ImagePreviewOverlay(imagePreviewState)
    }
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
    hazeState: HazeState,
    onOpenAssignment: (Long) -> Unit,
    onEditAssignment: (Long) -> Unit,
    onNewAssignment: () -> Unit,
    onEditTimeBlock: (Long) -> Unit,
    onNewTimeBlock: () -> Unit
) {
    Scaffold(
        containerColor = Color.Transparent,
        bottomBar = {
            Column(Modifier.fillMaxWidth()) {
                // 较 1.6.1 收窄宽度，并用 haze 对栏后内容做高斯模糊 + 半透明底色。
                val hazeBackground = MaterialTheme.colorScheme.background
                val barTint = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.72f)
                Box(
                    Modifier
                        .fillMaxWidth()
                        .padding(start = 28.dp, end = 28.dp, bottom = 12.dp)
                        .clip(PillShape)
                        .hazeEffect(hazeState) {
                            // haze 必须有底色，否则绘制阶段直接抛异常。
                            backgroundColor = hazeBackground
                            blurRadius = 26.dp
                            noiseFactor = 0f
                        }
                        .background(barTint)
                ) {
                    NavigationBar(
                        containerColor = Color.Transparent,
                        tonalElevation = 0.dp,
                        windowInsets = WindowInsets(0.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(BottomBarHeight)
                    ) {
                        // 图标两端对齐，左右留白与上下一致（各 8dp），中间间距由屏宽均分。
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .height(BottomBarHeight)
                                .padding(horizontal = BottomBarItemInset),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
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
                // 手势导航条保留透明区域，避免在底栏下方形成纯色块。
                Spacer(Modifier.navigationBarsPadding())
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
            // 顶部保留安全区；内容从底栏后方穿过，滚动末尾停在底栏上方。
            modifier = Modifier.padding(top = padding.calculateTopPadding()),
            message = message,
            bottomContentPadding = padding.calculateBottomPadding(),
            hazeState = hazeState,
            onOpenAssignment = onOpenAssignment,
            onEditAssignment = onEditAssignment,
            onEditTimeBlock = onEditTimeBlock
        )
    }
}

@Composable
private fun BottomNavigationItem(
    selected: Boolean,
    onClick: () -> Unit,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String
) {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()

    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .background(
                when {
                    selected -> MaterialTheme.colorScheme.primaryContainer
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
                .padding(top = 8.dp, bottom = 8.dp, end = 8.dp)
                .width(panelWidth)
                .fillMaxHeight(),
            shape = PillShape,
            color = MaterialTheme.colorScheme.surfaceContainer,
            tonalElevation = 0.dp
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
            Spacer(Modifier.height(8.dp))
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
                .padding(top = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            AppTab.entries.forEach { item ->
                IconNavigationItem(
                    selected = tab == item,
                    onClick = { onTab(item) },
                    contentDescription = item.title,
                    icon = {
                        Icon(
                            tabIcon(item),
                            contentDescription = null,
                            modifier = Modifier.size(28.dp)
                        )
                    }
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
                        color = subject.colorHex.toComposeColorOrNull()
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
            .size(64.dp)
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
            .size(56.dp)
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
                modifier = Modifier.size(24.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            Box(
                Modifier
                    .size(22.dp)
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
    bottomContentPadding: Dp = 0.dp,
    hazeState: HazeState? = null,
    onOpenAssignment: (Long) -> Unit,
    onEditAssignment: (Long) -> Unit,
    onEditTimeBlock: (Long) -> Unit
) {
    Box(
        modifier
            .fillMaxSize()
            // 底栏高斯模糊采样这片内容；无底栏的大屏布局不附加该层。
            .then(if (hazeState != null) Modifier.hazeSource(hazeState) else Modifier)
    ) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "tab"
        ) { target ->
            when (target) {
                AppTab.DASHBOARD -> DashboardScreen(state, bottomContentPadding)
                AppTab.ASSIGNMENTS -> AssignmentsScreen(
                    viewModel = viewModel,
                    state = state,
                    selectedSubjectId = selectedSubjectId,
                    onSelectSubject = onSelectSubject,
                    onOpen = onOpenAssignment,
                    onEdit = onEditAssignment,
                    bottomContentPadding = bottomContentPadding
                )
                AppTab.SCHEDULE -> ScheduleScreen(
                    viewModel = viewModel,
                    state = state,
                    onEdit = onEditTimeBlock,
                    bottomContentPadding = bottomContentPadding
                )
                AppTab.SUBJECTS -> SubjectsScreen(viewModel, state, bottomContentPadding)
                AppTab.SETTINGS -> SettingsScreen(viewModel, state, bottomContentPadding)
            }
        }

        message?.let {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(
                        bottom = bottomContentPadding + 12.dp,
                        start = 24.dp,
                        end = 24.dp
                    ),
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
