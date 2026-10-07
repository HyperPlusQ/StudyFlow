package com.hyperplusq.studyflow.ui

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import com.hyperplusq.studyflow.data.db.Priority
import com.hyperplusq.studyflow.data.db.SubtaskEntity
import com.hyperplusq.studyflow.domain.DateUtils
import com.hyperplusq.studyflow.system.SubmissionLink

@Composable
fun AssignmentDetailDialog(
    item: AssignmentWithSubtasks,
    state: AppUiState,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onToggleComplete: (Boolean) -> Unit,
    onSaveSubtask: (SubtaskEntity) -> Unit,
    onDeleteSubtask: (Long) -> Unit,
    onToggleSubtask: (SubtaskEntity, Boolean) -> Unit,
    onCancelCalendarSync: () -> Unit
) {
    val context = LocalContext.current
    val assignment = item.assignment
    val subject = state.subjects.firstOrNull { it.id == assignment.subjectId }
    val completed = assignment.status == AssignmentStatus.COMPLETED.rawValue
    var newSubtask by remember { mutableStateOf("") }
    var confirmDelete by remember { mutableStateOf(false) }
    val landscape = isLandscapeDialog()

    AlertDialog(
        onDismissRequest = onDismiss,
        properties = if (landscape) {
            androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
        } else {
            androidx.compose.ui.window.DialogProperties()
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(assignment.title, fontWeight = FontWeight.Bold)
                    Text(
                        subject?.name ?: "未分类",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onEdit) {
                    Icon(Icons.Outlined.Edit, "编辑")
                }
                IconButton(onClick = { confirmDelete = true }) {
                    Icon(Icons.Outlined.Delete, "删除", tint = MaterialTheme.colorScheme.error)
                }
            }
        },
        text = {
            Column(
                Modifier
                    .fillMaxWidth()
                    .height(590.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(13.dp)
            ) {
                DialogColumns(landscape = landscape, left = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        onClick = { onToggleComplete(!completed) },
                        shape = RoundedCornerShape(18.dp),
                        color = if (completed) MaterialTheme.colorScheme.secondaryContainer
                        else MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Row(Modifier.padding(horizontal = 14.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                if (completed) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                                null,
                                Modifier.width(20.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(if (completed) "已完成" else "标记完成", fontWeight = FontWeight.SemiBold)
                        }
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "关注分 ${com.hyperplusq.studyflow.domain.SmartScoring.score(item).toInt()}",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                InfoRow("截止日期", DateUtils.dueLabel(assignment.dueDate))
                InfoRow("优先级", Priority.fromRaw(assignment.priority).label + " · 权重 ${assignment.weight}")
                InfoRow("提醒", "截止前 ${assignment.reminderLeadHours} 小时")

                if (assignment.details.isNotBlank()) {
                    Column {
                        Text("详细内容", style = MaterialTheme.typography.labelLarge)
                        Text(assignment.details, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                if (assignment.submissionMethod.isNotBlank()) {
                    Column {
                        Text("提交方式", style = MaterialTheme.typography.labelLarge)
                        Surface(
                            onClick = {
                                if (!SubmissionLink.open(context, assignment.submissionMethod)) {
                                    // The caller surfaces a message elsewhere; the value remains copyable below.
                                }
                            },
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.secondaryContainer
                        ) {
                            Row(
                                Modifier.fillMaxWidth().padding(13.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Outlined.Link,
                                    null,
                                    tint = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                                Spacer(Modifier.width(11.dp))
                                Text(
                                    assignment.submissionMethod,
                                    Modifier.weight(1f),
                                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                                    maxLines = 3
                                )
                                Text(
                                    when (SubmissionLink.classify(assignment.submissionMethod)) {
                                        com.hyperplusq.studyflow.system.SubmissionKind.URL -> "浏览器"
                                        com.hyperplusq.studyflow.system.SubmissionKind.EMAIL -> "邮件"
                                        com.hyperplusq.studyflow.system.SubmissionKind.OTHER -> "复制"
                                    },
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }

                if (assignment.calendarEventId != null) {
                    OutlinedButton(
                        onClick = {
                            onCancelCalendarSync()
                            onDismiss()
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Outlined.CalendarMonth, null, Modifier.width(19.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("取消日历同步")
                    }
                }

                }, right = {
                if (item.attachments.isNotEmpty()) {
                    Text("图片附件", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    AttachmentStrip(
                        attachments = item.attachments,
                        maxVisible = item.attachments.size,
                        tileSize = 76.dp
                    )
                }
                HorizontalDivider()
                Text("检查清单", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                if (item.subtasks.isEmpty()) {
                    Text(
                        "把大作业拆分成可追踪的小步骤",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                item.subtasks.sortedWith(compareBy({ it.sortOrder }, { it.id })).forEach { subtask ->
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = { onToggleSubtask(subtask, !subtask.isCompleted) }) {
                            Icon(
                                if (subtask.isCompleted) Icons.Outlined.CheckCircle
                                else Icons.Outlined.RadioButtonUnchecked,
                                "切换子任务",
                                tint = if (subtask.isCompleted) MaterialTheme.colorScheme.secondary
                                else MaterialTheme.colorScheme.outline
                            )
                        }
                        Text(
                            subtask.title,
                            Modifier.weight(1f),
                            color = if (subtask.isCompleted) MaterialTheme.colorScheme.onSurfaceVariant
                            else MaterialTheme.colorScheme.onSurface
                        )
                        IconButton(onClick = { onDeleteSubtask(subtask.id) }) {
                            Icon(Icons.Outlined.Delete, "删除子任务")
                        }
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = newSubtask,
                        onValueChange = { newSubtask = it },
                        placeholder = { Text("新的子任务") },
                        singleLine = true,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(
                        enabled = newSubtask.isNotBlank(),
                        onClick = {
                            onSaveSubtask(
                                SubtaskEntity(
                                    assignmentId = assignment.id,
                                    title = newSubtask.trim(),
                                    sortOrder = item.subtasks.size
                                )
                            )
                            newSubtask = ""
                        }
                    ) { Icon(Icons.Outlined.Add, "添加子任务") }
                }
                })
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("关闭") }
        },
        dismissButton = {
            if (assignment.calendarEventId == null) {
                TextButton(onClick = onEdit) { Text("编辑") }
            }
        }
    )

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("删除作业？") },
            text = { Text("子任务与日历事件将一并删除，此操作不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    onDelete()
                    onDismiss()
                }) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("取消") }
            }
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            Modifier.width(84.dp),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(value, Modifier.weight(1f), fontWeight = FontWeight.Medium)
    }
}
