package com.hyperplusq.studyflow.system

import android.content.Context
import android.net.Uri
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AppDatabase
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AttachmentEntity
import com.hyperplusq.studyflow.data.db.SubjectEntity
import java.io.File
import java.nio.charset.StandardCharsets
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * ZIP 备份「打包 → 恢复」的端到端校验：导出的包必须同时包含 JSON 与原始图片文件，
 * 并且通过真实 import 路径恢复后图片字节完全一致。
 */
@RunWith(AndroidJUnit4::class)
class BackupRoundTripTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    private val image = byteArrayOf(
        0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 9, 8, 7, 6, 5
    )

    private fun newRepository(): StudyRepository =
        StudyRepository(Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).build())

    private suspend fun writeArchive(archive: ByteArray): File {
        val file = File(context.cacheDir, "studyflow-round-trip.zip")
        file.writeBytes(archive)
        return file
    }

    @Test
    fun attachmentsSurviveExportAndImport() = runBlocking {
        val source = newRepository()
        val subjectId = source.saveSubject(SubjectEntity(name = "数学"))
        source.saveAssignment(
            AssignmentEntity(title = "复习函数", subjectId = subjectId),
            attachments = listOf(
                AttachmentEntity(
                    assignmentId = 0,
                    fileName = "photo.jpg",
                    mimeType = "image/jpeg",
                    imageData = image
                )
            )
        )

        val archive = JsonExporter.buildArchive(source)
        assertTrue(BackupArchive.isArchive(archive))

        // JSON 内嵌 Base64 图片，同时 ZIP 里也保留原始图片文件。
        val json = String(BackupArchive.readDocument(archive), StandardCharsets.UTF_8)
        assertTrue(json.contains("\"imageData\""))
        val fileEntry = BackupArchive.findEntry(archive) {
            it.startsWith("attachments/") && it.endsWith(".jpg")
        }
        assertNotNull(fileEntry)
        assertArrayEquals(image, fileEntry)

        val file = writeArchive(archive)
        try {
            val target = newRepository()
            val summary = JsonImporter.import(context, Uri.fromFile(file), target)

            assertEquals(1, summary.assignments)
            assertEquals(1, summary.attachments)
            assertEquals(0, summary.skippedAttachments)

            val restored = target.assignmentsOnce().single()
            assertEquals("复习函数", restored.assignment.title)
            assertEquals(1, restored.attachments.size)
            assertEquals("photo.jpg", restored.attachments.single().fileName)
            assertArrayEquals(image, restored.attachments.single().imageData)
        } finally {
            file.delete()
        }
    }

    @Test
    fun missingJsonImageDataIsRecoveredFromArchiveEntry() = runBlocking {
        // JSON 里没有任何图片数据时，必须能从 attachments/ 条目恢复，而不是丢图或失败。
        val json = """
            {
              "format": "StudyFlow",
              "schemaVersion": 2,
              "app": "StudyFlow",
              "subjects": [],
              "assignments": [
                {
                  "id": "A-1",
                  "title": "没有图片字段的备份",
                  "createdAt": 1700000000000,
                  "updatedAt": 1700000000000,
                  "subtasks": [],
                  "attachments": [
                    {"id": "I-1", "fileName": "photo.jpg", "mimeType": "image/jpeg", "createdAt": 1700000000000}
                  ]
                }
              ],
              "timeBlocks": [],
              "submissionHistory": []
            }
        """.trimIndent()

        val archive = BackupArchive.create(
            listOf(
                "studyflow.json" to json.toByteArray(StandardCharsets.UTF_8),
                "attachments/A-1/I-1.jpg" to image
            )
        )

        val file = writeArchive(archive)
        try {
            val target = newRepository()
            val summary = JsonImporter.import(context, Uri.fromFile(file), target)

            assertEquals(0, summary.skippedAttachments)
            assertEquals(1, summary.attachments)
            assertArrayEquals(
                image,
                target.assignmentsOnce().single().attachments.single().imageData
            )
        } finally {
            file.delete()
        }
    }

    @Test
    fun unreadableAttachmentIsSkippedAndReported() = runBlocking {
        // 既没有图片数据、ZIP 里也没有对应文件：跳过该附件，其余数据照常导入。
        val json = """
            {
              "format": "StudyFlow",
              "schemaVersion": 2,
              "app": "StudyFlow",
              "subjects": [],
              "assignments": [
                {
                  "id": "A-1",
                  "title": "图片丢失的备份",
                  "createdAt": 1700000000000,
                  "updatedAt": 1700000000000,
                  "subtasks": [],
                  "attachments": [
                    {"id": "I-1", "fileName": "photo.jpg", "mimeType": "image/jpeg", "createdAt": 1700000000000},
                    {"id": "I-2", "fileName": "ok.jpg", "mimeType": "image/jpeg", "imageData": "AQID", "createdAt": 1700000000000}
                  ]
                }
              ],
              "timeBlocks": [],
              "submissionHistory": []
            }
        """.trimIndent()

        val archive = BackupArchive.create(
            listOf("studyflow.json" to json.toByteArray(StandardCharsets.UTF_8))
        )

        val file = writeArchive(archive)
        try {
            val target = newRepository()
            val summary = JsonImporter.import(context, Uri.fromFile(file), target)

            assertEquals(1, summary.skippedAttachments)
            assertEquals(1, summary.attachments)
            val restored = target.assignmentsOnce().single().attachments
            assertEquals(listOf("ok.jpg"), restored.map { it.fileName })
            assertArrayEquals(byteArrayOf(1, 2, 3), restored.single().imageData)
        } finally {
            file.delete()
        }
    }
}
