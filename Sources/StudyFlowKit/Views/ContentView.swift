import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let studyFlowNewAssignment = Notification.Name("StudyFlow.NewAssignment")
    static let studyFlowNewSubject = Notification.Name("StudyFlow.NewSubject")
    static let studyFlowNewTimeBlock = Notification.Name("StudyFlow.NewTimeBlock")
}

struct ContentView: View {
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
    @State private var subjectBeingEdited: Subject?
    @State private var showNewTimeBlock = false
    @State private var syncCoordinator = ICloudSyncCoordinator.shared
    @State private var iosTab: IOSTab = .dashboard

    /// 创建 iOS 主内容视图，所有状态均由默认值初始化。
    init() {}

    var body: some View {
        iosTabView
        .background { StudyFlowBackdrop().ignoresSafeArea() }
        .task {
            // 同步的重活在后台，但也不必串行阻塞后面的提醒注册。
            Task { await syncCoordinator.performLaunchSyncIfNeeded(context: context) }
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.scheduleAllSubjectReminders(
                subjects: subjects,
                assignments: assignments
            )
        }
        .onReceive(
            Timer.publish(every: 30, on: .main, in: .common).autoconnect()
        ) { _ in
            Task { await syncCoordinator.checkScheduledSyncIfNeeded(context: context) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyFlowNewAssignment)) { _ in
            showNewAssignment = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyFlowNewSubject)) { _ in
            newSubjectParent = nil
            subjectBeingEdited = nil
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
        .sheet(item: $subjectBeingEdited) {
            SubjectEditorView(existing: $0, subjects: subjects)
        }
        .sheet(isPresented: $showNewSubject) {
            SubjectEditorView(existing: nil, subjects: subjects)
        }
        .sheet(isPresented: $showNewTimeBlock) {
            TimeBlockEditorView(subjects: subjects)
        }
    }

