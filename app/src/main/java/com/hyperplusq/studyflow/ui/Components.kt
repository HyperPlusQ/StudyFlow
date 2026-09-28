package com.hyperplusq.studyflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import com.hyperplusq.studyflow.data.db.SubjectEntity
import com.hyperplusq.studyflow.domain.DateUtils
import com.hyperplusq.studyflow.domain.SmartScoring

@Composable
fun SubjectDot(subject: SubjectEntity?, modifier: Modifier = Modifier) {
    val color = subject?.colorHex?.toComposeColorOrNull() ?: MaterialTheme.colorScheme.primary
    Box(
        modifier
            .size(12.dp)
            .background(color, CircleShape)
    )
}

fun String.toComposeColorOrNull(): Color? =
    try {
        val clean = removePrefix("#")
        val value = clean.toLong(16)
        val argb = if (clean.length == 6) 0xFF000000 or value else value
        Color(argb)
    } catch (_: Exception) {
        null
    }

@Composable
fun AssignmentCard(
    item: AssignmentWithSubtasks,
    subjects: List<SubjectEntity>,
    onClick: () -> Unit,
    onToggleComplete: (Boolean) -> Unit,
    onOpenSubmission: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val assignment = item.assignment
    val subject = subjects.firstOrNull { it.id == assignment.subjectId }
    val completed = assignment.status == AssignmentStatus.COMPLETED.rawValue
    val score = SmartScoring.score(item).toInt()
    val overdue = DateUtils.isOverdue(assignment.dueDate, completed)

    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { onToggleComplete(!completed) }) {
                Icon(
                    if (completed) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                    contentDescription = if (completed) "恢复作业" else "完成作业",
                    tint = if (completed) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.outline
                )
            }

            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SubjectDot(subject)
                    Spacer(Modifier.width(7.dp))
                    Text(
                        subject?.name ?: "未分类",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (score > 0 && !completed) {
                        Spacer(Modifier.width(8.dp))
                        AssistChip(
                            onClick = onClick,
                            label = { Text("关注 $score") },
                            modifier = Modifier.height(28.dp)
                        )
                    }
                }
                Text(
                    assignment.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    textDecoration = if (completed) TextDecoration.LineThrough else null
                )
                if (assignment.details.isNotBlank()) {
                    Text(
                        assignment.details,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        DateUtils.dueLabel(assignment.dueDate),
                        style = MaterialTheme.typography.labelLarge,
                        color = if (overdue) MaterialTheme.colorScheme.error
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (assignment.submissionMethod.isNotBlank()) {
                        Spacer(Modifier.width(10.dp))
                        Surface(
                            onClick = { onOpenSubmission?.invoke() },
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.secondaryContainer
                        ) {
                            Text(
                                "打开提交方式",
                                Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                        }
                    }
                }
                if (item.subtasks.isNotEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    LinearProgressIndicator(
                        progress = { item.progress },
                        modifier = Modifier.fillMaxWidth(),
                        strokeCap = androidx.compose.ui.graphics.StrokeCap.Round
                    )
                    Spacer(Modifier.height(5.dp))
                    Text(
                        "${item.completedSubtaskCount}/${item.subtasks.size} 子任务",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
fun StatCard(
    title: String,
    value: String,
    supporting: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier,
        shape = RoundedCornerShape(28.dp),
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f),
        tonalElevation = 2.dp
    ) {
        Column(Modifier.padding(18.dp)) {
            Box(
                Modifier
                    .size(34.dp)
                    .background(color.copy(alpha = 0.18f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Box(Modifier.size(12.dp).background(color, CircleShape))
            }
            Spacer(Modifier.height(12.dp))
            Text(value, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(
                supporting,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
