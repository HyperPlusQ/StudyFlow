package com.hyperplusq.studyflow.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.hyperplusq.studyflow.StudyFlowApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
                app.repository.allAssignmentsOnce().forEach {
                    ReminderScheduler.schedule(context, it)
                }
            } finally {
                pending.finish()
            }
        }
    }
}
