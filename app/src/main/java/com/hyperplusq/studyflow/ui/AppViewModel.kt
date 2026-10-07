package com.hyperplusq.studyflow.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.hyperplusq.studyflow.StudyFlowApp
import com.hyperplusq.studyflow.data.AppSettings
import com.hyperplusq.studyflow.data.SettingsRepository
import com.hyperplusq.studyflow.data.StudyRepository
import com.hyperplusq.studyflow.data.db.AssignmentEntity
import com.hyperplusq.studyflow.data.db.AssignmentStatus
import com.hyperplusq.studyflow.data.db.AssignmentWithSubtasks
import com.hyperplusq.studyflow.data.db.AttachmentEntity
import com.hyperplusq.studyflow.data.db.SubjectEntity
import com.hyperplusq.studyflow.data.db.SubtaskEntity
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import com.hyperplusq.studyflow.system.CalendarSyncManager
import com.hyperplusq.studyflow.system.JsonExporter
import com.hyperplusq.studyflow.system.JsonImporter
import com.hyperplusq.studyflow.system.ReminderScheduler
import com.hyperplusq.studyflow.widget.WidgetUpdater
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class AppUiState(
    val subjects: List<SubjectEntity> = emptyList(),
    val assignments: List<AssignmentWithSubtasks> = emptyList(),
    val timeBlocks: List<TimeBlockEntity> = emptyList(),
    val submissionHistory: List<com.hyperplusq.studyflow.data.db.SubmissionHistoryEntity> = emptyList(),
    val settings: AppSettings = AppSettings()
)

