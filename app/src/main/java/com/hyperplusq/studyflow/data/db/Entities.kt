package com.hyperplusq.studyflow.data.db

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Relation

enum class Priority(val rawValue: Int, val label: String) {
    LOW(1, "低"),
    MEDIUM(2, "中"),
    HIGH(3, "高"),
    CRITICAL(4, "紧急");

    companion object {
        fun fromRaw(value: Int): Priority = entries.firstOrNull { it.rawValue == value } ?: MEDIUM
    }
}

enum class AssignmentStatus(val rawValue: Int, val label: String) {
    ACTIVE(0, "进行中"),
    COMPLETED(1, "已完成");

    companion object {
        fun fromRaw(value: Int): AssignmentStatus =
            entries.firstOrNull { it.rawValue == value } ?: ACTIVE
    }
}

@Entity(tableName = "subjects", indices = [Index("parentId")])
data class SubjectEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val symbol: String = "menu_book",
    val colorHex: String = "#4F6BED",
    val parentId: Long? = null,
    val sortOrder: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    /** 距上一次登记作业多少天后提醒再次登记，null 表示关闭。 */
    val assignmentIntervalDays: Int? = null,
    /** 最近一次新建本科目作业的时间，用于布置间隔提醒。 */
    val lastAssignmentRegisteredAt: Long? = null
)

@Entity(
    tableName = "assignments",
    indices = [Index("subjectId"), Index("dueDate"), Index("status")]
)
data class AssignmentEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val details: String = "",
    val dueDate: Long? = null,
    val submissionMethod: String = "",
    val subjectId: Long? = null,
    val priority: Int = Priority.MEDIUM.rawValue,
    val status: Int = AssignmentStatus.ACTIVE.rawValue,
    val weight: Int = 3,
    val reminderLeadHours: Int = 24,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val completedAt: Long? = null,
    val calendarEventId: Long? = null
)

@Entity(
    tableName = "attachments",
    foreignKeys = [
        ForeignKey(
            entity = AssignmentEntity::class,
            parentColumns = ["id"],
            childColumns = ["assignmentId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("assignmentId")]
)
data class AttachmentEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val assignmentId: Long,
    val fileName: String,
    val mimeType: String = "image/jpeg",
    val imageData: ByteArray,
    val createdAt: Long = System.currentTimeMillis()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AttachmentEntity) return false
        return id == other.id &&
            assignmentId == other.assignmentId &&
            fileName == other.fileName &&
            mimeType == other.mimeType &&
            imageData.contentEquals(other.imageData) &&
            createdAt == other.createdAt
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + assignmentId.hashCode()
        result = 31 * result + fileName.hashCode()
        result = 31 * result + mimeType.hashCode()
        result = 31 * result + imageData.contentHashCode()
        result = 31 * result + createdAt.hashCode()
        return result
    }
}

@Entity(
    tableName = "subtasks",
    foreignKeys = [
        ForeignKey(
            entity = AssignmentEntity::class,
            parentColumns = ["id"],
            childColumns = ["assignmentId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("assignmentId")]
)
data class SubtaskEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val assignmentId: Long,
    val title: String,
    val isCompleted: Boolean = false,
    val sortOrder: Int = 0
)

@Entity(tableName = "time_blocks", indices = [Index("subjectId"), Index("assignmentId"), Index("startDate")])
data class TimeBlockEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val assignmentId: Long? = null,
    val subjectId: Long? = null,
    val startDate: Long,
    val durationMinutes: Int = 60,
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "submission_history",
    indices = [Index(value = ["subjectId", "method"], unique = true)]
)
data class SubmissionHistoryEntity(
    @androidx.room.PrimaryKey(autoGenerate = true) val id: Long = 0,
    val subjectId: Long,
    val method: String,
    val lastUsedAt: Long = System.currentTimeMillis()
)

data class AssignmentWithSubtasks(
    @Embedded val assignment: AssignmentEntity,
    @Relation(parentColumn = "id", entityColumn = "assignmentId")
    val subtasks: List<SubtaskEntity>,
    @Relation(parentColumn = "id", entityColumn = "assignmentId")
    val attachments: List<AttachmentEntity>
) {
    val completedSubtaskCount: Int get() = subtasks.count { it.isCompleted }
    val progress: Float
        get() = when {
            subtasks.isEmpty() && assignment.status == AssignmentStatus.COMPLETED.rawValue -> 1f
            subtasks.isEmpty() -> 0f
            else -> completedSubtaskCount.toFloat() / subtasks.size
        }
}
