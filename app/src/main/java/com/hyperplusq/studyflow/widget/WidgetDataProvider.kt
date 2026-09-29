package com.hyperplusq.studyflow.widget

import android.content.Context
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AppDatabase
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.domain.DateUtils
import com.hyperplusq.studyflow.domain.SmartScoring
import kotlinx.coroutines.runBlocking

internal data class WidgetSnapshot(
    val activeCount: Int,
    val dueTodayCount: Int,
    val overdueCount: Int,
    val items: List<WidgetItem>
)

internal data class WidgetItem(
    val title: String,
    val subtitle: String
)

internal object WidgetDataProvider {
    fun load(context: Context): WidgetSnapshot {
        val repository = StudyRepository(AppDatabase.get(context))
        return runBlocking {
            val assignments = repository.assignmentsOnce()
            val subjects = repository.subjectsOnce().associateBy { it.id }
            val now = System.currentTimeMillis()
            val active = SmartScoring.sort(
                assignments.filter { it.assignment.status == AssignmentStatus.ACTIVE.rawValue },
                now
            )
            val dueToday = active.count { DateUtils.isSameDay(it.assignment.dueDate, now) }
            val overdue = active.count {
                DateUtils.isOverdue(it.assignment.dueDate, completed = false, now = now)
            }
            WidgetSnapshot(
                activeCount = active.size,
                dueTodayCount = dueToday,
                overdueCount = overdue,
                items = active.map { item ->
                    val subject = item.assignment.subjectId
                        ?.let { subjects[it]?.name }
                        ?: "未分类"
                    val due = if (overdueItem(item.assignment.dueDate, now)) {
                        "已逾期 · ${DateUtils.dueLabel(item.assignment.dueDate, now)}"
                    } else {
                        DateUtils.dueLabel(item.assignment.dueDate, now)
                    }
                    val checklist = if (item.subtasks.isEmpty()) {
                        ""
                    } else {
                        " · 子任务 ${item.completedSubtaskCount}/${item.subtasks.size}"
                    }
                    WidgetItem(
                        title = item.assignment.title,
                        subtitle = "$subject · $due$checklist"
                    )
                }
            )
        }
    }

    private fun overdueItem(dueDate: Long?, now: Long): Boolean =
        dueDate != null && dueDate < now
}
