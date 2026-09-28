package com.hyperplusq.studyflow.ui

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import com.hyperplusq.studyflow.domain.DateUtils
import java.util.Calendar

@Composable
fun TimeBlockEditorDialog(
    initial: TimeBlockEntity?,
    state: AppUiState,
    onDismiss: () -> Unit,
    onSave: (TimeBlockEntity) -> Unit,
    onDelete: (Long) -> Unit
) {
    val context = LocalContext.current
    var title by remember { mutableStateOf(initial?.title ?: "") }
    var startDate by remember {
        mutableStateOf(initial?.startDate ?: DateUtils.startOfDay(System.currentTimeMillis())!!)
    }
    var duration by remember { mutableStateOf((initial?.durationMinutes ?: 60).toString()) }
    var notes by remember { mutableStateOf(initial?.notes ?: "") }
    var subjectId by remember { mutableStateOf(initial?.subjectId) }
    var assignmentId by remember { mutableStateOf(initial?.assignmentId) }
    var subjectMenu by remember { mutableStateOf(false) }
    var assignmentMenu by remember { mutableStateOf(false) }

    val landscape = isLandscapeDialog()

    AlertDialog(
        onDismissRequest = onDismiss,
        properties = if (landscape) {
            androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)
        } else {
            androidx.compose.ui.window.DialogProperties()
        },
        title = { Text(if (initial == null) "安排时间块" else "编辑时间块") },
        text = {
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                DialogColumns(landscape = landscape, left = {
                    OutlinedTextField(
                        title,
                        { title = it },
                        label = { Text("名称 *") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Text("开始时间", style = MaterialTheme.typography.labelLarge)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = {
                                val calendar = Calendar.getInstance().apply { timeInMillis = startDate }
                                DatePickerDialog(
                                    context,
                                    { _, year, month, day ->
                                        val result = Calendar.getInstance().apply {
                                            timeInMillis = startDate
                                            set(year, month, day)
                                        }
                                        startDate = result.timeInMillis
                                    },
                                    calendar.get(Calendar.YEAR),
                                    calendar.get(Calendar.MONTH),
                                    calendar.get(Calendar.DAY_OF_MONTH)
                                ).show()
                            },
                            modifier = Modifier.weight(1f)
                        ) { Text(DateUtils.localDate(startDate)?.toString() ?: "日期") }

                        OutlinedButton(onClick = {
                            val calendar = Calendar.getInstance().apply { timeInMillis = startDate }
                            TimePickerDialog(
                                context,
                                { _, hour, minute ->
                                    val result = Calendar.getInstance().apply {
                                        timeInMillis = startDate
                                        set(Calendar.HOUR_OF_DAY, hour)
                                        set(Calendar.MINUTE, minute)
                                        set(Calendar.SECOND, 0)
                                        set(Calendar.MILLISECOND, 0)
                                    }
                                    startDate = result.timeInMillis
                                },
                                calendar.get(Calendar.HOUR_OF_DAY),
                                calendar.get(Calendar.MINUTE),
                                true
                            ).show()
                        }) { Text("时刻") }
                    }

                    OutlinedTextField(
                        duration,
                        {
                            duration = it.filter(Char::isDigit).take(4)
                        },
                        label = { Text("时长（分钟）") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }, right = {
                    Text("科目", style = MaterialTheme.typography.labelLarge)
                    DropdownSelector(
                        text = state.subjects.firstOrNull { it.id == subjectId }?.name ?: "不关联",
                        expanded = subjectMenu,
                        onExpandedChange = { subjectMenu = it }
                    ) {
                        DropdownMenuItem(
                            text = { Text("不关联") },
                            onClick = { subjectId = null; subjectMenu = false }
                        )
                        state.subjects.forEach {
                            DropdownMenuItem(
                                text = { Text(it.name) },
                                onClick = { subjectId = it.id; subjectMenu = false }
                            )
                        }
                    }

                    Text("关联作业", style = MaterialTheme.typography.labelLarge)
                    DropdownSelector(
                        text = state.assignments.firstOrNull { it.assignment.id == assignmentId }
                            ?.assignment?.title ?: "不关联",
                        expanded = assignmentMenu,
                        onExpandedChange = { assignmentMenu = it }
                    ) {
                        DropdownMenuItem(
                            text = { Text("不关联") },
                            onClick = { assignmentId = null; assignmentMenu = false }
                        )
                        state.assignments.forEach {
                            DropdownMenuItem(
                                text = { Text(it.assignment.title, maxLines = 1) },
                                onClick = { assignmentId = it.assignment.id; assignmentMenu = false }
                            )
                        }
                    }

                    OutlinedTextField(
                        notes,
                        { notes = it },
                        label = { Text("备注") },
                        minLines = 3,
                        modifier = Modifier.fillMaxWidth()
                    )

                    if (initial != null) {
                        TextButton(
                            onClick = { onDelete(initial.id); onDismiss() },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("删除时间块", color = MaterialTheme.colorScheme.error) }
                    }
                })
            }
        },
        confirmButton = {
            Button(
                enabled = title.isNotBlank() && duration.toIntOrNull()?.let { it > 0 } == true,
                onClick = {
                    onSave(
                        (initial ?: TimeBlockEntity(title = title, startDate = startDate)).copy(
                            title = title.trim(),
                            startDate = startDate,
                            durationMinutes = duration.toInt(),
                            notes = notes.trim(),
                            subjectId = subjectId,
                            assignmentId = assignmentId
                        )
                    )
                    onDismiss()
                }
            ) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

@Composable
private fun DropdownSelector(
    text: String,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    content: @Composable () -> Unit
) {
    androidx.compose.material3.OutlinedButton(
        onClick = { onExpandedChange(true) },
        modifier = Modifier.fillMaxWidth()
    ) { Text(text) }
    DropdownMenu(expanded = expanded, onDismissRequest = { onExpandedChange(false) }) {
        content()
    }
}
