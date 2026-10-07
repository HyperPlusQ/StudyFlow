package com.hyperplusq.studyflow.system

import java.io.ByteArrayOutputStream
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * 生成 StudyFlow ZIP 备份。条目使用 Store 方式写入，
 * 因而 macOS/iOS 的轻量 ZIP 读取器可以直接校验 CRC 并读取。
 */
object BackupArchive {
    fun create(entries: List<Pair<String, ByteArray>>): ByteArray {
        require(entries.isNotEmpty()) { "ZIP 备份不能为空" }
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { zip ->
            entries.forEach { (path, data) ->
                val entry = ZipEntry(path).apply {
                    method = ZipEntry.STORED
                    size = data.size.toLong()
                    compressedSize = data.size.toLong()
                    crc = CRC32().apply { update(data) }.value
                }
                zip.putNextEntry(entry)
                zip.write(data)
                zip.closeEntry()
            }
        }
        return output.toByteArray()
    }

    /** 读取 ZIP 中的 StudyFlow JSON，兼容旧版纯 JSON。 */
    fun readDocument(bytes: ByteArray): ByteArray {
        if (!isArchive(bytes)) return bytes
        ZipInputStream(bytes.inputStream()).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (!entry.isDirectory && entry.name == "studyflow.json") {
                    return zip.readBytes()
                }
            }
        }
        error("ZIP 备份中缺少 studyflow.json")
    }

    fun isArchive(bytes: ByteArray): Boolean =
        bytes.size >= 4 &&
            bytes[0] == 'P'.code.toByte() &&
            bytes[1] == 'K'.code.toByte() &&
            bytes[2].toInt() == 3 &&
            bytes[3].toInt() == 4

    fun fileExtension(mimeType: String): String = when (mimeType.lowercase()) {
        "image/png" -> "png"
        "image/heic", "image/heif" -> "heic"
        "image/gif" -> "gif"
        "image/webp" -> "webp"
        "image/bmp" -> "bmp"
        else -> "jpg"
    }
}
