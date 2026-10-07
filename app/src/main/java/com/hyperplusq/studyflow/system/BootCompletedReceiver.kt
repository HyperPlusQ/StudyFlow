package com.hyperplusq.studyflow.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.hyperplusq.studyflow.StudyFlowApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.LOCKED_BOOT_COMPLETED"
        ) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val app = context.applicationContext as StudyFlowApp
                val enabled = app.settings.settings.first().notificationsEnabled
                val assignments = app.repository.allAssignmentsOnce()
                val subjects = app.repository.subjectsOnce()
                val latestBySubject = assignments.groupBy { it.subjectId }
                    .mapValues { (_, items) -> items.maxOf { it.createdAt } }
                if (enabled) {
                    assignments.forEach { ReminderScheduler.schedule(context, it) }
                    subjects.forEach {
                        ReminderScheduler.scheduleSubject(context, it, latestBySubject[it.id])
                    }
                } else {
                    assignments.forEach { ReminderScheduler.cancel(context, it.id) }
                    subjects.forEach { ReminderScheduler.cancelSubject(context, it.id) }
                }
            } finally {
                pending.finish()
            }
        }
    }
}
