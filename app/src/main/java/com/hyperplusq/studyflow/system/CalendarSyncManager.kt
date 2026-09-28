package com.hyperplusq.studyflow.system

import android.Manifest
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.SubjectEntity
import java.util.TimeZone

object CalendarSyncManager {
    fun hasPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    fun sync(
        context: Context,
        assignment: AssignmentEntity,
        subject: SubjectEntity?,
        alwaysSync: Boolean
    ): Long? {
        if (!hasPermission(context)) return assignment.calendarEventId
        val resolver = context.contentResolver
        val eventId = assignment.calendarEventId
        if (assignment.status == AssignmentStatus.COMPLETED.rawValue ||
            assignment.dueDate == null
        ) {
            if (eventId != null) deleteEvent(context, eventId)
            return null
        }

        val values = eventValues(assignment, subject)
        return if (eventId != null) {
            try {
                resolver.update(
                    CalendarContract.Events.CONTENT_URI,
                    values,
                    "${CalendarContract.Events._ID}=?",
                    arrayOf(eventId.toString())
                )
                eventId
            } catch (_: Exception) {
                createEvent(context, assignment, subject)
            }
        } else if (alwaysSync) {
            createEvent(context, assignment, subject)
        } else {
            null
        }
    }

    fun deleteEvent(context: Context, eventId: Long) {
        if (!hasPermission(context)) return
        try {
            context.contentResolver.delete(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
                null,
                null
            )
        } catch (_: Exception) {
        }
    }

    private fun createEvent(
        context: Context,
        assignment: AssignmentEntity,
        subject: SubjectEntity?
    ): Long? {
        val calendarId = writableCalendarId(context.contentResolver) ?: return null
        val values = eventValues(assignment, subject).apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.DTSTART, assignment.dueDate)
            put(CalendarContract.Events.DTEND, assignment.dueDate)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
        return try {
            context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)?.let {
                ContentUris.parseId(it)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun eventValues(assignment: AssignmentEntity, subject: SubjectEntity?): ContentValues =
        ContentValues().apply {
            put(CalendarContract.Events.TITLE, "作业：${assignment.title}")
            val details = buildString {
                if (subject != null) appendLine("科目：${subject.name}")
                if (assignment.details.isNotBlank()) append(assignment.details)
                if (assignment.submissionMethod.isNotBlank()) {
                    if (isNotEmpty()) appendLine()
                    append("提交方式：${assignment.submissionMethod}")
                }
            }
            put(CalendarContract.Events.DESCRIPTION, details)
            if (assignment.dueDate != null) {
                put(CalendarContract.Events.DTSTART, assignment.dueDate)
                put(CalendarContract.Events.DTEND, assignment.dueDate)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            }
        }

    private fun writableCalendarId(resolver: ContentResolver): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL
        )
        resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            "${CalendarContract.Calendars.VISIBLE}=1 AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR}",
            null,
            "${CalendarContract.Calendars._ID} ASC"
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        return null
    }
}

private object ContextCompat {
    fun checkSelfPermission(context: Context, permission: String): Int =
        context.checkCallingOrSelfPermission(permission)
}
