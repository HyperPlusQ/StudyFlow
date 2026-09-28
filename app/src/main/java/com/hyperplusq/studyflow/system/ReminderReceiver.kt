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
        val assignmentId = intent.getLongExtra("assignment_id", -1)
        if (assignmentId < 0) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val app = context.applicationContext as StudyFlowApp
                val assignment = app.repository.assignment(assignmentId)?.assignment ?: return@launch
                val permission = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                val canPost = permission == PackageManager.PERMISSION_GRANTED ||
                    android.os.Build.VERSION.SDK_INT < 33
                if (!canPost) return@launch

                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (manager.getNotificationChannel("due_soon") == null) {
                    manager.createNotificationChannel(
                        NotificationChannel(
                            "due_soon",
                            "作业截止提醒",
                            NotificationManager.IMPORTANCE_HIGH
                        )
                    )
                }
                val notification = android.app.Notification.Builder(context, "due_soon")
                    .setSmallIcon(android.R.drawable.ic_popup_reminder)
                    .setContentTitle("作业即将截止")
                    .setContentText(assignment.title)
                    .setAutoCancel(true)
                    .build()
                manager.notify(assignmentId.toInt(), notification)
            } finally {
                pending.finish()
            }
        }
    }
}
