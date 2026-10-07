package com.hyperplusq.studyflow.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BackupTable
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CloudDone
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hyperplusq.studyflow.BuildConfig

@Composable
fun SettingsScreen(viewModel: AppViewModel, state: AppUiState) {
    val context = LocalContext.current
    var checking by remember { mutableStateOf(false) }
    val exporting by viewModel.exporting.collectAsState()
    val importing by viewModel.importing.collectAsState()
    var pendingImportUri by remember { mutableStateOf<android.net.Uri?>(null) }

    val calendarLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        if (result.values.all { it }) viewModel.setAlwaysSyncCalendar(true)
        else viewModel.announce("未获得日历权限，自动同步未开启")
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.setNotificationsEnabled(true)
        else viewModel.announce("未获得通知权限，本地提醒未开启")
    }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri -> uri?.let(viewModel::exportJson) }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> if (uri != null) pendingImportUri = uri }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("设置", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)

        SettingsCard(
            icon = Icons.Outlined.CalendarMonth,
            title = "系统日历"
        ) {
            SettingRow(
                title = "总是同步到系统日历"
            ) {
                Switch(
                    checked = state.settings.alwaysSyncCalendar,
                    onCheckedChange = { enabled ->
                        if (enabled) {
                            val permissions = arrayOf(
                                Manifest.permission.READ_CALENDAR,
                                Manifest.permission.WRITE_CALENDAR
                            )
                            val granted = permissions.all {
                                androidx.core.content.ContextCompat.checkSelfPermission(context, it) ==
                                    PackageManager.PERMISSION_GRANTED
                            }
                            if (granted) viewModel.setAlwaysSyncCalendar(true)
                            else calendarLauncher.launch(permissions)
                        } else {
                            viewModel.setAlwaysSyncCalendar(false)
                        }
                    }
                )
            }
        }

        SettingsCard(
            icon = Icons.Outlined.Notifications,
            title = "本地提醒"
        ) {
            SettingRow(
                title = "启用截止与布置提醒"
            ) {
                Switch(
                    checked = state.settings.notificationsEnabled,
                    onCheckedChange = { enabled ->
                        if (enabled) {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                androidx.core.content.ContextCompat.checkSelfPermission(
                                    context,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            } else {
                                viewModel.setNotificationsEnabled(true)
                            }
                        } else {
                            viewModel.setNotificationsEnabled(false)
                        }
                    }
                )
            }
        }

        SettingsCard(
            icon = Icons.Outlined.Download,
            title = "GitHub 更新"
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "当前版本 ${BuildConfig.VERSION_NAME}",
                        fontWeight = FontWeight.SemiBold
                    )
                    val last = state.settings.lastGithubResponse
                    if (last.isNotBlank()) {
                        Text(
                            last,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                OutlinedButton(
                    enabled = !checking,
                    onClick = {
                        checking = true
                        viewModel.checkGithubUpdate(
                            onFinished = { checking = false }
                        )
                    }
                ) { Text("检查更新") }
            }
            if (checking) {
                Spacer(Modifier.height(10.dp))
                LinearProgressIndicator(Modifier.fillMaxWidth())
            }
        }

        SettingsCard(
            icon = Icons.Outlined.BackupTable,
            title = "导入与导出"
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Button(
                    enabled = !exporting && !importing,
                    onClick = {
                        exportLauncher.launch(
                            "StudyFlow-${System.currentTimeMillis()}.zip"
                        )
                    }
                ) { Text("导出 ZIP 备份") }
                Button(
                    enabled = !exporting && !importing,
                    onClick = {
                        importLauncher.launch(arrayOf("application/zip", "application/json"))
                    }
                ) { Text("导入 ZIP/JSON") }
                if (exporting || importing) {
                    LinearProgressIndicator(Modifier.weight(1f))
                }
            }
        }

        SettingsCard(
            icon = Icons.Outlined.Info,
            title = "关于"
        ) {
            SettingRow(title = "作者") {
                Text(
                    "HyperPlus",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        if (pendingImportUri != null) {
            AlertDialog(
                onDismissRequest = { pendingImportUri = null },
                title = { Text("导入 StudyFlow 数据") },
                text = { Text("导入会覆盖当前设备上的科目、作业、子任务、时间块、图片附件和提交方式记录。是否继续？") },
                confirmButton = {
                    Button(
                        onClick = {
                            pendingImportUri?.let(viewModel::importJson)
                            pendingImportUri = null
                        }
                    ) { Text("继续导入") }
                },
                dismissButton = {
                    TextButton(onClick = { pendingImportUri = null }) { Text("取消") }
                }
            )
        }
    }
}

@Composable
private fun SettingsCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    content: @Composable () -> Unit
) {
    androidx.compose.material3.Surface(
        shape = RoundedCornerShape(30.dp),
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.94f),
        tonalElevation = 2.dp,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(16.dp))
            content()
        }
    }
}

@Composable
private fun SettingRow(
    title: String,
    trailing: @Composable () -> Unit
) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            title,
            Modifier.weight(1f),
            fontWeight = FontWeight.SemiBold
        )
        trailing()
    }
}
