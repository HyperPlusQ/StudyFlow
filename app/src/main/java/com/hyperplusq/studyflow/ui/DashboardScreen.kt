package com.hyperplusq.studyflow.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.EventAvailable
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.HourglassTop
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.domain.DateUtils
import com.hyperplusq.studyflow.domain.ListScope
import com.hyperplusq.studyflow.domain.SmartScoring

@Composable
fun DashboardScreen(
    state: AppUiState,
    bottomContentPadding: Dp = 0.dp
) {
    val active = state.assignments.filter {
        it.assignment.status == AssignmentStatus.ACTIVE.rawValue
    }
    val completed = state.assignments.filter {
        it.assignment.status == AssignmentStatus.COMPLETED.rawValue
    }
    val overdue = active.count { DateUtils.isOverdue(it.assignment.dueDate, false) }
    val dueToday = active.count { DateUtils.isSameDay(it.assignment.dueDate, System.currentTimeMillis()) }
    val withChecklist = active.filter { it.subtasks.isNotEmpty() }
    val checklistRate = if (withChecklist.isEmpty()) 0f
    else withChecklist.map { it.progress }.average().toFloat()
    val completionRate = if (state.assignments.isEmpty()) 0f
    else completed.size.toFloat() / state.assignments.size
    val priority = SmartScoring.sort(active).take(5)
    val todayStart = DateUtils.startOfDay(System.currentTimeMillis())

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 16.dp + bottomContentPadding),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("学习概览", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatCard(
                title = "进行中",
                value = active.size.toString(),
                supporting = "项作业",
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(1f)
            )
            StatCard(
                title = "今日截止",
                value = dueToday.toString(),
                supporting = if (overdue > 0) "$overdue 项已逾期" else "保持节奏",
                color = MaterialTheme.colorScheme.tertiary,
                modifier = Modifier.weight(1f)
            )
        }

        SurfaceCard(title = "完成率", supporting = "所有作业的累计完成进度") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "${(completionRate * 100).toInt()}%",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.width(14.dp))
                LinearProgressIndicator(
                    progress = { completionRate },
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "${completed.size} 项已完成 · ${active.size} 项进行中",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        SurfaceCard(title = "智能关注", supporting = "截止日期、优先级与自定义权重综合排序") {
            if (priority.isEmpty()) {
                EmptyHint(Icons.Outlined.Inbox, "暂无待办作业")
            } else {
                priority.forEachIndexed { index, item ->
                    val subject = state.subjects.firstOrNull { it.id == item.assignment.subjectId }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "${index + 1}",
                            Modifier.width(24.dp),
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold
                        )
                        Column(Modifier.weight(1f)) {
                            Text(
                                item.assignment.title,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1
                            )
                            Text(
                                listOfNotNull(
                                    subject?.name,
                                    DateUtils.dueLabel(item.assignment.dueDate)
                                ).joinToString(" · "),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Text(
                            SmartScoring.score(item).toInt().toString(),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    if (index == priority.lastIndex) Spacer(Modifier.height(2.dp))
                }
            }
        }

        SurfaceCard(title = "子任务进度", supporting = "检查清单平均完成情况") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "${(checklistRate * 100).toInt()}%",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.width(14.dp))
                LinearProgressIndicator(
                    progress = { checklistRate },
                    modifier = Modifier.weight(1f),
                    color = MaterialTheme.colorScheme.secondary
                )
            }
        }

        SurfaceCard(title = "接下来 7 天", supporting = "按日历查看近期截止") {
            val start = todayStart ?: 0L
            val end = start + 7L * 24 * 60 * 60 * 1000
            val nextSeven = active
                .filter {
                    val due = it.assignment.dueDate
                    due != null && due >= start && due <= end
                }
                .sortedBy { it.assignment.dueDate }
            if (nextSeven.isEmpty()) {
                EmptyHint(Icons.Outlined.EventAvailable, "未来一周没有截止作业")
            } else {
                nextSeven.forEach {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Outlined.HourglassTop,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(it.assignment.title, fontWeight = FontWeight.Medium, maxLines = 1)
                            Text(
                                DateUtils.dueLabel(it.assignment.dueDate),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SurfaceCard(
    title: String,
    supporting: String,
    content: @Composable () -> Unit
) {
    androidx.compose.material3.Surface(
        shape = MaterialTheme.shapes.extraLarge,
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f),
        tonalElevation = 2.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(20.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Text(
                supporting,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(14.dp))
            content()
        }
    }
}

@Composable
fun EmptyHint(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.outline)
        Spacer(Modifier.width(12.dp))
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
