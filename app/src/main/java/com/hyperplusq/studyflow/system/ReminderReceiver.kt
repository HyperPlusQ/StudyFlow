package com.hyperplusq.studyflow.system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.hyperplusq.studyflow.StudyFlowApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val subjectId = intent.getLongExtra("subject_id", -1)
        val assignmentId = intent.getLongExtra("assignment_id", -1)
        if (subjectId < 0 && assignmentId < 0) return

        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val permission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                )
                val canPost = permission == PackageManager.PERMISSION_GRANTED ||
                    android.os.Build.VERSION.SDK_INT < 33
                if (!canPost) return@launch

                val app = context.applicationContext as StudyFlowApp
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager

                if (subjectId >= 0) {
                    val subject = app.repository.subject(subjectId) ?: return@launch
                    val interval = subject.assignmentIntervalDays ?: return@launch
                    if (interval <= 0) return@launch
                    createChannel(
                        manager,
                        "subject_assignment_reminders",
                        "作业布置提醒",
                        NotificationManager.IMPORTANCE_HIGH
                    )
                    val notification = android.app.Notification.Builder(
                        context,
                        "subject_assignment_reminders"
                    )
                        .setSmallIcon(android.R.drawable.ic_popup_reminder)
                        .setContentTitle("该登记作业了")
                        .setContentText("“${subject.name}”距离上一次登记作业已过 $interval 天。")
                        .setAutoCancel(true)
                        .build()
                    manager.notify(subjectNotificationId(subject.id), notification)
                } else {
                    val assignment = app.repository.assignment(assignmentId)?.assignment
                        ?: return@launch
                    createChannel(
                        manager,
                        "due_soon",
                        "作业截止提醒",
                        NotificationManager.IMPORTANCE_HIGH
                    )
                    val notification = android.app.Notification.Builder(context, "due_soon")
                        .setSmallIcon(android.R.drawable.ic_popup_reminder)
                        .setContentTitle("作业即将截止")
                        .setContentText(assignment.title)
                        .setAutoCancel(true)
                        .build()
                    manager.notify(assignmentId.toInt(), notification)
                }
            } finally {
                pending.finish()
            }
        }
    }

    private fun createChannel(
        manager: NotificationManager,
        id: String,
        title: String,
        importance: Int
    ) {
        if (manager.getNotificationChannel(id) == null) {
            manager.createNotificationChannel(
                NotificationChannel(id, title, importance)
            )
        }
    }

    private fun subjectNotificationId(subjectId: Long): Int =
        (Int.MAX_VALUE / 2) + subjectId.toInt()
}
