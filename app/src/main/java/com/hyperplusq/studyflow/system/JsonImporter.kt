package com.hyperplusq.studyflow.system

import android.content.Context
import android.net.Uri
import androidx.room.withTransaction
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.SubmissionHistoryEntity
import com.hyperplusq.studyflow.data.db.SubjectEntity
import com.hyperplusq.studyflow.data.db.SubtaskEntity
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import java.time.Instant
import java.time.OffsetDateTime
import org.json.JSONArray
import org.json.JSONObject

/**
 * Imports both StudyFlow Android snapshots (numeric IDs / epoch milliseconds)
 * and StudyFlow macOS snapshots (UUIDs / ISO-8601 dates). The complete document
 * is parsed and validated before the destructive replacement is started.
 */
object JsonImporter {
    data class Summary(
        val subjects: Int,
        val assignments: Int,
        val subtasks: Int,
        val timeBlocks: Int,
        val submissionHistory: Int
    ) {
        val total: Int get() = subjects + assignments + subtasks + timeBlocks + submissionHistory
    }

    private data class SubjectRecord(
        val rawId: String,
        val name: String,
        val symbol: String,
        val colorHex: String,
        val parentRawId: String?,
        val sortOrder: Int,
        val createdAt: Long
    )

    private data class SubtaskRecord(
        val rawId: String,
        val title: String,
        val isCompleted: Boolean,
        val sortOrder: Int
    )

    private data class AssignmentRecord(
        val rawId: String,
        val title: String,
        val details: String,
        val dueDate: Long?,
        val submissionMethod: String,
        val subjectRawId: String?,
        val priority: Int,
        val status: Int,
        val weight: Int,
        val reminderLeadHours: Int,
        val createdAt: Long,
        val updatedAt: Long,
        val completedAt: Long?,
        val calendarEventId: Long?,
        val subtasks: List<SubtaskRecord>
    )

    private data class TimeBlockRecord(
        val rawId: String,
        val title: String,
        val assignmentRawId: String?,
        val subjectRawId: String?,
        val startDate: Long,
        val durationMinutes: Int,
        val notes: String,
        val createdAt: Long
    )

    private data class HistoryRecord(
        val rawId: String,
        val subjectRawId: String,
        val method: String,
        val lastUsedAt: Long
    )

    private data class Document(
        val subjects: List<SubjectRecord>,
        val assignments: List<AssignmentRecord>,
        val timeBlocks: List<TimeBlockRecord>,
        val history: List<HistoryRecord>
    )

