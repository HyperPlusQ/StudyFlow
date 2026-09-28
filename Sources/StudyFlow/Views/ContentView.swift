import SwiftData
import SwiftUI

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
    @State private var editingSubject: Subject?
    @State private var showNewTimeBlock = false

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
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(selection.scope.title)
        .task {
            await NotificationManager.shared.requestAuthorization()
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
    @State private var notice: String?

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
            Section("数据") {
                LabeledContent("存储方式") { Text("SwiftData 本地存储") }
                LabeledContent("跨设备同步") { Text("当前未启用 iCloud") }
                Text("作业、科目、子任务和时间块均保存在本机应用容器中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 430)
        .alert("设置", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("好") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }
}