    /// 使用原生底部标签栏切换主要页面。
    private var iosTabView: some View {
        TabView(selection: $iosTab) {
            NavigationStack {
                DashboardView(
                    assignments: assignments,
                    subjects: subjects,
                    blocks: blocks,
                    onNewBlock: { showNewTimeBlock = true }
                )
            }
            .tabItem { Label("概览", systemImage: "chart.bar.xaxis") }
            .tag(IOSTab.dashboard)

            NavigationStack {
                IOSAssignmentsPage(
                    assignments: assignments,
                    subjects: subjects,
                    blocks: blocks,
                    filter: $filter,
                    onNewAssignment: { showNewAssignment = true }
                )
            }
            .tabItem { Label("作业", systemImage: "list.bullet.rectangle") }
            .tag(IOSTab.assignments)

            NavigationStack {
                ScheduleView(
                    blocks: blocks,
                    subjects: subjects,
                    onNewBlock: { showNewTimeBlock = true }
                )
            }
            .tabItem { Label("日程", systemImage: "calendar") }
            .tag(IOSTab.schedule)

            NavigationStack {
                SubjectsView(
                    selection: $selection,
                    subjects: subjects,
                    assignments: assignments,
                    onNewSubject: {
                        newSubjectParent = nil
                        subjectBeingEdited = nil
                        showNewSubject = true
                    },
                    onEditSubject: { subject in
                        showNewSubject = false
                        subjectBeingEdited = subject
                    }
                )
            }
            .tabItem { Label("科目", systemImage: "books.vertical") }
            .tag(IOSTab.subjects)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
            .tag(IOSTab.settings)
        }
        .tint(.accentColor)
        .tabViewStyle(.automatic)
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var notice: String?
    @State private var updateState: UpdateCheckState = .idle
    @State private var exportNotice: String?
    @State private var syncCoordinator = ICloudSyncCoordinator.shared
    @AppStorage(CalendarService.alwaysSyncDefaultsKey) private var alwaysSyncCalendar = false
    @State private var isImporting = false
    @State private var pendingImportURL: URL?
    @State private var isChoosingCloudFolder = false
    @State private var pendingFolderEnable = false
    @State private var isExporting = false
    @State private var exportDocument: JSONFileDocument?

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
                    .studyFlowTransparentButtonStyle()
                }
                Text("每份作业都可以在编辑器中设置提前 0、1、6、24 或 48 小时提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("系统日历") {
                Toggle("总是同步到系统日历", isOn: $alwaysSyncCalendar)
                    .onChange(of: alwaysSyncCalendar) { _, isEnabled in
                        guard isEnabled else { return }
                        requestCalendarAccessForAutomaticSync()
                    }

                Text("打开后会立即请求日历权限。此后新建、编辑或完成作业时会自动创建、更新或删除对应日历事件；已同步作业即使关闭此开关，编辑或完成时仍会更新或删除现有事件。")
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
                            Label {
                                Text("从 GitHub 检查更新")
                            } icon: {
                                Image(systemName: "arrow.clockwise.circle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .studyFlowTransparentButtonStyle()
                    .disabled({
                        if case .checking = updateState { return true }
                        return false
                    }())

                    Spacer()

                    if case let .updateAvailable(_, url) = updateState {
                        Link("查看更新", destination: url)
                            .studyFlowTransparentButtonStyle()
                    }
                }
                if case .failed = updateState {
                    Button("重新检查") {
                        Task { await checkForUpdates() }
                    }
                    .studyFlowTransparentButtonStyle()
                }
                Link("前往 StudyFlow on GitHub", destination: GitHubUpdateService.projectURL)
                    .font(.caption)
                    .studyFlowTransparentButtonStyle()
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
                            if enabled && !syncCoordinator.hasSelectedFolder {
                                pendingFolderEnable = true
                                isChoosingCloudFolder = true
                                return
                            }
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

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        isChoosingCloudFolder = true
                        pendingFolderEnable = false
                    } label: {
                        Label(
                            syncCoordinator.hasSelectedFolder ? "更改同步文件夹…" : "选择同步文件夹…",
                            systemImage: "folder"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    }
                    .studyFlowTransparentButtonStyle()
                    .frame(maxWidth: .infinity)

                    Button {
                        Task { await syncCoordinator.synchronize(context: context) }
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .studyFlowTransparentButtonStyle()
                    .disabled(!syncCoordinator.hasSelectedFolder || syncCoordinator.isSynchronizing)
                    .frame(maxWidth: .infinity)
                }

                Text("开启后，每次打开 StudyFlow 都会同步；到达设定时间后，在应用运行期间也会自动同步。系统比较本地与 iCloud 中 \(ICloudSyncCoordinator.fileName) 的修改时间，并用较新的文件覆盖较旧的文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("备份与 iCloud") {
                LabeledContent("存储方式") { Text("SwiftData 本地存储") }
                LabeledContent("云盘备份") { Text("iCloud 云盘 ZIP 备份") }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        exportData(to: .anywhere)
                    } label: {
                        Label("导出 ZIP 备份…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .studyFlowTransparentButtonStyle()
                    .frame(maxWidth: .infinity)

                    Button {
                        exportData(to: .iCloudDrive)
                    } label: {
                        Label("导出到 iCloud 云盘（ZIP）…", systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .studyFlowTransparentButtonStyle()
                    .frame(maxWidth: .infinity)

                    Button {
                        isImporting = true
                    } label: {
                        Label("导入 ZIP/JSON…", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .studyFlowTransparentButtonStyle()
                    .frame(maxWidth: .infinity)
                }

                Text("ZIP 备份包含科目、作业、子任务、时间块、提交方式历史和图片附件；仍兼容旧版 JSON。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("作者") {
                    Text("HyperPlus")
                }
            }
        }
        .formStyle(.grouped)
        .platformSheetFrame()
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
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.zip, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                pendingImportURL = urls.first
            case let .failure(error):
                exportNotice = "无法选择文件：\(error.localizedDescription)"
            }
        }
        .alert(
            "导入 ZIP/JSON",
            isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { if !$0 { pendingImportURL = nil } }
            )
        ) {
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
            Button("覆盖并导入", role: .destructive) {
                if let url = pendingImportURL {
                    importData(from: url)
                }
                pendingImportURL = nil
            }
        } message: {
            Text("导入会用文件中的数据覆盖当前科目、作业、子任务、时间块、提交方式记录和图片附件。")
        }
        .fileImporter(
            isPresented: $isChoosingCloudFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    setCloudFolder(url)
                }
            case let .failure(error):
                pendingFolderEnable = false
                notice = "无法选择同步文件夹：\(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .zip,
            defaultFilename: DataExportService.suggestedFileName()
        ) { result in
            switch result {
            case .success:
                exportNotice = "导出成功。文件已保存到所选位置。"
            case let .failure(error):
                if (error as? CocoaError)?.code == .userCancelled {
                    exportNotice = "已取消导出。"
                } else {
                    exportNotice = "导出失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 开启开关时请求日历权限，失败则回滚开关。
    private func requestCalendarAccessForAutomaticSync() {
        Task { @MainActor in
            do {
                try await CalendarService.shared.requestAccessForAutomaticSync()
            } catch {
                alwaysSyncCalendar = false
                notice = error.localizedDescription
            }
        }
    }

    private func setCloudFolder(_ url: URL) {
        defer { pendingFolderEnable = false }
        guard syncCoordinator.setFolder(url: url, context: context) else {
            notice = syncCoordinator.lastMessage
            return
        }

        if pendingFolderEnable, !syncCoordinator.setEnabled(true, context: context) {
            notice = syncCoordinator.lastMessage
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
    /// 将数据导出到文件或 iCloud 云盘。
    private func exportData(to destination: DataExportService.Destination) {
        do {
            let data = try DataExportService.currentData(context: context)
            exportDocument = JSONFileDocument(data: data)
            isExporting = true
        } catch {
            exportNotice = "导出失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    /// 读取并恢复用户选择的 ZIP 或旧版 JSON 文件。
    private func importData(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            try DataExportService.restore(data: data, into: context)
            // 导入同样是一次数据变更：刷新同步比较时间戳，下次同步才会上传。
            syncCoordinator.refreshLocalSnapshotIfNeeded(context: context)
            exportNotice = "导入成功。当前数据已替换为文件内容。"
        } catch {
            exportNotice = "导入失败：\(error.localizedDescription)"
        }
    }
}

struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip, .json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
