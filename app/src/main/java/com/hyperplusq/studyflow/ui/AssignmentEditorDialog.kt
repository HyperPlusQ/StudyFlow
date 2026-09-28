package com.hyperplusq.studyflow.ui

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import com.hyperplusq.studyflow.data.db.Priority
import com.hyperplusq.studyflow.domain.DateUtils
import com.hyperplusq.studyflow.system.SubmissionKind
import com.hyperplusq.studyflow.system.SubmissionLink
import java.util.Calendar

@Composable
fun AssignmentEditorDialog(
    initial: AssignmentWithSubtasks?,
    state: AppUiState,
    onDismiss: () -> Unit,
    onSave: (AssignmentEntity) -> Unit
) {
    val current = initial?.assignment
    var title by remember { mutableStateOf(current?.title ?: "") }
    var details by remember { mutableStateOf(current?.details ?: "") }
    var subjectId by remember { mutableStateOf(current?.subjectId) }
    var dueDate by remember { mutableStateOf(current?.dueDate) }
    var submission by remember { mutableStateOf(current?.submissionMethod ?: "") }
    var priority by remember { mutableStateOf(Priority.fromRaw(current?.priority ?: Priority.MEDIUM.rawValue)) }
    var weight by remember { mutableStateOf((current?.weight ?: 3).toFloat()) }
    var reminderHours by remember { mutableStateOf(current?.reminderLeadHours ?: 24) }
    var subjectMenu by remember { mutableStateOf(false) }
    var priorityMenu by remember { mutableStateOf(false) }
    var reminderMenu by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val suggestions = state.submissionHistory
        .filter { subjectId == null || it.subjectId == subjectId }
        .map { it.method }
        .distinct()

    val landscape = isLandscapeDialog()

    AlertDialog(
        onDismissRequest = onDismiss,
        properties = if (landscape) {
            androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
        } else {
            androidx.compose.ui.window.DialogProperties()
        },
        title = {
            Text(if (initial == null) "新建作业" else "编辑作业")
        },
        text = {
            Column(
                Modifier
                    .fillMaxWidth()
                    .height(560.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                DialogColumns(landscape = landscape, left = {
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = { Text("标题 *") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = details,
                        onValueChange = { details = it },
                        label = { Text("详细内容") },
                        minLines = 3,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Text("科目", style = MaterialTheme.typography.labelLarge)
                    DropdownButton(
                        text = state.subjects.firstOrNull { it.id == subjectId }?.name ?: "未分类",
                        expanded = subjectMenu,
                        onExpanded = { subjectMenu = it }
                    ) {
                        DropdownMenuItem(
                            text = { Text("未分类") },
                            onClick = { subjectId = null; subjectMenu = false }
                        )
                        state.subjects.forEach { subject ->
                            DropdownMenuItem(
                                text = { Text(subject.name) },
                                onClick = { subjectId = subject.id; subjectMenu = false }
                            )
                        }
                    }

                    Text("截止日期", style = MaterialTheme.typography.labelLarge)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = {
                                val calendar = Calendar.getInstance().apply {
                                    dueDate?.let { timeInMillis = it }
                                }
                                DatePickerDialog(
                                    context,
                                    { _, year, month, day ->
                                        val selected = Calendar.getInstance().apply {
                                            set(year, month, day)
                                            if (dueDate == null) set(Calendar.HOUR_OF_DAY, 18)
                                        }
                                        dueDate = selected.timeInMillis
                                    },
                                    calendar.get(Calendar.YEAR),
                                    calendar.get(Calendar.MONTH),
                                    calendar.get(Calendar.DAY_OF_MONTH)
                                ).show()
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(DateUtils.localDate(dueDate)?.toString() ?: "选择日期")
                        }
                        if (dueDate != null) {
                            OutlinedButton(
                                onClick = {
                                    val calendar = Calendar.getInstance().apply { timeInMillis = dueDate!! }
                                    TimePickerDialog(
                                        context,
                                        { _, hour, minute ->
                                            val selected = Calendar.getInstance().apply {
                                                timeInMillis = dueDate!!
                                                set(Calendar.HOUR_OF_DAY, hour)
                                                set(Calendar.MINUTE, minute)
                                                set(Calendar.SECOND, 0)
                                                set(Calendar.MILLISECOND, 0)
                                            }
                                            dueDate = selected.timeInMillis
                                        },
                                        calendar.get(Calendar.HOUR_OF_DAY),
                                        calendar.get(Calendar.MINUTE),
                                        true
                                    ).show()
                                }
                            ) { Text("时间") }
                            TextButton(onClick = { dueDate = null }) { Text("清除") }
                        }
                    }
                }, right = {
                    Text("提交渠道 / 方式", style = MaterialTheme.typography.labelLarge)
                    OutlinedTextField(
                        value = submission,
                        onValueChange = { submission = it },
                        label = { Text("网址、邮箱或文字说明") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    if (suggestions.isNotEmpty()) {
                        Text(
                            "本科目历史记录",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(7.dp)
                        ) {
                            suggestions.forEach { suggestion ->
                                val kind = SubmissionLink.classify(suggestion)
                                val label = when (kind) {
                                    SubmissionKind.URL -> "网页"
                                    SubmissionKind.EMAIL -> "邮件"
                                    SubmissionKind.OTHER -> "文本"
                                }
                                FilterChip(
                                    selected = submission == suggestion,
                                    onClick = { submission = suggestion },
                                    label = { Text("$label · $suggestion", maxLines = 1) }
                                )
                            }
                        }
                    }

                    Text("优先级", style = MaterialTheme.typography.labelLarge)
                    DropdownButton(priority.label, priorityMenu, { priorityMenu = it }) {
                        Priority.entries.forEach {
                            DropdownMenuItem(
                                text = { Text(it.label) },
                                onClick = { priority = it; priorityMenu = false }
                            )
                        }
                    }

                    Text("自定义权重：${weight.toInt()}", style = MaterialTheme.typography.labelLarge)
                    Slider(
                        value = weight,
                        onValueChange = { weight = it },
                        valueRange = 1f..10f,
                        steps = 8
                    )

                    Text("提前提醒", style = MaterialTheme.typography.labelLarge)
                    DropdownButton(reminderLabel(reminderHours), reminderMenu, { reminderMenu = it }) {
                        listOf(1, 6, 12, 24, 48, 72).forEach { hours ->
                            DropdownMenuItem(
                                text = { Text(reminderLabel(hours)) },
                                onClick = { reminderHours = hours; reminderMenu = false }
                            )
                        }
                    }
                })
            }
        },
        confirmButton = {
            Button(
                enabled = title.isNotBlank(),
                onClick = {
                    onSave(
                        (current ?: AssignmentEntity(title = title)).copy(
                            title = title.trim(),
                            details = details.trim(),
                            dueDate = dueDate,
                            submissionMethod = submission.trim(),
                            subjectId = subjectId,
                            priority = priority.rawValue,
                            weight = weight.toInt(),
                            reminderLeadHours = reminderHours
                        )
                    )
                }
            ) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

@Composable
private fun DropdownButton(
    text: String,
    expanded: Boolean,
    onExpanded: (Boolean) -> Unit,
    menu: @Composable () -> Unit
) {
    Row {
        OutlinedButton(onClick = { onExpanded(true) }, modifier = Modifier.fillMaxWidth()) {
            Text(text)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { onExpanded(false) }) {
            menu()
        }
    }
}

private fun reminderLabel(hours: Int): String = when (hours) {
    1 -> "提前 1 小时"
    6 -> "提前 6 小时"
    12 -> "提前 12 小时"
    24 -> "提前 1 天"
    48 -> "提前 2 天"
    72 -> "提前 3 天"
    else -> "提前 $hours 小时"
}