class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application as StudyFlowApp
    private val repository: StudyRepository = app.repository
    private val settingsRepository: SettingsRepository = app.settings

    val uiState: StateFlow<AppUiState> = combine(
        repository.subjects,
        repository.assignments,
        repository.timeBlocks,
        repository.submissionHistory,
        settingsRepository.settings
    ) { subjects, assignments, blocks, history, settings ->
        AppUiState(subjects, assignments, blocks, history, settings)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppUiState())

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message

    private val _exporting = MutableStateFlow(false)
    val exporting: StateFlow<Boolean> = _exporting

    private val _importing = MutableStateFlow(false)
    val importing: StateFlow<Boolean> = _importing

    private var messageJob: Job? = null

    fun announce(text: String) {
        messageJob?.cancel()
        _message.value = text
        messageJob = viewModelScope.launch {
            kotlinx.coroutines.delay(3_500)
            _message.value = null
        }
    }

    fun subject(id: Long?): SubjectEntity? = uiState.value.subjects.firstOrNull { it.id == id }

    /** 保存新建或修改后的科目。 */
    fun saveSubject(subject: SubjectEntity) = launchOp("已保存科目") {
        repository.saveSubject(subject)
        // 重新读取数据库，保留仓储层自动补全的登记时间后再刷新提醒。
        refreshSubjectReminders(settingsRepository.settings.first().notificationsEnabled)
    }

    /**
     * 从数据库读取最新科目与作业，统一恢复或取消“作业布置间隔”提醒。
     * 导入的旧数据可能缺少登记时间，因此用该科目最新作业的创建时间兜底。
     */
    private suspend fun refreshSubjectReminders(enabled: Boolean) {
        val assignments = repository.allAssignmentsOnce()
        val subjects = repository.subjectsOnce()
        val latestBySubject = assignments
            .groupBy { it.subjectId }
            .mapValues { (_, items) -> items.maxOf { it.createdAt } }

        if (enabled) {
            subjects.forEach { subject ->
                ReminderScheduler.scheduleSubject(
                    getApplication(),
                    subject,
                    latestBySubject[subject.id]
                )
            }
        } else {
            subjects.forEach { ReminderScheduler.cancelSubject(getApplication(), it.id) }
        }
    }

    /** 删除科目并保留关联作业。 */
    fun deleteSubject(subject: SubjectEntity) = launchOp("已删除科目") {
        ReminderScheduler.cancelSubject(getApplication(), subject.id)
        repository.deleteSubject(subject)
    }

    /** 保存作业，并同步提醒、提交历史与日历。 */
    fun saveAssignment(
        assignment: AssignmentEntity,
        attachments: List<AttachmentEntity>? = null,
        syncCalendar: Boolean = uiState.value.settings.alwaysSyncCalendar
    ) = launchOp("作业已保存") {
        val id = repository.saveAssignment(
            assignment.copy(id = assignment.id, updatedAt = System.currentTimeMillis()),
            attachments = attachments
        )
        val saved = repository.assignment(id)?.assignment ?: return@launchOp
        repository.rememberSubmission(saved.subjectId, saved.submissionMethod)
        val notificationsEnabled = settingsRepository.settings.first().notificationsEnabled
        if (notificationsEnabled) {
            ReminderScheduler.schedule(getApplication(), saved)
        }
        refreshSubjectReminders(notificationsEnabled)
        syncCalendarIfPossible(saved, syncCalendar)
    }

    /** 删除作业并清理提醒和日历事件。 */
    fun deleteAssignment(id: Long) = launchOp("作业已删除") {
        val existing = repository.assignment(id)?.assignment
        ReminderScheduler.cancel(getApplication(), id)
        existing?.calendarEventId?.let { CalendarSyncManager.deleteEvent(getApplication(), it) }
        repository.deleteAssignment(id)
    }

    /** 切换作业完成状态并刷新关联提醒。 */
    fun setAssignmentCompleted(id: Long, completed: Boolean) = launchOp(
        if (completed) "作业已完成" else "作业已恢复"
    ) {
        val existing = repository.assignment(id)?.assignment ?: return@launchOp
        repository.setAssignmentStatus(id, completed)
        val updated = existing.copy(
            status = if (completed) AssignmentStatus.COMPLETED.rawValue else AssignmentStatus.ACTIVE.rawValue,
            completedAt = if (completed) System.currentTimeMillis() else null
        )
        if (completed) ReminderScheduler.cancel(getApplication(), id)
        else ReminderScheduler.schedule(getApplication(), updated)
        syncCalendarIfPossible(updated, uiState.value.settings.alwaysSyncCalendar)
    }

    fun cancelCalendarSync(id: Long) = launchOp("已取消日历同步") {
        val existing = repository.assignment(id)?.assignment ?: return@launchOp
        existing.calendarEventId?.let { CalendarSyncManager.deleteEvent(getApplication(), it) }
        repository.setCalendarEventId(id, null)
    }

    fun saveSubtask(subtask: SubtaskEntity) = launchOp(null) { repository.saveSubtask(subtask) }
    fun deleteSubtask(id: Long) = launchOp(null) { repository.deleteSubtask(id) }
    fun setSubtaskCompleted(id: Long, completed: Boolean) = launchOp(null) {
        repository.setSubtaskCompleted(id, completed)
    }

    fun saveTimeBlock(block: TimeBlockEntity) = launchOp("时间块已保存") {
        repository.saveTimeBlock(block)
    }

    fun deleteTimeBlock(id: Long) = launchOp("时间块已删除") { repository.deleteTimeBlock(id) }

    fun deleteSubmissionHistory(id: Long) = launchOp("已删除提交方式记录") {
        repository.deleteSubmissionHistory(id)
    }

    fun setAlwaysSyncCalendar(enabled: Boolean) = launchOp(null) {
        settingsRepository.setAlwaysSyncCalendar(enabled)
        if (enabled) {
            uiState.value.assignments
                .filter { it.assignment.status != AssignmentStatus.COMPLETED.rawValue }
                .forEach { syncCalendarIfPossible(it.assignment, true) }
        }
    }

    fun setNotificationsEnabled(enabled: Boolean) = launchOp(null) {
        settingsRepository.setNotificationsEnabled(enabled)
        val assignments = repository.allAssignmentsOnce()
        if (enabled) {
            assignments.forEach {
                if (it.status != AssignmentStatus.COMPLETED.rawValue) {
                    ReminderScheduler.schedule(getApplication(), it)
                }
            }
        } else {
            assignments.forEach { ReminderScheduler.cancel(getApplication(), it.id) }
        }
        // 重新开启通知时也必须恢复科目的“作业布置间隔”提醒。
        refreshSubjectReminders(enabled)
    }

    fun checkGithubUpdate(onFinished: (() -> Unit)? = null) {
        viewModelScope.launch {
            try {
                val release = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    com.hyperplusq.studyflow.system.GithubUpdateService.checkLatest()
                }
                val response = "${release.version} · ${release.publishedAt.take(10)}"
                settingsRepository.setLastGithubResponse(response)
                announce("已是最新 Release：${release.version}")
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    com.hyperplusq.studyflow.system.GithubUpdateService.open(
                        getApplication(),
                        release.htmlUrl
                    )
                }
            } catch (c: CancellationException) {
                throw c
            } catch (e: Exception) {
                announce("检查更新失败：${e.message ?: "网络错误"}")
            } finally {
                onFinished?.invoke()
            }
        }
    }

    /** 从用户选择的 JSON 文件导入数据。 */
    fun importJson(uri: Uri) {
        if (_importing.value || _exporting.value) return
        _importing.value = true
        viewModelScope.launch {
            try {
                val settings = settingsRepository.settings.first()
                val summary = JsonImporter.import(
                    context = getApplication(),
                    uri = uri,
                    repository = repository,
                    beforeReplace = {
                        repository.allAssignmentsOnce().forEach { assignment ->
                            ReminderScheduler.cancel(getApplication(), assignment.id)
                            assignment.calendarEventId?.let {
                                CalendarSyncManager.deleteEvent(getApplication(), it)
                            }
                        }
                        repository.subjectsOnce().forEach { subject ->
                            ReminderScheduler.cancelSubject(getApplication(), subject.id)
                        }
                    }
                )
                val imported = repository.assignmentsOnce()
                imported.forEach { item ->
                    // Imported calendar identifiers are platform-specific and are rebuilt
                    // after the old events have been removed.
                    repository.setCalendarEventId(item.assignment.id, null)
                    if (settings.alwaysSyncCalendar) {
                        syncCalendarIfPossible(item.assignment, true)
                    }
                }
                if (settings.notificationsEnabled) {
                    imported.forEach { item ->
                        if (item.assignment.status != AssignmentStatus.COMPLETED.rawValue) {
                            ReminderScheduler.schedule(getApplication(), item.assignment)
                        }
                    }
                }
                // 旧版备份可能缺少科目登记时间，按导入后的最新作业时间恢复提醒。
                refreshSubjectReminders(settings.notificationsEnabled)
                WidgetUpdater.requestUpdate(getApplication())
                announce(
                    "导入完成：${summary.assignments} 份作业、${summary.attachments} 个附件"
                )
            } catch (c: CancellationException) {
                throw c
            } catch (e: Exception) {
                announce("导入失败：${e.message ?: "未知错误"}")
            } finally {
                _importing.value = false
            }
        }
    }

    /** 将当前数据库及图片附件导出为 ZIP 备份。 */
    fun exportJson(uri: Uri) {
        if (_exporting.value) return
        _exporting.value = true
        viewModelScope.launch {
            try {
                JsonExporter.export(getApplication(), uri, repository)
                announce("ZIP 备份已导出")
            } catch (c: CancellationException) {
                throw c
            } catch (e: Exception) {
                announce("导出失败：${e.message ?: "未知错误"}")
            } finally {
                _exporting.value = false
            }
        }
    }

    private suspend fun syncCalendarIfPossible(assignment: AssignmentEntity, enabled: Boolean) {
        if (!CalendarSyncManager.hasPermission(getApplication())) return
        val eventId = CalendarSyncManager.sync(
            context = getApplication(),
            assignment = assignment,
            subject = subject(assignment.subjectId),
            alwaysSync = enabled
        )
        if (eventId != assignment.calendarEventId) {
            repository.setCalendarEventId(assignment.id, eventId)
        }
    }

    /** 统一执行异步操作、错误提示与小组件刷新。 */
    private fun launchOp(success: String?, action: suspend () -> Unit) {
        viewModelScope.launch {
            try {
                action()
                WidgetUpdater.requestUpdate(getApplication())
                success?.let { announce(it) }
            } catch (c: CancellationException) {
                throw c
            } catch (e: Exception) {
                announce("操作失败：${e.message ?: "未知错误"}")
            }
        }
    }

    companion object {
        val Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                AppViewModel(AppApplication.instance) as T
        }
    }
}

// Kept separate to avoid requiring a custom ViewModel factory in MainActivity.
object AppApplication {
    lateinit var instance: android.app.Application
}
