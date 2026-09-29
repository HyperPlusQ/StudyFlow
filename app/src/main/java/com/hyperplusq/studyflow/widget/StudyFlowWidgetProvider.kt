package com.hyperplusq.studyflow.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.hyperplusq.studyflow.R
import com.hyperplusq.studyflow.ui.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

abstract class StudyFlowWidgetProvider : AppWidgetProvider() {
    protected abstract val layoutRes: Int
    protected abstract val maxItems: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val pendingResult = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val snapshot = WidgetDataProvider.load(context)
                appWidgetIds.forEach { id ->
                    appWidgetManager.updateAppWidget(
                        id,
                        buildViews(context, id, snapshot)
                    )
                }
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun buildViews(context: Context, widgetId: Int, snapshot: WidgetSnapshot): RemoteViews =
        RemoteViews(context.packageName, layoutRes).apply {
            setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    widgetId,
                    Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            setImageViewResource(R.id.widget_icon, R.mipmap.ic_launcher)
            setTextViewText(
                R.id.widget_title,
                context.getString(com.hyperplusq.studyflow.R.string.app_name)
            )
            setTextViewText(R.id.widget_stats, stats(snapshot))
            bindItems(this, snapshot)
        }

    private fun stats(snapshot: WidgetSnapshot): String {
        val due = if (snapshot.dueTodayCount > 0) " · 今天 ${snapshot.dueTodayCount}" else ""
        val overdue = if (snapshot.overdueCount > 0) " · 逾期 ${snapshot.overdueCount}" else ""
        return "进行中 ${snapshot.activeCount}$due$overdue"
    }

    private fun bindItems(views: RemoteViews, snapshot: WidgetSnapshot) {
        if (maxItems == 1) {
            val item = snapshot.items.firstOrNull()
            views.setViewVisibility(
                R.id.widget_task_title,
                if (item == null) android.view.View.GONE else android.view.View.VISIBLE
            )
            views.setViewVisibility(
                R.id.widget_task_subtitle,
                if (item == null) android.view.View.GONE else android.view.View.VISIBLE
            )
            views.setViewVisibility(
                R.id.widget_empty,
                if (item == null) android.view.View.VISIBLE else android.view.View.GONE
            )
            if (item != null) {
                views.setTextViewText(R.id.widget_task_title, item.title)
                views.setTextViewText(R.id.widget_task_subtitle, item.subtitle)
            } else {
                views.setTextViewText(R.id.widget_empty, "暂无进行中作业")
            }
            return
        }

        val titleIds = listOf(
            R.id.widget_task_title_1,
            R.id.widget_task_title_2,
            R.id.widget_task_title_3,
            R.id.widget_task_title_4,
            R.id.widget_task_title_5
        )
        val subtitleIds = listOf(
            R.id.widget_task_subtitle_1,
            R.id.widget_task_subtitle_2,
            R.id.widget_task_subtitle_3,
            R.id.widget_task_subtitle_4,
            R.id.widget_task_subtitle_5
        )
        for (index in 1..minOf(maxItems, titleIds.size)) {
            val item = snapshot.items.getOrNull(index - 1)
            val titleId = titleIds[index - 1]
            val subtitleId = subtitleIds[index - 1]
            views.setViewVisibility(
                titleId,
                if (item == null) android.view.View.GONE else android.view.View.VISIBLE
            )
            views.setViewVisibility(
                subtitleId,
                if (item == null) android.view.View.GONE else android.view.View.VISIBLE
            )
            if (item != null) {
                views.setTextViewText(titleId, item.title)
                views.setTextViewText(subtitleId, item.subtitle)
            }
        }
        views.setViewVisibility(
            R.id.widget_empty,
            if (snapshot.items.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE
        )
        if (snapshot.items.isEmpty()) {
            views.setTextViewText(R.id.widget_empty, "暂无进行中作业")
        }
    }
}

object WidgetUpdater {
    fun requestUpdate(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val providers = listOf(
            SmallWidgetProvider::class.java,
            MediumWidgetProvider::class.java,
            LargeWidgetProvider::class.java
        )
        providers.forEach { providerClass ->
            val component = ComponentName(context, providerClass)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return@forEach
            val intent = Intent(context, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
