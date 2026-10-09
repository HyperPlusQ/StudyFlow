package com.hyperplusq.studyflow.system

import java.time.Instant
import java.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 恢复备份时图片附件的异常处理：JSON 内 Base64 优先、ZIP 条目回退、
 * 完全无法恢复的附件只跳过该条，不影响其余数据导入。
 *
 * 跑在真机/模拟器上，因为解析依赖平台自带的 org.json 实现。
 */
@RunWith(AndroidJUnit4::class)
class JsonImporterParseTest {
    private val image = byteArrayOf(1, 2, 3, 4, 5, 6, 7)
    private val encodedImage: String = Base64.getEncoder().encodeToString(image)

    private fun attachmentJson(
        id: String,
        imageData: String?,
        fileName: String? = "photo.jpg"
    ): String = buildString {
        append("{")
        append("\"id\":\"$id\",")
        if (fileName != null) append("\"fileName\":\"$fileName\",")
        append("\"mimeType\":\"image/jpeg\",")
        append("\"createdAt\":1700000000000")
        if (imageData != null) append(",\"imageData\":\"$imageData\"")
        append("}")
    }

    private fun documentJson(attachments: String, dueDate: String = "1700000000000"): String = """
        {
          "format": "StudyFlow",
          "schemaVersion": 2,
          "app": "StudyFlow",
          "subjects": [],
          "assignments": [
            {
              "id": "A-1",
              "title": "复习",
              "dueDate": $dueDate,
              "createdAt": 1700000000000,
              "updatedAt": 1700000000000,
              "subtasks": [],
              "attachments": [$attachments]
            }
          ],
          "timeBlocks": [],
          "submissionHistory": []
        }
    """.trimIndent()

    @Test
    fun imageDataIsDecodedFromJson() {
        val document = JsonImporter.parse(
            documentJson(attachmentJson("I-1", encodedImage))
        ) { _, _ -> null }
        JsonImporter.validate(document)

        assertEquals(0, document.skippedAttachments)
        assertArrayEquals(image, document.assignments.single().attachments.single().imageData)
    }

    @Test
    fun missingImageDataFallsBackToArchiveEntry() {
        val document = JsonImporter.parse(
            documentJson(attachmentJson("I-1", imageData = null))
        ) { assignmentRawId, attachmentRawId ->
            if (assignmentRawId == "A-1" && attachmentRawId == "I-1") image else null
        }
        JsonImporter.validate(document)

        assertEquals(0, document.skippedAttachments)
        assertArrayEquals(image, document.assignments.single().attachments.single().imageData)
    }

    @Test
    fun damagedImageDataFallsBackToArchiveEntry() {
        val document = JsonImporter.parse(
            documentJson(attachmentJson("I-1", imageData = "!!!"))
        ) { _, _ -> image }
        JsonImporter.validate(document)

        assertEquals(0, document.skippedAttachments)
        assertArrayEquals(image, document.assignments.single().attachments.single().imageData)
    }

    @Test
    fun unrecoverableAttachmentIsSkippedWithoutFailingImport() {
        val attachments = listOf(
            attachmentJson("I-1", imageData = null),
            attachmentJson("I-2", encodedImage)
        ).joinToString(",")

        val document = JsonImporter.parse(documentJson(attachments)) { _, _ -> null }
        JsonImporter.validate(document)

        assertEquals(1, document.skippedAttachments)
        val restored = document.assignments.single().attachments
        assertEquals(listOf("I-2"), restored.map { it.rawId })
        assertArrayEquals(image, restored.single().imageData)
    }

    @Test
    fun attachmentWithoutIdOrFileNameIsSkippedGracefully() {
        val document = JsonImporter.parse(
            documentJson(
                """{"mimeType":"image/jpeg","imageData":"$encodedImage"}"""
            )
        ) { _, _ -> null }

        assertEquals(1, document.skippedAttachments)
        assertTrue(document.assignments.single().attachments.isEmpty())
    }

    @Test
    fun crossPlatformSnapshotWithIsoDatesParses() {
        val document = JsonImporter.parse(
            documentJson(
                attachmentJson("I-1", encodedImage),
                dueDate = "\"2026-10-08T12:00:00Z\""
            )
        ) { _, _ -> null }
        JsonImporter.validate(document)

        assertEquals(
            Instant.parse("2026-10-08T12:00:00Z").toEpochMilli(),
            document.assignments.single().dueDate
        )
    }
}
