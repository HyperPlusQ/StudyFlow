package com.hyperplusq.studyflow.system

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Patterns

enum class SubmissionKind { URL, EMAIL, OTHER }

object SubmissionLink {
    /** 识别提交方式是网址、邮箱还是普通文本。 */
    fun classify(value: String): SubmissionKind {
        val text = value.trim()
        return when {
            text.startsWith("mailto:", ignoreCase = true) -> SubmissionKind.EMAIL
            Patterns.EMAIL_ADDRESS.matcher(text).matches() -> SubmissionKind.EMAIL
            text.startsWith("http://", ignoreCase = true) ||
                text.startsWith("https://", ignoreCase = true) -> SubmissionKind.URL
            else -> SubmissionKind.OTHER
        }
    }

    /** 用系统浏览器或邮件应用打开提交方式。 */
    fun open(context: Context, value: String): Boolean {
        val text = value.trim()
        if (text.isBlank()) return false
        val uri = when (classify(text)) {
            SubmissionKind.EMAIL ->
                if (text.startsWith("mailto:", ignoreCase = true)) Uri.parse(text)
                else Uri.parse("mailto:" + Uri.encode(text))
            SubmissionKind.URL -> Uri.parse(text)
            SubmissionKind.OTHER -> return false
        }
        val intent = Intent(
            if (classify(text) == SubmissionKind.EMAIL) Intent.ACTION_SENDTO else Intent.ACTION_VIEW,
            uri
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
