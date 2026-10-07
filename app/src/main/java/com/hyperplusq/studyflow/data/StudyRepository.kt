package com.hyperplusq.studyflow.data

import androidx.room.withTransaction
import com.hyperplusq.studyflow.data.db.AppDatabase
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AttachmentEntity
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

    /** 新增或更新科目；编辑时保留最近一次作业登记时间。 */
    suspend fun saveSubject(subject: SubjectEntity): Long = db.withTransaction {
        if (subject.id == 0L) {
            db.subjectDao().insert(subject)
        } else {
            val previous = db.subjectDao().findById(subject.id)
            db.subjectDao().update(
                subject.copy(lastAssignmentRegisteredAt = subject.lastAssignmentRegisteredAt
                    ?: previous?.lastAssignmentRegisteredAt)
            )
            subject.id
        }
    }

    /** 删除科目并取消关联数据。 */
    suspend fun deleteSubject(subject: SubjectEntity) = db.subjectDao().deleteTree(subject)

    /**
     * 在同一事务中保存作业、附件和科目登记时间，避免界面或小组件读取到中间状态。
     * 附件传入 null 时不会修改现有附件；传入列表时（包括空列表）会整体替换。
     */
    suspend fun saveAssignment(
        assignment: AssignmentEntity,
        attachments: List<AttachmentEntity>? = null
    ): Long = db.withTransaction {
        val previous = if (assignment.id == 0L) null else db.assignmentDao().findById(assignment.id)
        val savedId = if (assignment.id == 0L) {
            db.assignmentDao().insert(assignment)
        } else {
            db.assignmentDao().update(assignment)
            assignment.id
        }

        if (attachments != null) {
            db.attachmentDao().deleteForAssignment(savedId)
            if (attachments.isNotEmpty()) {
                db.attachmentDao().insertAll(
                    attachments.map { it.copy(id = 0, assignmentId = savedId) }
                )
            }
        }

        // 新作业（含从其他科目移动过来的作业）刷新目标科目的登记时间。
        assignment.subjectId?.let { subjectId ->
            val shouldMarkNewRegistration = assignment.id == 0L ||
                previous?.assignment?.subjectId != assignment.subjectId
            if (shouldMarkNewRegistration) {
                db.subjectDao().findById(subjectId)?.let { subject ->
                    db.subjectDao().update(
                        subject.copy(lastAssignmentRegisteredAt = System.currentTimeMillis())
                    )
                }
            }
        }
        savedId
    }

    /** 删除作业时由外键级联清理附件。 */
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

    /** 一次性读取全部数据，供导出、提醒和小组件使用。 */
    suspend fun allAssignmentsOnce(): List<AssignmentEntity> = db.assignmentDao().allOnce()
    suspend fun subjectsOnce(): List<SubjectEntity> = db.subjectDao().allOnce()
    suspend fun assignmentsOnce(): List<com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks> =
        db.assignmentDao().allOnceWithSubtasks()
    suspend fun timeBlocksOnce(): List<TimeBlockEntity> = db.timeBlockDao().allOnce()
    suspend fun submissionHistoryOnce(): List<SubmissionHistoryEntity> =
        db.submissionHistoryDao().allOnce()
    suspend fun attachmentsFor(assignmentId: Long): List<AttachmentEntity> =
        db.attachmentDao().forAssignment(assignmentId)
}
