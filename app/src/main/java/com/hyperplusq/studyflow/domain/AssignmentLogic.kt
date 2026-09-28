package com.hyperplusq.studyflow.domain

import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import com.hyperplusq.studyflow.data.db.Priority
import com.hyperplusq.studyflow.data.db.SubjectEntity
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

enum class ListScope(val title: String) {
    TODAY("今天"),
    UPCOMING("即将到期"),
    ALL("所有作业"),
    COMPLETED("已完成"),
    DASHBOARD("仪表盘")
}

enum class DueWindow(val title: String) {
    ALL("全部日期"),
    OVERDUE("已逾期"),
    TODAY("今天截止"),
    WEEK("本周截止"),
    NO_DATE("无截止日期");

    fun contains(epochMillis: Long?, now: Long = System.currentTimeMillis()): Boolean {
        val date = epochMillis ?: return this == NO_DATE
        if (this == NO_DATE) return false
        val zone = ZoneId.systemDefault()
        val taskDate = Instant.ofEpochMilli(date).atZone(zone).toLocalDate()
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        return when (this) {
            ALL -> true
            OVERDUE -> date < now
            TODAY -> taskDate == today
            WEEK -> !taskDate.isBefore(today) && !taskDate.isAfter(today.plusDays(7))
            NO_DATE -> false
        }
    }
}

data class AssignmentFilter(
    val searchText: String = "",
    val subjectId: Long? = null,
    val dueWindow: DueWindow = DueWindow.ALL,
    val priority: Priority? = null,
    val hasChecklistOnly: Boolean = false
) {
    val isDefault: Boolean
        get() = searchText.isBlank() && subjectId == null && dueWindow == DueWindow.ALL &&
            priority == null && !hasChecklistOnly

    fun reset() = AssignmentFilter()
}

object SmartScoring {
    fun score(item: AssignmentWithSubtasks, now: Long = System.currentTimeMillis()): Double {
        val assignment = item.assignment
        if (assignment.status == AssignmentStatus.COMPLETED.rawValue) return -1.0
        val priority = Priority.fromRaw(assignment.priority)
        var score = assignment.weight * 35.0 + priority.rawValue * 25.0
        val due = assignment.dueDate
        if (due != null) {
            val remainingHours = (due - now).toDouble() / TimeUnit.HOURS.toMillis(1)
            score += when {
                remainingHours < 0 -> 1000 + minOf(kotlin.math.abs(remainingHours), 240.0) * 2
                remainingHours < 6 -> 720 - remainingHours * 12
                remainingHours < 24 -> 520.0
                remainingHours < 72 -> 360.0
                remainingHours < 168 -> 220.0
                else -> 80.0
            }
        } else {
            score += 140.0
        }
        val checklistPenalty = item.progress * 80.0
        return (score - checklistPenalty).coerceAtLeast(0.0)
    }

    fun sort(items: List<AssignmentWithSubtasks>, now: Long = System.currentTimeMillis()): List<AssignmentWithSubtasks> =
        items.sortedWith(
            compareByDescending<AssignmentWithSubtasks> { score(it, now) }
                .thenBy { it.assignment.dueDate ?: Long.MAX_VALUE }
                .thenBy { it.assignment.createdAt }
        )
}

object AssignmentQueries {
    fun matches(item: AssignmentWithSubtasks, filter: AssignmentFilter, scope: ListScope): Boolean {
        val a = item.assignment
        if (scope == ListScope.COMPLETED && a.status != AssignmentStatus.COMPLETED.rawValue) return false
        if (scope != ListScope.COMPLETED && a.status == AssignmentStatus.COMPLETED.rawValue) return false
        if (filter.subjectId != null && a.subjectId != filter.subjectId) return false
        if (filter.priority != null && a.priority != filter.priority.rawValue) return false
        if (filter.hasChecklistOnly && item.subtasks.isEmpty()) return false
        if (!filter.dueWindow.contains(a.dueDate)) return false

        if (scope == ListScope.TODAY && !DueWindow.TODAY.contains(a.dueDate)) return false
        if (scope == ListScope.UPCOMING) {
            if (a.dueDate == null || a.dueDate < System.currentTimeMillis()) return false
        }

        val needle = filter.searchText.trim()
        if (needle.isNotBlank()) {
            val haystack = listOf(
                a.title,
                a.details,
                a.submissionMethod
            ).plus(item.subtasks.map { it.title }).joinToString("\n")
            if (!haystack.contains(needle, ignoreCase = true)) return false
        }
        return true
    }
}

object DateUtils {
    fun localDate(epochMillis: Long?): LocalDate? =
        epochMillis?.let { Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate() }

    fun startOfDay(epochMillis: Long?): Long? =
        localDate(epochMillis)?.atStartOfDay(ZoneId.systemDefault())?.toInstant()?.toEpochMilli()

    fun isSameDay(a: Long?, b: Long?): Boolean = localDate(a) != null && localDate(a) == localDate(b)

    fun dueLabel(epochMillis: Long?, now: Long = System.currentTimeMillis()): String {
        if (epochMillis == null) return "无截止日期"
        val zone = ZoneId.systemDefault()
        val date = Instant.ofEpochMilli(epochMillis).atZone(zone)
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val taskDate = date.toLocalDate()
        val time = "%02d:%02d".format(date.hour, date.minute)
        return when (taskDate) {
            today -> "今天 $time"
            today.plusDays(1) -> "明天 $time"
            today.minusDays(1) -> "昨天 $time"
            else -> "%d月%d日 %s".format(taskDate.monthValue, taskDate.dayOfMonth, time)
        }
    }

    fun isOverdue(epochMillis: Long?, completed: Boolean, now: Long = System.currentTimeMillis()): Boolean =
        !completed && epochMillis != null && epochMillis < now
}
