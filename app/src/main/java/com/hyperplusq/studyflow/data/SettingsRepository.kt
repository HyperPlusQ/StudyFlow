package com.hyperplusq.studyflow.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "studyflow_settings")

data class AppSettings(
    val alwaysSyncCalendar: Boolean = false,
    val notificationsEnabled: Boolean = false,
    val lastGithubResponse: String = ""
)

class SettingsRepository(private val context: Context) {
    private object Keys {
        val ALWAYS_SYNC_CALENDAR = booleanPreferencesKey("always_sync_calendar")
        val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
        val LAST_GITHUB_RESPONSE = stringPreferencesKey("last_github_response")
    }

    val settings: Flow<AppSettings> = context.dataStore.data.map { prefs ->
        AppSettings(
            alwaysSyncCalendar = prefs[Keys.ALWAYS_SYNC_CALENDAR] ?: false,
            notificationsEnabled = prefs[Keys.NOTIFICATIONS_ENABLED] ?: false,
            lastGithubResponse = prefs[Keys.LAST_GITHUB_RESPONSE] ?: ""
        )
    }

    suspend fun setAlwaysSyncCalendar(enabled: Boolean) {
        context.dataStore.edit { it[Keys.ALWAYS_SYNC_CALENDAR] = enabled }
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.dataStore.edit { it[Keys.NOTIFICATIONS_ENABLED] = enabled }
    }

    suspend fun setLastGithubResponse(value: String) {
        context.dataStore.edit { it[Keys.LAST_GITHUB_RESPONSE] = value }
    }
}
