package com.hyperplusq.studyflow

import android.app.Application
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import com.hyperplusq.studyflow.data.SettingsRepository
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AppDatabase
import com.hyperplusq.studyflow.system.ReminderScheduler
import com.hyperplusq.studyflow.widget.WidgetUpdater

class StudyFlowApp : Application() {
    lateinit var database: AppDatabase
        private set
    lateinit var repository: StudyRepository
        private set
    lateinit var settings: SettingsRepository
        private set
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        database = AppDatabase.get(this)
        repository = StudyRepository(database)
        settings = SettingsRepository(this)
        scheduleExistingReminders()
        WidgetUpdater.requestUpdate(this)
    }

    private fun scheduleExistingReminders() {
        applicationScope.launch {
            try {
                repository.allAssignmentsOnce().forEach { ReminderScheduler.schedule(this@StudyFlowApp, it) }
            } catch (_: Exception) {
            }
        }
    }
}
