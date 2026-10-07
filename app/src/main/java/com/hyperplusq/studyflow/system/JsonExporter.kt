package com.hyperplusq.studyflow.system

import android.content.Context
import android.net.Uri
import android.util.Base64
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import java.nio.charset.StandardCharsets
import org.json.JSONArray
import org.json.JSONObject

/** 生成跨平台 StudyFlow 快照；所有内部数字主键都会稳定映射为 UUID。 */
object JsonExporter {
    /** 将数据库内容写入 ZIP；JSON 与图片附件封装在同一备份中。 */
    suspend fun export(context: Context, uri: Uri, repository: StudyRepository) {
        val assignments = repository.assignmentsOnce()
        val document = buildDocument(repository, assignments)
        val entries = mutableListOf(
            "studyflow.json" to document.toString(2).toByteArray(StandardCharsets.UTF_8)
        )
        assignments.forEach { item ->
            val assignmentId = stableId("assignment", item.assignment.id)
            item.attachments.forEach { attachment ->
                val attachmentId = stableId("attachment", attachment.id)
                val path = "attachments/$assignmentId/$attachmentId.${BackupArchive.fileExtension(attachment.mimeType)}"
                entries += path to attachment.imageData
            }
        }
        val archive = BackupArchive.create(entries)
        context.contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(archive)
        } ?: error("无法打开导出文件")
    }

    /** 构建可由 macOS/iOS/Android 共同读取的 JSON 文档。 */
    suspend fun buildDocument(
        repository: StudyRepository,
        assignments: List<com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks>
    ): JSONObject {
        val subjects = repository.subjectsOnce()
        val timeBlocks = repository.timeBlocksOnce()
        val history = repository.submissionHistoryOnce()

        return JSONObject().apply {
            put("format", "StudyFlow")
            put("formatVersion", 1)
            put("schemaVersion", 2)
            put("app", "StudyFlow")
            put("platform", "Android")
            put("exportedAt", System.currentTimeMillis())
            put("subjects", JSONArray().apply {
                subjects.forEach { subject ->
                    put(JSONObject().apply {
                        put("id", stableId("subject", subject.id))
                        put("name", subject.name)
                        put("symbol", subject.symbol)
                        put("colorHex", subject.colorHex)
                        put("parentId", subject.parentId?.let { stableId("subject", it) } ?: JSONObject.NULL)
                        put("sortOrder", subject.sortOrder)
                        put("createdAt", subject.createdAt)
                        put("assignmentIntervalDays", subject.assignmentIntervalDays ?: JSONObject.NULL)
                        put("lastAssignmentRegisteredAt", subject.lastAssignmentRegisteredAt ?: JSONObject.NULL)
                    })
                }
            })
            put("assignments", JSONArray().apply {
                assignments.forEach { item ->
                    val assignment = item.assignment
                    put(JSONObject().apply {
                        put("id", stableId("assignment", assignment.id))
                        put("title", assignment.title)
                        put("details", assignment.details)
                        put("dueDate", assignment.dueDate ?: JSONObject.NULL)
                        put("submissionMethod", assignment.submissionMethod)
                        put("subjectId", assignment.subjectId?.let { stableId("subject", it) } ?: JSONObject.NULL)
                        put("priority", assignment.priority)
                        put(
                            "status",
                            if (assignment.status == AssignmentStatus.COMPLETED.rawValue) "completed" else "active"
                        )
                        put("weight", assignment.weight)
                        put("reminderLeadHours", assignment.reminderLeadHours)
                        put("createdAt", assignment.createdAt)
                        put("updatedAt", assignment.updatedAt)
                        put("completedAt", assignment.completedAt ?: JSONObject.NULL)
                        // 日历事件标识属于平台私有值，跨端导入后由各端重建。
                        put("calendarEventIdentifier", JSONObject.NULL)
                        put("subtasks", JSONArray().apply {
                            item.subtasks.forEach { subtask ->
                                put(JSONObject().apply {
                                    put("id", stableId("subtask", subtask.id))
                                    put("title", subtask.title)
                                    put("isCompleted", subtask.isCompleted)
                                    put("sortOrder", subtask.sortOrder)
                                })
                            }
                        })
                        put("attachments", JSONArray().apply {
                            item.attachments.forEach { attachment ->
                                put(JSONObject().apply {
                                    put("id", stableId("attachment", attachment.id))
                                    put("fileName", attachment.fileName)
                                    put("mimeType", attachment.mimeType)
                                    put(
                                        "imageData",
                                        Base64.encodeToString(attachment.imageData, Base64.NO_WRAP)
                                    )
                                    put("createdAt", attachment.createdAt)
                                })
                            }
                        })
                    })
                }
            })
            put("timeBlocks", JSONArray().apply {
                timeBlocks.forEach { block ->
                    put(JSONObject().apply {
                        put("id", stableId("timeblock", block.id))
                        put("title", block.title)
                        put("assignmentId", block.assignmentId?.let { stableId("assignment", it) } ?: JSONObject.NULL)
                        put("subjectId", block.subjectId?.let { stableId("subject", it) } ?: JSONObject.NULL)
                        put("startDate", block.startDate)
                        put("durationMinutes", block.durationMinutes)
                        put("notes", block.notes)
                        put("createdAt", block.createdAt)
                    })
                }
            })
            put("submissionHistory", JSONArray().apply {
                history.forEach { entry ->
                    put(JSONObject().apply {
                        put("id", stableId("history", entry.id))
                        put("subjectId", stableId("subject", entry.subjectId))
                        put("value", entry.method)
                        put("method", entry.method)
                        put("lastUsedAt", entry.lastUsedAt)
                    })
                }
            })
        }
    }

    /** 用命名空间 UUID 保证同一行数据在多次导出中保持相同标识。 */
    internal fun stableId(kind: String, rawId: Long): String =
        java.util.UUID.nameUUIDFromBytes("StudyFlow:$kind:$rawId".toByteArray(StandardCharsets.UTF_8))
            .toString()
            .uppercase()
}
