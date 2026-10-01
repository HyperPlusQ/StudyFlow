package com.hyperplusq.studyflow.data

import com.hyperplusq.studyflow.data.db.AppDatabase
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.SubmissionHistoryEntity
import com.hyperplusq.studyflow.data.db.SubjectEntity
import com.hyperplusq.studyflow.data.db.SubtaskEntity
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import kotlinx.coroutines.flow.Flow

class StudyRepository(private val db: AppDatabase) {
    internal val database: AppDatabase
        get() = db
    val subjects: Flow<List<SubjectEntity>> = db.subjectDao().observeAll()
    val assignments: Flow<List<com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks>> =
        db.assignmentDao().observeAllWithSubtasks()
    val timeBlocks: Flow<List<TimeBlockEntity>> = db.timeBlockDao().observeAll()
    val submissionHistory: Flow<List<SubmissionHistoryEntity>> =
        db.submissionHistoryDao().observeAll()

    suspend fun subject(id: Long): SubjectEntity? = db.subjectDao().findById(id)
    suspend fun assignment(id: Long) = db.assignmentDao().findById(id)

    /** 新增或更新科目并返回其主键。 */
    suspend fun saveSubject(subject: SubjectEntity): Long =
        if (subject.id == 0L) db.subjectDao().insert(subject)
        else db.subjectDao().update(subject).let { subject.id }

    suspend fun deleteSubject(subject: SubjectEntity) = db.subjectDao().deleteTree(subject)

    /** 新增或更新作业并返回其主键。 */
    suspend fun saveAssignment(assignment: AssignmentEntity): Long =
        if (assignment.id == 0L) db.assignmentDao().insert(assignment)
        else db.assignmentDao().update(assignment).let { assignment.id }

    suspend fun deleteAssignment(id: Long) = db.assignmentDao().delete(id)

    /** 更新作业完成状态和完成时间。 */
    suspend fun setAssignmentStatus(id: Long, completed: Boolean) {
        if (completed) db.subtaskDao().completeAll(id)
        db.assignmentDao().updateStatus(
            id = id,
            status = if (completed) AssignmentStatus.COMPLETED.rawValue else AssignmentStatus.ACTIVE.rawValue,
            completedAt = if (completed) System.currentTimeMillis() else null
        )
    }

    suspend fun setCalendarEventId(id: Long, eventId: Long?) =
        db.assignmentDao().setCalendarEventId(id, eventId)

    suspend fun saveSubtask(subtask: SubtaskEntity): Long =
        if (subtask.id == 0L) db.subtaskDao().insert(subtask)
        else db.subtaskDao().update(subtask).let { subtask.id }

    suspend fun deleteSubtask(id: Long) = db.subtaskDao().delete(id)

    suspend fun setSubtaskCompleted(id: Long, completed: Boolean) =
        db.subtaskDao().setCompleted(id, completed)

    suspend fun saveTimeBlock(block: TimeBlockEntity): Long =
        if (block.id == 0L) db.timeBlockDao().insert(block)
        else db.timeBlockDao().update(block).let { block.id }

    suspend fun deleteTimeBlock(id: Long) = db.timeBlockDao().delete(id)

    /** 记录科目下使用过的提交方式。 */
    suspend fun rememberSubmission(subjectId: Long?, method: String) {
        val normalized = method.trim()
        if (subjectId != null && normalized.isNotBlank()) {
            db.submissionHistoryDao().remember(subjectId, normalized, System.currentTimeMillis())
        }
    }

    suspend fun deleteSubmissionHistory(id: Long) =
        db.submissionHistoryDao().delete(id)

    /** 一次性读取全部作业，供导出和小组件使用。 */
    suspend fun allAssignmentsOnce(): List<AssignmentEntity> = db.assignmentDao().allOnce()
    suspend fun subjectsOnce(): List<SubjectEntity> = db.subjectDao().allOnce()
    suspend fun assignmentsOnce(): List<com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks> =
        db.assignmentDao().allOnceWithSubtasks()
    suspend fun timeBlocksOnce(): List<TimeBlockEntity> = db.timeBlockDao().allOnce()
    suspend fun submissionHistoryOnce(): List<SubmissionHistoryEntity> =
        db.submissionHistoryDao().allOnce()
}
