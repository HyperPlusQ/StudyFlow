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
import com.hyperplusq.studyflow.data.db.SubjectEntity
import com.hyperplusq.studyflow.data.db.SubtaskEntity
import com.hyperplusq.studyflow.data.db.TimeBlockEntity
import com.hyperplusq.studyflow.system.CalendarSyncManager
import com.hyperplusq.studyflow.system.JsonExporter
import com.hyperplusq.studyflow.system.ReminderScheduler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
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

    fun saveSubject(subject: SubjectEntity) = launchOp("已保存科目") {
        repository.saveSubject(subject)
    }

    fun deleteSubject(subject: SubjectEntity) = launchOp("已删除科目") {
        repository.deleteSubject(subject)
    }

    fun saveAssignment(
        assignment: AssignmentEntity,
        syncCalendar: Boolean = uiState.value.settings.alwaysSyncCalendar
    ) = launchOp("作业已保存") {
        val id = repository.saveAssignment(assignment.copy(id = assignment.id, updatedAt = System.currentTimeMillis()))
        val saved = repository.assignment(id)?.assignment ?: return@launchOp
        repository.rememberSubmission(saved.subjectId, saved.submissionMethod)
        ReminderScheduler.schedule(getApplication(), saved)
        syncCalendarIfPossible(saved, syncCalendar)
    }

    fun deleteAssignment(id: Long) = launchOp("作业已删除") {
        val existing = repository.assignment(id)?.assignment
        ReminderScheduler.cancel(getApplication(), id)
        existing?.calendarEventId?.let { CalendarSyncManager.deleteEvent(getApplication(), it) }
        repository.deleteAssignment(id)
    }

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
        if (enabled) {
            uiState.value.assignments.forEach {
                if (it.assignment.status != AssignmentStatus.COMPLETED.rawValue) {
                    ReminderScheduler.schedule(getApplication(), it.assignment)
                }
            }
        } else {
            uiState.value.assignments.forEach { ReminderScheduler.cancel(getApplication(), it.assignment.id) }
        }
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

    fun exportJson(uri: Uri) {
        if (_exporting.value) return
        _exporting.value = true
        viewModelScope.launch {
            try {
                JsonExporter.export(getApplication(), uri, repository)
                announce("JSON 已导出")
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

    private fun launchOp(success: String?, action: suspend () -> Unit) {
        viewModelScope.launch {
            try {
                action()
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
