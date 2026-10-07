package com.hyperplusq.studyflow

import android.app.Application
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
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

    /** 应用启动时统一恢复截止提醒和科目的作业布置提醒。 */
    private fun scheduleExistingReminders() {
        applicationScope.launch {
            try {
                val enabled = settings.settings.first().notificationsEnabled
                val assignments = repository.allAssignmentsOnce()
                val subjects = repository.subjectsOnce()
                val latestBySubject = assignments.groupBy { it.subjectId }
                    .mapValues { (_, items) -> items.maxOf { it.createdAt } }
                if (enabled) {
                    assignments.forEach { ReminderScheduler.schedule(this@StudyFlowApp, it) }
                    subjects.forEach {
                        ReminderScheduler.scheduleSubject(
                            this@StudyFlowApp,
                            it,
                            latestBySubject[it.id]
                        )
                    }
                } else {
                    assignments.forEach { ReminderScheduler.cancel(this@StudyFlowApp, it.id) }
                    subjects.forEach { ReminderScheduler.cancelSubject(this@StudyFlowApp, it.id) }
                }
            } catch (_: Exception) {
            }
        }
    }
}
