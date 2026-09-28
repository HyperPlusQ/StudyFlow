package com.hyperplusq.studyflow.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.LinkOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.SubjectEntity

private val subjectColors = listOf(
    "#4F6BED", "#006C5A", "#B54708", "#9E1B32", "#6941C6",
    "#026AA7", "#067647", "#B42318", "#7A5AF8", "#4E5BA6"
)

@Composable
fun SubjectsScreen(viewModel: AppViewModel, state: AppUiState) {
    var editing by remember { mutableStateOf<SubjectEntity?>(null) }
    var editorOpen by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<SubjectEntity?>(null) }
    var historySubjectId by remember { mutableStateOf<Long?>(null) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "科目",
                Modifier.weight(1f),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
            FilledTonalButton(onClick = {
                editing = null
                editorOpen = true
            }) {
                Icon(Icons.Outlined.Add, null, Modifier.size(18.dp))
                Spacer(Modifier.width(7.dp))
                Text("新建科目")
            }
        }

        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column {
                if (state.subjects.isEmpty()) {
                    Column(
                        Modifier.fillMaxWidth().padding(vertical = 38.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("还没有科目", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "先创建一个大类，再添加子科目",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    orderedSubjects(state.subjects).forEach { pair ->
                        val subject = pair.first
                        val depth = pair.second
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(start = (14 + depth * 24).dp, end = 6.dp, top = 7.dp, bottom = 7.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            BoxColor(subject.colorHex)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(subject.name, fontWeight = FontWeight.SemiBold)
                                Text(
                                    subject.symbol.ifBlank { "自定义符号" } +
                                        (if (subject.parentId != null) " · 子科目" else " · 大类"),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            IconButton(onClick = {
                                editing = subject
                                editorOpen = true
                            }) {
                                Icon(Icons.Outlined.Edit, "编辑 ${subject.name}")
                            }
                            IconButton(onClick = { deleting = subject }) {
                                Icon(
                                    Icons.Outlined.Delete,
                                    "删除 ${subject.name}",
                                    tint = MaterialTheme.colorScheme.error
                                )
                            }
                        }
                    }
                }
            }
        }

        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(Modifier.padding(18.dp)) {
                Text("提交方式记录", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    "保存每个科目曾经输入的网址或邮箱，可随时删除",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(12.dp))

                if (state.subjects.isNotEmpty()) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FilterChip(
                            selected = historySubjectId == null,
                            onClick = { historySubjectId = null },
                            label = { Text("全部科目") }
                        )
                        state.subjects.forEach { subject ->
                            FilterChip(
                                selected = historySubjectId == subject.id,
                                onClick = { historySubjectId = subject.id },
                                label = { Text(subject.name) }
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                }

                val entries = state.submissionHistory.filter {
                    historySubjectId == null || it.subjectId == historySubjectId
                }
                if (entries.isEmpty()) {
                    Text(
                        "暂无记录",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 14.dp)
                    )
                } else {
                    entries.forEach { entry ->
                        val subject = state.subjects.firstOrNull { it.id == entry.subjectId }
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 7.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            BoxColor(subject?.colorHex)
                            Spacer(Modifier.width(11.dp))
                            Column(Modifier.weight(1f)) {
                                Text(entry.method, maxLines = 2)
                                Text(
                                    subject?.name ?: "已删除科目",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            IconButton(onClick = { viewModel.deleteSubmissionHistory(entry.id) }) {
                                Icon(Icons.Outlined.LinkOff, "删除记录", tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
        }
    }

    if (editorOpen) {
        SubjectEditorDialog(
            initial = editing,
            subjects = state.subjects,
            onDismiss = { editorOpen = false },
            onSave = {
                viewModel.saveSubject(it)
                editorOpen = false
            }
        )
    }

    deleting?.let { subject ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text("删除科目？") },
            text = {
                Text("将删除“${subject.name}”，其子科目会提升一级，关联作业与时间块会变为未分类。")
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteSubject(subject)
                    deleting = null
                }) {
                    Text("删除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) { Text("取消") }
            }
        )
    }
}

@Composable
private fun BoxColor(hex: String?) {
    val color = hex?.toComposeColorOrNull() ?: MaterialTheme.colorScheme.primary
    Surface(
        shape = CircleShape,
        color = color,
        modifier = Modifier.size(14.dp)
    ) {}
}

@Composable
private fun SubjectEditorDialog(
    initial: SubjectEntity?,
    subjects: List<SubjectEntity>,
    onDismiss: () -> Unit,
    onSave: (SubjectEntity) -> Unit
) {
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var symbol by remember { mutableStateOf(initial?.symbol ?: "menu_book") }
    var color by remember { mutableStateOf(initial?.colorHex ?: subjectColors.first()) }
    var parentId by remember { mutableStateOf(initial?.parentId) }
    var parentMenu by remember { mutableStateOf(false) }
    val parent = subjects.firstOrNull { it.id == parentId }
    val landscape = isLandscapeDialog()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "新建科目" else "编辑科目") },
        properties = if (landscape) {
            androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
        } else {
            androidx.compose.ui.window.DialogProperties()
        },
        text = {
            DialogColumns(landscape = landscape, left = {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("科目名称") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = symbol,
                    onValueChange = { symbol = it },
                    label = { Text("符号（仅作标记）") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Text("层级", style = MaterialTheme.typography.labelLarge)
                OutlinedButton(
                    onClick = { parentMenu = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(parent?.name ?: "顶级大类")
                }
                DropdownMenu(expanded = parentMenu, onDismissRequest = { parentMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("顶级大类") },
                        onClick = { parentId = null; parentMenu = false }
                    )
                    subjects.filter { it.id != initial?.id && !isAncestor(it, initial, subjects) }.forEach {
                        DropdownMenuItem(
                            text = { Text("子级：${it.name}") },
                            onClick = { parentId = it.id; parentMenu = false }
                        )
                    }
                }
            }, right = {
                Text("颜色", style = MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    subjectColors.take(8).forEach { value ->
                        val selected = value == color
                        Surface(
                            onClick = { color = value },
                            shape = CircleShape,
                            color = value.toComposeColorOrNull() ?: MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(if (selected) 38.dp else 32.dp),
                            border = if (selected) androidx.compose.foundation.BorderStroke(
                                3.dp,
                                MaterialTheme.colorScheme.onSurface
                            ) else null
                        ) {}
                    }
                }
            })
        },
        confirmButton = {
            Button(
                enabled = name.isNotBlank(),
                onClick = {
                    onSave(
                        (initial ?: SubjectEntity(name = name)).copy(
                            name = name.trim(),
                            symbol = symbol.trim().ifBlank { "menu_book" },
                            colorHex = color,
                            parentId = parentId,
                            sortOrder = initial?.sortOrder ?: subjects.size
                        )
                    )
                }
            ) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

private fun isAncestor(candidate: SubjectEntity, root: SubjectEntity?, subjects: List<SubjectEntity>): Boolean {
    if (root == null) return false
    val byId = subjects.associateBy { it.id }
    val seen = mutableSetOf<Long>()
    var cursor: Long? = candidate.id
    while (cursor != null && cursor !in seen) {
        if (cursor == root.id) return true
        seen += cursor
        cursor = byId[cursor]?.parentId
    }
    return false
}

private fun orderedSubjects(subjects: List<SubjectEntity>): List<Pair<SubjectEntity, Int>> {
    val result = mutableListOf<Pair<SubjectEntity, Int>>()
    val roots = subjects.filter { s -> subjects.none { it.id == s.parentId } }
    fun visit(parent: SubjectEntity?, depth: Int) {
        subjects.filter { it.parentId == parent?.id }.sortedWith(compareBy({ it.sortOrder }, { it.createdAt })).forEach {
            result += it to depth
            visit(it, depth + 1)
        }
    }
    roots.sortedWith(compareBy({ it.sortOrder }, { it.createdAt })).forEach {
        result += it to 0
        visit(it, 1)
    }
    // Include orphaned references safely.
    subjects.filter { s -> result.none { it.first.id == s.id } }.forEach { result += it to 0 }
    return result
}