    /** 校验并用 JSON 内容替换当前数据库。 */
    suspend fun import(
        context: Context,
        uri: Uri,
        repository: StudyRepository,
        beforeReplace: suspend () -> Unit = {}
    ): Summary {
        val document = context.contentResolver.openInputStream(uri)?.use { input ->
            parse(String(input.readBytes(), Charsets.UTF_8))
        } ?: error("无法读取所选文件")

        validate(document)
        beforeReplace()

        return repository.database.withTransaction {
            val dao = repository.database
            dao.submissionHistoryDao().deleteAll()
            dao.timeBlockDao().deleteAll()
            dao.subtaskDao().deleteAll()
            dao.assignmentDao().deleteAll()
            dao.subjectDao().deleteAll()

            val subjectIds = mutableMapOf<String, Long>()
            document.subjects.forEach { record ->
                subjectIds[record.rawId] = dao.subjectDao().insert(
                    SubjectEntity(
                        id = 0,
                        name = record.name,
                        symbol = record.symbol,
                        colorHex = record.colorHex,
                        parentId = null,
                        sortOrder = record.sortOrder,
                        createdAt = record.createdAt
                    )
                )
            }
            // Subjects have no Room foreign key on parentId, so parent links can be
            // applied after every subject has received its generated ID.
            document.subjects.forEach { record ->
                val parent = record.parentRawId?.let { subjectIds[it] }
                if (parent != null) {
                    dao.subjectDao().update(
                        SubjectEntity(
                            id = subjectIds.getValue(record.rawId),
                            name = record.name,
                            symbol = record.symbol,
                            colorHex = record.colorHex,
                            parentId = parent,
                            sortOrder = record.sortOrder,
                            createdAt = record.createdAt
                        )
                    )
                }
            }

            val assignmentIds = mutableMapOf<String, Long>()
            document.assignments.forEach { record ->
                val id = dao.assignmentDao().insert(
                    AssignmentEntity(
                        id = 0,
                        title = record.title,
                        details = record.details,
                        dueDate = record.dueDate,
                        submissionMethod = record.submissionMethod,
                        subjectId = record.subjectRawId?.let { subjectIds[it] },
                        priority = record.priority,
                        status = record.status,
                        weight = record.weight,
                        reminderLeadHours = record.reminderLeadHours,
                        createdAt = record.createdAt,
                        updatedAt = record.updatedAt,
                        completedAt = record.completedAt,
                        calendarEventId = record.calendarEventId
                    )
                )
                assignmentIds[record.rawId] = id
                record.subtasks.forEach { subtask ->
                    dao.subtaskDao().insert(
                        SubtaskEntity(
                            id = 0,
                            assignmentId = id,
                            title = subtask.title,
                            isCompleted = subtask.isCompleted,
                            sortOrder = subtask.sortOrder
                        )
                    )
                }
            }

            document.timeBlocks.forEach { record ->
                dao.timeBlockDao().insert(
                    TimeBlockEntity(
                        id = 0,
                        title = record.title,
                        assignmentId = record.assignmentRawId?.let { assignmentIds[it] },
                        subjectId = record.subjectRawId?.let { subjectIds[it] },
                        startDate = record.startDate,
                        durationMinutes = record.durationMinutes,
                        notes = record.notes,
                        createdAt = record.createdAt
                    )
                )
            }

            document.history.forEach { record ->
                val subjectId = subjectIds[record.subjectRawId]
                if (subjectId != null) {
                    dao.submissionHistoryDao().insert(
                        SubmissionHistoryEntity(
                            id = 0,
                            subjectId = subjectId,
                            method = record.method,
                            lastUsedAt = record.lastUsedAt
                        )
                    )
                }
            }

            Summary(
                subjects = document.subjects.size,
                assignments = document.assignments.size,
                subtasks = document.assignments.sumOf { it.subtasks.size },
                timeBlocks = document.timeBlocks.size,
                submissionHistory = document.history.size
            )
        }
    }

    private fun parse(json: String): Document {
        val root = JSONObject(json)
        val hasFormat = root.optString("format") == "StudyFlow"
        val hasSchema = root.has("schemaVersion") && root.optString("app", "StudyFlow") == "StudyFlow"
        if (!hasFormat && !hasSchema) error("所选文件不是 StudyFlow 数据快照")

        val subjects = root.optJSONArray("subjects").orEmpty().map { parseSubject(it as JSONObject) }
        val assignments = root.optJSONArray("assignments").orEmpty().map { parseAssignment(it as JSONObject) }
        val timeBlocks = root.optJSONArray("timeBlocks").orEmpty().map { parseTimeBlock(it as JSONObject) }
        val history = root.optJSONArray("submissionHistory").orEmpty().map { parseHistory(it as JSONObject) }
        return Document(subjects, assignments, timeBlocks, history)
    }

    private fun parseSubject(obj: JSONObject) = SubjectRecord(
        rawId = rawId(obj),
        name = requiredString(obj, "name"),
        symbol = obj.optString("symbol", "menu_book"),
        colorHex = obj.optString("colorHex", "#4F6BED"),
        parentRawId = nullableRawId(obj.opt("parentId")),
        sortOrder = obj.optInt("sortOrder", 0),
        createdAt = dateOrNow(obj.opt("createdAt"))
    )

    private fun parseAssignment(obj: JSONObject): AssignmentRecord {
        val rawStatus = obj.opt("status")
        val status = when (rawStatus) {
            is Number -> rawStatus.toInt()
            is String -> if (rawStatus.equals("completed", ignoreCase = true)) 1 else 0
            else -> 0
        }
        return AssignmentRecord(
            rawId = rawId(obj),
            title = requiredString(obj, "title"),
            details = obj.optString("details", ""),
            dueDate = nullableDate(obj.opt("dueDate")),
            submissionMethod = obj.optString("submissionMethod", obj.optString("value", "")),
            subjectRawId = nullableRawId(obj.opt("subjectId")),
            priority = obj.optInt("priority", 2),
            status = status,
            weight = obj.optInt("weight", 3),
            reminderLeadHours = obj.optInt("reminderLeadHours", 24),
            createdAt = dateOrNow(obj.opt("createdAt")),
            updatedAt = dateOrNow(obj.opt("updatedAt")),
            completedAt = nullableDate(obj.opt("completedAt")),
            calendarEventId = nullableLong(obj.opt("calendarEventId")),
            subtasks = obj.optJSONArray("subtasks").orEmpty().map { subtask ->
                val item = subtask as JSONObject
                SubtaskRecord(
                    rawId = rawId(item),
                    title = requiredString(item, "title"),
                    isCompleted = item.optBoolean("isCompleted", false),
                    sortOrder = item.optInt("sortOrder", 0)
                )
            }
        )
    }

