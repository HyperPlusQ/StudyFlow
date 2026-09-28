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
}
