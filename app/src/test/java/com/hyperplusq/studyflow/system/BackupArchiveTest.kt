package com.hyperplusq.studyflow.system

import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * ZIP 备份打包/读取的核心校验：JSON 与图片附件条目都必须能完整往返，
 * 且 macOS/iOS 读取器依赖的 Store 方式与 CRC 不能被破坏。
 */
class BackupArchiveTest {
    private val json = """{"format":"StudyFlow","schemaVersion":2}"""
    private val image = byteArrayOf(
        0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 1, 2, 3, 4
    )

    @Test
    fun archiveRoundTripKeepsJsonAndAttachment() {
        val archive = BackupArchive.create(
            listOf(
                "studyflow.json" to json.toByteArray(),
                "attachments/A-1/IMG-1.jpg" to image
            )
        )

        assertTrue(BackupArchive.isArchive(archive))
        assertArrayEquals(json.toByteArray(), BackupArchive.readDocument(archive))
        assertArrayEquals(
            image,
            BackupArchive.findEntry(archive) { it.startsWith("attachments/A-1/IMG-1") }
        )
        assertNull(BackupArchive.findEntry(archive) { it.startsWith("attachments/missing") })
    }

    @Test
    fun entriesAreStoredWithValidCrc() {
        val archive = BackupArchive.create(
            listOf(
                "studyflow.json" to json.toByteArray(),
                "attachments/A-1/IMG-1.png" to image
            )
        )

        val entries = mutableListOf<ZipEntry>()
        val payloads = mutableMapOf<String, ByteArray>()
        ZipInputStream(archive.inputStream()).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                entries += entry
                payloads[entry.name] = zip.readBytes()
            }
        }

        assertEquals(listOf("studyflow.json", "attachments/A-1/IMG-1.png"), entries.map { it.name })
        entries.forEach { entry ->
            assertEquals(ZipEntry.STORED, entry.method)
            val payload = payloads.getValue(entry.name)
            assertEquals(payload.size.toLong(), entry.size)
            assertEquals(payload.size.toLong(), entry.compressedSize)
        }
    }

    @Test
    fun plainJsonDocumentPassesThrough() {
        val bytes = json.toByteArray()
        assertFalse(BackupArchive.isArchive(bytes))
        assertArrayEquals(bytes, BackupArchive.readDocument(bytes))
        assertNull(BackupArchive.findEntry(bytes) { true })
    }

    @Test(expected = IllegalStateException::class)
    fun archiveWithoutDocumentIsRejected() {
        BackupArchive.readDocument(
            BackupArchive.create(listOf("readme.txt" to "hi".toByteArray()))
        )
    }

    @Test
    fun attachmentExtensionFollowsMimeType() {
        assertEquals("png", BackupArchive.fileExtension("image/png"))
        assertEquals("heic", BackupArchive.fileExtension("image/heic"))
        assertEquals("jpg", BackupArchive.fileExtension("image/jpeg"))
        assertEquals("jpg", BackupArchive.fileExtension("application/octet-stream"))
    }
}
