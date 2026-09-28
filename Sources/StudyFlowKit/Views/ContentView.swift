import Observation
import SwiftData
import SwiftUI

extension Notification.Name {
    static let studyFlowNewAssignment = Notification.Name("StudyFlow.NewAssignment")
    static let studyFlowNewSubject = Notification.Name("StudyFlow.NewSubject")
    static let studyFlowNewTimeBlock = Notification.Name("StudyFlow.NewTimeBlock")
}

struct ContentView: View {
    let exporter: (any StudyFlowDataExporter)?
    let cloudFolderProvider: (any StudyFlowCloudFolderProvider)?

    @Environment(\.modelContext) private var context
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]
    @Query(sort: \Assignment.updatedAt, order: .reverse) private var assignments: [Assignment]
    @Query(sort: \TimeBlock.startDate) private var blocks: [TimeBlock]

    @State private var selection = SidebarSelection(scope: .today)
    @State private var filter = AssignmentFilter()
    @State private var showNewAssignment = false
    @State private var editingAssignment: Assignment?
    @State private var showNewSubject = false
    @State private var newSubjectParent: Subject?
    @State private var editingSubject: Subject?
    @State private var showNewTimeBlock = false
    @State private var syncCoordinator = ICloudSyncCoordinator.shared

    init(
        exporter: (any StudyFlowDataExporter)? = nil,
        cloudFolderProvider: (any StudyFlowCloudFolderProvider)? = nil
    ) {
        self.exporter = exporter
        self.cloudFolderProvider = cloudFolderProvider
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selection,
                subjects: subjects,
                assignments: assignments,
                onNewAssignment: { showNewAssignment = true },
                onNewSubject: { parent in
                    newSubjectParent = parent
                    editingSubject = nil
                    showNewSubject = true
                },
                onEditSubject: { subject in
                    editingSubject = subject
                    newSubjectParent = nil
                    showNewSubject = true
                }
            )
            .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
        } detail: {
            Group {
                if selection.scope == .dashboard {
                    DashboardView(
                        assignments: assignments,
                        subjects: subjects,
                        blocks: blocks,
                        onNewBlock: { showNewTimeBlock = true }
                    )
                } else {
                    AssignmentListView(
                        scope: selection,
                        assignments: assignments,
                        subjects: subjects,
                        blocks: blocks,
                        filter: $filter,
                        onNewAssignment: { showNewAssignment = true }
                    )
                }
            }
        }
        .background { StudyFlowBackdrop().ignoresSafeArea() }
        .platformTransparentToolbar()
        .navigationTitle(selection.scope.title)
        .task {
            syncCoordinator.performLaunchSyncIfNeeded(context: context)
            await NotificationManager.shared.requestAuthorization()
        }
        .onReceive(
            Timer.publish(every: 30, on: .main, in: .common).autoconnect()
        ) { _ in
            syncCoordinator.checkScheduledSyncIfNeeded(context: context)
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyFlowNewAssignment)) { _ in
            showNewAssignment = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyFlowNewSubject)) { _ in
            newSubjectParent = nil
            editingSubject = nil
            showNewSubject = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyFlowNewTimeBlock)) { _ in
            showNewTimeBlock = true
        }
        .sheet(isPresented: $showNewAssignment) {
            AssignmentEditorView(mode: .new, subjects: subjects)
        }
        .sheet(item: $editingAssignment) {
            AssignmentEditorView(mode: .edit($0), subjects: subjects)
        }
        .sheet(isPresented: $showNewSubject) {
            SubjectEditorView(existing: editingSubject, subjects: subjects)
        }
        .sheet(isPresented: $showNewTimeBlock) {
            TimeBlockEditorView(subjects: subjects)
        }
    }
}

struct SettingsView: View {
    let exporter: (any StudyFlowDataExporter)?
    let cloudFolderProvider: (any StudyFlowCloudFolderProvider)?

    @Environment(\.modelContext) private var context

    @State private var notice: String?
    @State private var updateState: UpdateCheckState = .idle
    @State private var exportNotice: String?
    @State private var syncCoordinator = ICloudSyncCoordinator.shared

    init(
        exporter: (any StudyFlowDataExporter)? = nil,
        cloudFolderProvider: (any StudyFlowCloudFolderProvider)? = nil
    ) {
        self.exporter = exporter
        self.cloudFolderProvider = cloudFolderProvider
    }

