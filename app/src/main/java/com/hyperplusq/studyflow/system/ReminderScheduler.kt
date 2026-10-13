package com.hyperplusq.studyflow.system

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.SubjectEntity

object ReminderScheduler {
    private const val ASSIGNMENT_ACTION = "com.hyperplusq.studyflow.REMINDER"
    private const val SUBJECT_ACTION = "com.hyperplusq.studyflow.SUBJECT_ASSIGNMENT_REMINDER"
    private const val SUBJECT_REQUEST_BASE = 1_000_000

    /** 按提前提醒时长安排截止提醒。 */
    fun schedule(context: Context, assignment: AssignmentEntity) {
        cancel(context, assignment.id)
        val due = assignment.dueDate ?: return
        if (assignment.status == AssignmentStatus.COMPLETED.rawValue) return
        val trigger = due - assignment.reminderLeadHours * 60L * 60L * 1000L
        if (trigger <= System.currentTimeMillis()) return

        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // 窗口型闹钟可在不申请 Android 12 精确闹钟权限的情况下提供可靠提醒。
        manager.setWindow(
            AlarmManager.RTC_WAKEUP,
            trigger,
            10 * 60 * 1000L,
            pendingIntent(context, assignment.id)
        )
    }

    /** 取消指定作业尚未触发的提醒。 */
    fun cancel(context: Context, assignmentId: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context, assignmentId))
    }

    /**
     * 安排科目的“作业布置间隔”提醒。
     * 从最近一次登记本科目作业起计算；从未登记时从科目创建时间起计算。
     */
    fun scheduleSubject(
        context: Context,
        subject: SubjectEntity,
        latestAssignmentCreatedAt: Long? = null
    ) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = subjectPendingIntent(context, subject.id)
        val interval = subject.assignmentIntervalDays
        if (interval == null || interval <= 0) {
            manager.cancel(pending)
            return
        }

        val baseline = subject.lastAssignmentRegisteredAt
            ?: latestAssignmentCreatedAt
            ?: subject.createdAt
        // 已经逾期的提醒在应用启动后短暂延迟触发，避免启动瞬间连续弹出通知。
        val target = maxOf(baseline + interval * 86_400_000L, System.currentTimeMillis() + 1_500L)
        manager.setWindow(
            AlarmManager.RTC_WAKEUP,
            target,
            60 * 1000L,
            pending
        )
    }

    fun cancelSubject(context: Context, subjectId: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(subjectPendingIntent(context, subjectId))
    }

    /** 把 64 位自增 id 折叠成稳定的 32 位值，避免直接 Long→Int 截断丢失高位后碰撞。 */
    internal fun stableReminderId(id: Long): Int = (id xor (id ushr 32)).toInt()

    private fun pendingIntent(context: Context, assignmentId: Long): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ASSIGNMENT_ACTION
            putExtra("assignment_id", assignmentId)
        }
        return PendingIntent.getBroadcast(
            context,
            stableReminderId(assignmentId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun subjectPendingIntent(context: Context, subjectId: Long): PendingIntent {
        // 用稳定的 32 位折叠值并限制到 30 位，再加上基数，避免溢出成负数。
        val requestCode = SUBJECT_REQUEST_BASE + (stableReminderId(subjectId) and 0x3FFFFFFF)
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = SUBJECT_ACTION
            putExtra("subject_id", subjectId)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
