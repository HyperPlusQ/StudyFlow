package com.hyperplusq.studyflow.system

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus

object ReminderScheduler {
    fun schedule(context: Context, assignment: AssignmentEntity) {
        cancel(context, assignment.id)
        val due = assignment.dueDate ?: return
        if (assignment.status == AssignmentStatus.COMPLETED.rawValue) return
        val trigger = due - assignment.reminderLeadHours * 60L * 60L * 1000L
        if (trigger <= System.currentTimeMillis()) return

        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context, assignment.id)
        // A window alarm avoids the Android 12+ exact-alarm permission while preserving reminders.
        manager.setWindow(AlarmManager.RTC_WAKEUP, trigger, 10 * 60 * 1000L, pending)
    }

    fun cancel(context: Context, assignmentId: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context, assignmentId))
    }

    private fun pendingIntent(context: Context, assignmentId: Long): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.hyperplusq.studyflow.REMINDER"
            putExtra("assignment_id", assignmentId)
        }
        return PendingIntent.getBroadcast(
            context,
            assignmentId.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
