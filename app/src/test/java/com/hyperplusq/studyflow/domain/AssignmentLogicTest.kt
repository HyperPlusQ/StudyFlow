package com.hyperplusq.studyflow.domain

import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 作业筛选与排序的静态校验，重点覆盖「没有截止日期的作业」的显示规则。
 */
class AssignmentLogicTest {
    private fun item(
        dueDate: Long?,
        id: Long = 1,
        status: Int = AssignmentStatus.ACTIVE.rawValue
    ) = AssignmentWithSubtasks(
        assignment = AssignmentEntity(
            id = id,
            title = "没有截止日期的作业",
            dueDate = dueDate,
            status = status
        ),
        subtasks = emptyList(),
        attachments = emptyList()
    )

    @Test
    fun allWindowKeepsAssignmentsWithoutDueDate() {
        assertTrue(DueWindow.ALL.contains(null))
        assertTrue(DueWindow.NO_DATE.contains(null))
        assertFalse(DueWindow.TODAY.contains(null))
        assertFalse(DueWindow.WEEK.contains(null))
        assertFalse(DueWindow.OVERDUE.contains(null))
    }

    @Test
    fun datedAssignmentStillFollowsWindowSelection() {
        val now = System.currentTimeMillis()
        assertTrue(DueWindow.ALL.contains(now))
        assertFalse(DueWindow.NO_DATE.contains(now))
        assertTrue(DueWindow.OVERDUE.contains(now - 86_400_000L))
        assertFalse(DueWindow.OVERDUE.contains(now + 86_400_000L))
    }

    @Test
    fun undatedAssignmentShowsInDefaultAssignmentList() {
        // 默认筛选（全部日期、无关键词）下，未设截止日期的作业必须显示。
        assertTrue(AssignmentQueries.matches(item(null), AssignmentFilter(), ListScope.ALL))

        // 选择“无截止日期”时显示它，同时排除有日期的作业。
        val noDateFilter = AssignmentFilter(dueWindow = DueWindow.NO_DATE)
        assertTrue(AssignmentQueries.matches(item(null), noDateFilter, ListScope.ALL))
        assertFalse(AssignmentQueries.matches(item(System.currentTimeMillis()), noDateFilter, ListScope.ALL))
    }

    @Test
    fun undatedAssignmentStaysOutOfDateSpecificScopes() {
        assertFalse(AssignmentQueries.matches(item(null), AssignmentFilter(), ListScope.TODAY))
        assertFalse(AssignmentQueries.matches(item(null), AssignmentFilter(), ListScope.UPCOMING))
        assertFalse(
            AssignmentQueries.matches(
                item(null),
                AssignmentFilter(dueWindow = DueWindow.OVERDUE),
                ListScope.ALL
            )
        )
    }

    @Test
    fun scopeStillSeparatesCompletedAssignments() {
        val done = item(null, status = AssignmentStatus.COMPLETED.rawValue)
        assertFalse(AssignmentQueries.matches(done, AssignmentFilter(), ListScope.ALL))
        assertTrue(AssignmentQueries.matches(done, AssignmentFilter(), ListScope.COMPLETED))
    }

    @Test
    fun sortingKeepsUndatedAssignments() {
        val undated = item(null, id = 1)
        val dated = item(System.currentTimeMillis() + 86_400_000L, id = 2)
        val sorted = SmartScoring.sort(listOf(undated, dated))

        assertTrue(sorted.size == 2)
        assertTrue(sorted.map { it.assignment.id }.containsAll(listOf(1L, 2L)))
    }

    @Test
    fun searchAndSubjectFiltersStillApplyToUndatedAssignments() {
        val filtered = AssignmentFilter(searchText = "没有匹配")
        assertFalse(AssignmentQueries.matches(item(null), filtered, ListScope.ALL))

        val otherSubject = AssignmentFilter(subjectId = 42L)
        assertFalse(AssignmentQueries.matches(item(null), otherSubject, ListScope.ALL))
    }
}