    private fun parseTimeBlock(obj: JSONObject) = TimeBlockRecord(
        rawId = rawId(obj),
        title = requiredString(obj, "title"),
        assignmentRawId = nullableRawId(obj.opt("assignmentId")),
        subjectRawId = nullableRawId(obj.opt("subjectId")),
        startDate = requiredDate(obj.opt("startDate")),
        durationMinutes = obj.optInt("durationMinutes", 60),
        notes = obj.optString("notes", ""),
        createdAt = dateOrNow(obj.opt("createdAt"))
    )

    private fun parseHistory(obj: JSONObject) = HistoryRecord(
        rawId = rawId(obj),
        subjectRawId = requiredRawId(obj.opt("subjectId")),
        method = requiredString(obj, if (obj.has("method")) "method" else "value"),
        lastUsedAt = dateOrNow(obj.opt("lastUsedAt"))
    )

    private fun validate(document: Document) {
        requireUnique(document.subjects.map { it.rawId })
        requireUnique(document.assignments.map { it.rawId })
        requireUnique(document.timeBlocks.map { it.rawId })
        requireUnique(document.history.map { it.rawId })
        requireUnique(document.assignments.flatMap { it.subtasks }.map { it.rawId })

        val subjects = document.subjects.map { it.rawId }.toSet()
        document.subjects.forEach { record ->
            record.parentRawId?.let {
                require(it in subjects) { "科目 $it 引用了不存在的上级科目" }
            }
        }
        val assignments = document.assignments.map { it.rawId }.toSet()
        document.assignments.forEach { record ->
            record.subjectRawId?.let {
                require(it in subjects) { "作业 ${record.title} 引用了不存在的科目" }
            }
        }
        document.timeBlocks.forEach { record ->
            record.assignmentRawId?.let {
                require(it in assignments) { "时间块 ${record.title} 引用了不存在的作业" }
            }
            record.subjectRawId?.let {
                require(it in subjects) { "时间块 ${record.title} 引用了不存在的科目" }
            }
        }
        document.history.forEach { record ->
            require(record.subjectRawId in subjects) { "提交方式记录引用了不存在的科目" }
        }
    }

    private fun requireUnique(ids: List<String>) {
        require(ids.none { it.isBlank() }) { "快照包含空的数据标识" }
        require(ids.toSet().size == ids.size) { "快照包含重复的数据标识" }
    }

    private fun rawId(obj: JSONObject): String = requiredRawId(obj.opt("id"))

    private fun requiredRawId(value: Any?): String =
        nullableRawId(value) ?: error("快照记录缺少 id")

    private fun nullableRawId(value: Any?): String? = when {
        value == null || value == JSONObject.NULL -> null
        else -> value.toString().takeIf { it.isNotBlank() }
    }

    private fun requiredString(obj: JSONObject, key: String): String =
        obj.optString(key, "").takeIf { it.isNotBlank() } ?: error("快照记录缺少 $key")

    private fun nullableLong(value: Any?): Long? = when {
        value == null || value == JSONObject.NULL -> null
        value is Number -> value.toLong()
        else -> value.toString().toLongOrNull()
    }

    private fun nullableDate(value: Any?): Long? = when {
        value == null || value == JSONObject.NULL -> null
        value is Number -> value.toLong()
        else -> parseDate(value.toString())
    }

    private fun requiredDate(value: Any?): Long =
        nullableDate(value) ?: error("快照记录缺少日期")

    private fun dateOrNow(value: Any?): Long = nullableDate(value) ?: System.currentTimeMillis()

    private fun parseDate(value: String): Long {
        val trimmed = value.trim()
        trimmed.toLongOrNull()?.let { return it }
        return try {
            Instant.parse(trimmed).toEpochMilli()
        } catch (_: Exception) {
            try {
                OffsetDateTime.parse(trimmed).toInstant().toEpochMilli()
            } catch (_: Exception) {
                error("无法解析日期：$value")
            }
        }
    }

    private fun JSONArray?.orEmpty(): List<Any> =
        this?.let { 0 until it.length() }?.map { get(it) } ?: emptyList()
}
