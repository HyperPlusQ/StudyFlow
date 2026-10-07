package com.hyperplusq.studyflow.data.db

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface SubjectDao {
    @Query("SELECT * FROM subjects")
    suspend fun allOnce(): List<SubjectEntity>

    @Query("SELECT * FROM subjects ORDER BY sortOrder, createdAt")
    fun observeAll(): Flow<List<SubjectEntity>>

    @Query("SELECT * FROM subjects WHERE id = :id")
    suspend fun findById(id: Long): SubjectEntity?

    @Insert
    suspend fun insert(subject: SubjectEntity): Long

    @Update
    suspend fun update(subject: SubjectEntity)

    @Query("DELETE FROM subjects WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM subjects")
    suspend fun deleteAll()

    @Query("UPDATE subjects SET parentId = :newParentId WHERE parentId = :oldParentId")
    suspend fun promoteChildren(oldParentId: Long, newParentId: Long?)

    @Query("UPDATE assignments SET subjectId = NULL WHERE subjectId = :subjectId")
    suspend fun detachAssignments(subjectId: Long)

    @Query("UPDATE time_blocks SET subjectId = NULL WHERE subjectId = :subjectId")
    suspend fun detachTimeBlocks(subjectId: Long)

    @Query("DELETE FROM submission_history WHERE subjectId = :subjectId")
    suspend fun deleteHistory(subjectId: Long)

    @Transaction
    suspend fun deleteTree(subject: SubjectEntity) {
        promoteChildren(subject.id, subject.parentId)
        detachAssignments(subject.id)
        detachTimeBlocks(subject.id)
        deleteHistory(subject.id)
        delete(subject.id)
    }
}

@Dao
interface AssignmentDao {
    @Transaction
    @Query("SELECT * FROM assignments ORDER BY createdAt DESC")
    fun observeAllWithSubtasks(): Flow<List<AssignmentWithSubtasks>>

    @Transaction
    @Query("SELECT * FROM assignments WHERE id = :id")
    fun observeById(id: Long): Flow<AssignmentWithSubtasks?>

    @Transaction
    @Query("SELECT * FROM assignments WHERE id = :id")
    suspend fun findById(id: Long): AssignmentWithSubtasks?

    @Insert
    suspend fun insert(assignment: AssignmentEntity): Long

    @Update
    suspend fun update(assignment: AssignmentEntity)

    @Query("SELECT * FROM assignments")
    suspend fun allOnce(): List<AssignmentEntity>

    @Transaction
    @Query("SELECT * FROM assignments")
    suspend fun allOnceWithSubtasks(): List<AssignmentWithSubtasks>

    @Query("DELETE FROM assignments WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM assignments")
    suspend fun deleteAll()

    @Query("UPDATE assignments SET status = :status, completedAt = :completedAt, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateStatus(id: Long, status: Int, completedAt: Long?, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE assignments SET calendarEventId = :eventId WHERE id = :id")
    suspend fun setCalendarEventId(id: Long, eventId: Long?)
}

@Dao
interface AttachmentDao {
    @Query("SELECT * FROM attachments WHERE assignmentId = :assignmentId ORDER BY createdAt")
    suspend fun forAssignment(assignmentId: Long): List<AttachmentEntity>

    @Insert
    suspend fun insert(attachment: AttachmentEntity): Long

    @Insert
    suspend fun insertAll(attachments: List<AttachmentEntity>)

    @Query("DELETE FROM attachments WHERE assignmentId = :assignmentId")
    suspend fun deleteForAssignment(assignmentId: Long)

    @Query("DELETE FROM attachments")
    suspend fun deleteAll()
}

@Dao
interface SubtaskDao {
    @Insert
    suspend fun insert(subtask: SubtaskEntity): Long

    @Update
    suspend fun update(subtask: SubtaskEntity)

    @Query("DELETE FROM subtasks WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM subtasks")
    suspend fun deleteAll()

    @Query("UPDATE subtasks SET isCompleted = :completed WHERE id = :id")
    suspend fun setCompleted(id: Long, completed: Boolean)

    @Query("UPDATE subtasks SET isCompleted = 1 WHERE assignmentId = :assignmentId")
    suspend fun completeAll(assignmentId: Long)
}

@Dao
interface TimeBlockDao {
    @Query("SELECT * FROM time_blocks ORDER BY startDate")
    fun observeAll(): Flow<List<TimeBlockEntity>>

    @Insert
    suspend fun insert(block: TimeBlockEntity): Long

    @Update
    suspend fun update(block: TimeBlockEntity)

    @Query("SELECT * FROM time_blocks")
    suspend fun allOnce(): List<TimeBlockEntity>

    @Query("DELETE FROM time_blocks WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM time_blocks")
    suspend fun deleteAll()
}

@Dao
interface SubmissionHistoryDao {
    @Query("SELECT * FROM submission_history WHERE subjectId = :subjectId ORDER BY lastUsedAt DESC")
    fun observeForSubject(subjectId: Long): Flow<List<SubmissionHistoryEntity>>

    @Query("SELECT * FROM submission_history ORDER BY lastUsedAt DESC")
    fun observeAll(): Flow<List<SubmissionHistoryEntity>>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(entry: SubmissionHistoryEntity): Long

    @Query(
        """
        INSERT OR IGNORE INTO submission_history(subjectId, method, lastUsedAt)
        VALUES(:subjectId, :method, :lastUsedAt)
        """
    )
    suspend fun remember(subjectId: Long, method: String, lastUsedAt: Long)

    @Query("SELECT * FROM submission_history")
    suspend fun allOnce(): List<SubmissionHistoryEntity>

    @Query("DELETE FROM submission_history WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("DELETE FROM submission_history")
    suspend fun deleteAll()
}
