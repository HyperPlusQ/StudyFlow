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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.domain.AssignmentFilter
import com.hyperplusq.studyflow.domain.AssignmentQueries
import com.hyperplusq.studyflow.domain.DueWindow
import com.hyperplusq.studyflow.domain.ListScope
import com.hyperplusq.studyflow.domain.SmartScoring
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.Priority

@Composable
fun AssignmentsScreen(
    viewModel: AppViewModel,
    state: AppUiState,
    selectedSubjectId: Long?,
    onSelectSubject: (Long?) -> Unit,
    onOpen: (Long) -> Unit,
    onEdit: (Long) -> Unit
) {
    var filter by remember { mutableStateOf(AssignmentFilter()) }
    var scope by remember { mutableStateOf(ListScope.ALL) }
    var showFilters by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val effectiveFilter = filter.copy(subjectId = selectedSubjectId)
    val items = SmartScoring.sort(
        state.assignments.filter { AssignmentQueries.matches(it, effectiveFilter, scope) }
    )

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "作业",
                Modifier.weight(1f),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = { showFilters = !showFilters }) {
                Icon(Icons.Outlined.FilterList, "筛选")
            }
            if (!effectiveFilter.isDefault) {
                TextButton(onClick = {
                    filter = AssignmentFilter()
                    onSelectSubject(null)
                }) {
                    Text("清除")
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = filter.searchText,
            onValueChange = { filter = filter.copy(searchText = it) },
            modifier = Modifier.fillMaxWidth(),
            leadingIcon = { Icon(Icons.Outlined.Search, null) },
            trailingIcon = {
                if (filter.searchText.isNotEmpty()) {
                    IconButton(onClick = { filter = filter.copy(searchText = "") }) {
                        Icon(Icons.Outlined.Close, "清除搜索")
                    }
                }
            },
            singleLine = true,
            shape = MaterialTheme.shapes.extraLarge
        )

        Spacer(Modifier.height(12.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ListScope.entries.filter { it != ListScope.DASHBOARD }.forEach {
                FilterChip(
                    selected = scope == it,
                    onClick = { scope = it },
                    label = { Text(it.title) }
                )
            }
        }

        if (showFilters) {
            Spacer(Modifier.height(12.dp))
            Surface(
                shape = MaterialTheme.shapes.extraLarge,
                color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.96f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text("科目", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FilterChip(
                            selected = selectedSubjectId == null,
                            onClick = { onSelectSubject(null) },
                            label = { Text("全部") }
                        )
                        state.subjects.forEach { subject ->
                            FilterChip(
                                selected = selectedSubjectId == subject.id,
                                onClick = { onSelectSubject(subject.id) },
                                label = { Text(subject.name) }
                            )
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    Text("截止日期", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        DueWindow.entries.forEach {
                            FilterChip(
                                selected = filter.dueWindow == it,
                                onClick = { filter = filter.copy(dueWindow = it) },
                                label = { Text(it.title) }
                            )
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    PriorityFilter(filter.priority) {
                        filter = filter.copy(priority = it)
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            checked = filter.hasChecklistOnly,
                            onCheckedChange = { filter = filter.copy(hasChecklistOnly = it) }
                        )
                        Text("仅显示带检查清单的作业")
                    }
                }
            }
        }

        Spacer(Modifier.height(14.dp))
        if (items.isEmpty()) {
            Surface(
                shape = MaterialTheme.shapes.extraLarge,
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(vertical = 34.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("没有符合条件的作业", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "可调整筛选条件，或新建一项作业",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items.forEach { item ->
                    AssignmentCard(
                        item = item,
                        subjects = state.subjects,
                        onClick = { onOpen(item.assignment.id) },
                        onToggleComplete = { viewModel.setAssignmentCompleted(item.assignment.id, it) },
                        onOpenSubmission = {
                            com.hyperplusq.studyflow.system.SubmissionLink.open(
                                context,
                                item.assignment.submissionMethod
                            )
                        }
                    )
                }
            }
        }
        Spacer(Modifier.height(96.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PriorityFilter(selected: Priority?, onChange: (Priority?) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = selected?.label ?: "全部优先级",
            onValueChange = {},
            readOnly = true,
            label = { Text("优先级") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(androidx.compose.material3.ExposedDropdownMenuAnchorType.PrimaryNotEditable),
            shape = MaterialTheme.shapes.large
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text("全部优先级") },
                onClick = { onChange(null); expanded = false }
            )
            Priority.entries.forEach { priority ->
                DropdownMenuItem(
                    text = { Text(priority.label) },
                    onClick = { onChange(priority); expanded = false }
                )
            }
        }
    }
    Spacer(Modifier.height(12.dp))
}
