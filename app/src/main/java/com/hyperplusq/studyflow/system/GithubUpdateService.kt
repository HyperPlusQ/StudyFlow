package com.hyperplusq.studyflow.system

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class GithubRelease(
    val version: String,
    val htmlUrl: String,
    val publishedAt: String
)

object GithubUpdateService {
    private const val RELEASES_API =
        "https://api.github.com/repos/HyperPlusQ/StudyFlow/releases/latest"

    fun checkLatest(): GithubRelease {
        val connection = URL(RELEASES_API).openConnection() as HttpURLConnection
        connection.connectTimeout = 8_000
        connection.readTimeout = 8_000
        connection.setRequestProperty("Accept", "application/vnd.github+json")
        connection.setRequestProperty("User-Agent", "StudyFlow-Android")
        try {
            check(connection.responseCode in 200..299) {
                "GitHub HTTP ${connection.responseCode}"
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            return GithubRelease(
                version = json.optString("tag_name", "未知版本"),
                htmlUrl = json.optString("html_url", "https://github.com/HyperPlusQ/StudyFlow/releases"),
                publishedAt = json.optString("published_at", "")
            )
        } finally {
            connection.disconnect()
        }
    }

    fun open(context: Context, url: String) {
        try {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: ActivityNotFoundException) {
        }
    }

    /**
     * 判断 [latest] 是否比当前安装的 [current] 版本新。
     * 支持 "v1.6.2"、预发布后缀（如 "1.6.3-beta.1"）等常见写法：先逐段比较数值，
     * 数值相同时没有预发布后缀的一方视为更新（1.6.2 > 1.6.2-beta.3）。
     */
    fun isNewer(latest: String, current: String): Boolean = compareVersion(latest, current) > 0

    /** 返回 [latest] 相对 [current] 的比较结果：>0 更新，0 相同，<0 更旧。 */
    fun compareVersion(latest: String, current: String): Int {
        val a = parseVersion(latest)
        val b = parseVersion(current)
        for (i in 0 until maxOf(a.numbers.size, b.numbers.size)) {
            val x = a.numbers.getOrElse(i) { 0 }
            val y = b.numbers.getOrElse(i) { 0 }
            if (x != y) return x.compareTo(y)
        }
        return when {
            a.prerelease == b.prerelease -> 0
            a.prerelease -> -1
            else -> 1
        }
    }

    private data class ParsedVersion(val numbers: List<Int>, val prerelease: Boolean)

    private fun parseVersion(value: String): ParsedVersion {
        val trimmed = value.trim().removePrefix("v").removePrefix("V")
        val core = trimmed.substringBefore('+')
        val prerelease = core.contains('-')
        val numbers = core.substringBefore('-')
            .split('.')
            .map { part -> part.takeWhile(Char::isDigit).toIntOrNull() ?: 0 }
        return ParsedVersion(numbers, prerelease)
    }
}
