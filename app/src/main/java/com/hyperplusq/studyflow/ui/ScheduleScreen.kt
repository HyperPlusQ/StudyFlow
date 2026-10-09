package com.hyperplusq.studyflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import com.hyperplusq.studyflow.domain.DateUtils
import java.time.Instant
import java.time.ZoneId

@Composable
fun ScheduleScreen(
    viewModel: AppViewModel,
    state: AppUiState,
    onEdit: (Long) -> Unit,
    bottomContentPadding: Dp = 0.dp
) {
    val grouped = state.timeBlocks.groupBy {
        DateUtils.localDate(it.startDate)?.atStartOfDay(ZoneId.systemDefault())?.toInstant()?.toEpochMilli()
            ?: 0L
    }.toSortedMap()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 16.dp + bottomContentPadding),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("学习日程", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)

        if (grouped.isEmpty()) {
            Surface(
                shape = MaterialTheme.shapes.extraLarge,
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    Modifier.padding(vertical = 44.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Outlined.CalendarMonth,
                        null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("还没有时间块", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "点击右下角按钮开始安排学习时间",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        grouped.forEach { (day, blocks) ->
            Column {
                Text(
                    DateUtils.dueLabel(day).substringBefore(" "),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    blocks.forEach { block -> TimeBlockRow(block, state, onEdit, viewModel) }
                }
            }
        }
        Spacer(Modifier.height(96.dp))
    }
}

@Composable
private fun TimeBlockRow(
    block: TimeBlockEntity,
    state: AppUiState,
    onEdit: (Long) -> Unit,
    viewModel: AppViewModel
) {
    val zone = ZoneId.systemDefault()
    val start = Instant.ofEpochMilli(block.startDate).atZone(zone)
    val end = start.plusMinutes(block.durationMinutes.toLong())
    val subject = state.subjects.firstOrNull { it.id == block.subjectId }
    val assignment = state.assignments.firstOrNull { it.assignment.id == block.assignmentId }?.assignment

    Surface(
        onClick = { onEdit(block.id) },
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.95f),
        tonalElevation = 2.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .width(4.dp)
                    .height(56.dp)
                    .background(subject?.colorHex?.toComposeColorOrNull()
                        ?: MaterialTheme.colorScheme.primary, CircleShape)
            )
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(block.title, fontWeight = FontWeight.SemiBold, maxLines = 2)
                Text(
                    "${start.hour.toString().padStart(2, '0')}:${start.minute.toString().padStart(2, '0')}–" +
                        "${end.hour.toString().padStart(2, '0')}:${end.minute.toString().padStart(2, '0')}" +
                        (subject?.let { " · ${it.name}" } ?: ""),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (assignment != null) {
                    Text(
                        "关联：${assignment.title}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1
                    )
                }
                if (block.notes.isNotBlank()) {
                    Text(
                        block.notes,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2
                    )
                }
            }
            Text(
                "${block.durationMinutes} 分钟",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.secondary
            )
            IconButton(onClick = { viewModel.deleteTimeBlock(block.id) }) {
                Icon(Icons.Outlined.Delete, "删除时间块", tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}