    var body: some View {
        Form {
            Section("通知") {
                LabeledContent("截止提醒") {
                    Button("请求通知权限") {
                        Task {
                            await NotificationManager.shared.requestAuthorization()
                            notice = "权限请求已发送；可在系统设置中修改。"
                        }
                    }
                }
                Text("每份作业都可以在编辑器中设置提前 0、1、6、24 或 48 小时提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("系统日历") {
                Text("在作业详情中可将截止时间添加到 macOS 系统日历；首次同步时会请求日历权限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("软件更新") {
                LabeledContent("当前版本") {
                    Text(GitHubUpdateService.currentVersion)
                        .monospacedDigit()
                }
                LabeledContent("更新状态") {
                    Text(updateStatusText)
                        .foregroundStyle(statusColor)
                }
                HStack {
                    Button {
                        Task { await checkForUpdates() }
                    } label: {
                        if case .checking = updateState {
                            ProgressView().controlSize(.small)
                            Text("正在检查…")
                        } else {
                            Label("从 GitHub 检查更新", systemImage: "arrow.clockwise.circle")
                        }
                    }
                    .disabled({
                        if case .checking = updateState { return true }
                        return false
                    }())

                    Spacer()

                    if case let .updateAvailable(_, url) = updateState {
                        Link("查看更新", destination: url)
                            .buttonStyle(.borderedProminent)
                    }
                }
                if case .failed = updateState {
                    Button("重新检查") {
                        Task { await checkForUpdates() }
                    }
                    .buttonStyle(.borderless)
                }
                Link("前往 StudyFlow on GitHub", destination: GitHubUpdateService.projectURL)
                    .font(.caption)
                Text("更新检查读取 GitHub 的 Release 与 Tag 信息；更新页面由系统浏览器打开，并由用户完成下载安装。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("iCloud 自动同步") {
                Toggle(
                    "每次打开和到时自动同步",
                    isOn: Binding(
                        get: { syncCoordinator.isEnabled },
                        set: { enabled in
                            if !syncCoordinator.setEnabled(enabled, context: context) {
                                notice = "未选择同步文件夹，自动同步保持关闭。"
                            }
                        }
                    )
                )
                .toggleStyle(.switch)

                DatePicker(
                    "每日同步时间",
                    selection: Binding(
                        get: {
                            var components = DateComponents()
                            components.hour = syncCoordinator.syncHour
                            components.minute = syncCoordinator.syncMinute
                            return Calendar.current.date(from: components) ?? .now
                        },
                        set: { date in
                            let components = Calendar.current.dateComponents(
                                [.hour, .minute],
                                from: date
                            )
                            syncCoordinator.setSyncTime(
                                hour: components.hour ?? 21,
                                minute: components.minute ?? 0
                            )
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!syncCoordinator.isEnabled)

                LabeledContent("同步文件夹") {
                    Text(syncCoordinator.folderName ?? "尚未选择")
                        .foregroundStyle(syncCoordinator.folderName == nil ? .secondary : .primary)
                }

                LabeledContent("同步状态") {
                    Text(syncCoordinator.lastMessage)
                        .foregroundStyle(.secondary)
                }

                if let lastSync = syncCoordinator.lastSyncDate {
                    LabeledContent("上次同步") {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                            .monospacedDigit()
                    }
                }

                HStack {
                    Button {
                        syncCoordinator.chooseFolder(context: context)
                    } label: {
                        Label("更改同步文件夹…", systemImage: "folder")
                    }
                    .disabled(!syncCoordinator.isEnabled || cloudFolderProvider == nil)

                    Button {
                        syncCoordinator.synchronize(context: context)
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                    .disabled(!syncCoordinator.isEnabled || cloudFolderProvider == nil)

                    Spacer()
                }

                Text("开启后，每次打开 StudyFlow 都会同步；到达设定时间后，在应用运行期间也会自动同步。系统比较本地与 iCloud 中 \(ICloudSyncCoordinator.fileName) 的修改时间，并用较新的文件覆盖较旧的文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("备份与 iCloud") {
                LabeledContent("存储方式") { Text("SwiftData 本地存储") }
                LabeledContent("云盘备份") { Text("iCloud 云盘 JSON 导出") }

                HStack {
                    Button {
                        exportData(to: .anywhere)
                    } label: {
                        Label("导出 JSON…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exporter == nil)

                    Button {
                        exportData(to: .iCloudDrive)
                    } label: {
                        Label("导出到 iCloud 云盘…", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(exporter == nil)
                }

                if exporter == nil {
                    Text("当前平台尚未配置 JSON 导出器。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("导出包含科目、作业、子任务、时间块和提交方式历史，可保存到本机或在保存对话框中选择 iCloud 云盘。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 760)
        .alert("设置", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("好") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
        .alert("数据导出", isPresented: Binding(get: { exportNotice != nil }, set: { if !$0 { exportNotice = nil } })) {
            Button("好") { exportNotice = nil }
        } message: {
            Text(exportNotice ?? "")
        }
    }

    private var updateStatusText: String {
        switch updateState {
        case .idle:
            "尚未检查"
        case .checking:
            "正在连接 GitHub…"
        case let .upToDate(version):
            "已是最新版本（\(version)）"
        case let .updateAvailable(version, _):
            "发现新版本 \(version)"
        case let .failed(message):
            message
        }
    }

    private var statusColor: Color {
        switch updateState {
        case .idle, .checking:
            .secondary
        case .upToDate:
            .green
        case .updateAvailable:
            .orange
        case .failed:
            .red
        }
    }

    private func checkForUpdates() async {
        updateState = .checking
        updateState = await GitHubUpdateService.checkForUpdates()
    }

    @MainActor
    private func exportData(to destination: DataExportService.Destination) {
        guard let exporter else {
            exportNotice = "当前平台尚未配置 JSON 导出器。"
            return
        }

        do {
            let data = try DataExportService.currentData(context: context)
            let didSave = try exporter.export(
                data: data,
                suggestedFileName: DataExportService.suggestedFileName(),
                destination: destination.exportDestination
            )
            if didSave {
                exportNotice = "导出成功。文件已写入所选位置。"
            } else {
                exportNotice = "已取消导出。"
            }
        } catch is CocoaError {
            exportNotice = "已取消导出。"
        } catch {
            exportNotice = "导出失败：\(error.localizedDescription)"
        }
    }
}
