package com.hyperplusq.studyflow.system

import android.content.Context
import android.net.Uri
import com.hyperplusq.studyflow.data.StudyRepository
import org.json.JSONArray
import org.json.JSONObject

object JsonExporter {
    /** 将数据库内容写入用户选择的 JSON 文件。 */
    suspend fun export(context: Context, uri: Uri, repository: StudyRepository) {
        val subjects = repository.subjectsOnce()
        val assignments = repository.assignmentsOnce()
        val timeBlocks = repository.timeBlocksOnce()
        val history = repository.submissionHistoryOnce()

        val root = JSONObject().apply {
            put("schemaVersion", 1)
            put("app", "StudyFlow")
            put("platform", "Android")
            put("exportedAt", System.currentTimeMillis())
            put("subjects", JSONArray().apply {
                subjects.forEach { subject ->
                    put(JSONObject().apply {
                        put("id", subject.id)
                        put("name", subject.name)
                        put("symbol", subject.symbol)
                        put("colorHex", subject.colorHex)
                        put("parentId", subject.parentId ?: JSONObject.NULL)
                        put("sortOrder", subject.sortOrder)
                        put("createdAt", subject.createdAt)
                    })
                }
            })
            put("assignments", JSONArray().apply {
                assignments.forEach { item ->
                    put(JSONObject().apply {
                        put("id", item.assignment.id)
                        put("title", item.assignment.title)
                        put("details", item.assignment.details)
                        put("dueDate", item.assignment.dueDate ?: JSONObject.NULL)
                        put("submissionMethod", item.assignment.submissionMethod)
                        put("subjectId", item.assignment.subjectId ?: JSONObject.NULL)
                        put("priority", item.assignment.priority)
                        put("status", item.assignment.status)
                        put("weight", item.assignment.weight)
                        put("reminderLeadHours", item.assignment.reminderLeadHours)
                        put("createdAt", item.assignment.createdAt)
                        put("updatedAt", item.assignment.updatedAt)
                        put("completedAt", item.assignment.completedAt ?: JSONObject.NULL)
                        put("calendarEventId", item.assignment.calendarEventId ?: JSONObject.NULL)
                        put("subtasks", JSONArray().apply {
                            item.subtasks.forEach { subtask ->
                                put(JSONObject().apply {
                                    put("id", subtask.id)
                                    put("title", subtask.title)
                                    put("isCompleted", subtask.isCompleted)
                                    put("sortOrder", subtask.sortOrder)
                                })
                            }
                        })
                    })
                }
            })
            put("timeBlocks", JSONArray().apply {
                timeBlocks.forEach { block ->
                    put(JSONObject().apply {
                        put("id", block.id)
                        put("title", block.title)
                        put("assignmentId", block.assignmentId ?: JSONObject.NULL)
                        put("subjectId", block.subjectId ?: JSONObject.NULL)
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
                        put("id", entry.id)
                        put("subjectId", entry.subjectId)
                        put("method", entry.method)
                        put("lastUsedAt", entry.lastUsedAt)
                    })
                }
            })
        }

        context.contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(root.toString(2).toByteArray(Charsets.UTF_8))
        } ?: error("无法打开导出文件")
    }
}
