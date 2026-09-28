import SwiftData
import SwiftUI

struct AssignmentListView: View {
    let scope: SidebarSelection
    let assignments: [Assignment]
    let subjects: [Subject]
    let blocks: [TimeBlock]
    @Binding var filter: AssignmentFilter
    let onNewAssignment: () -> Void

    @Environment(\.modelContext) private var context
    @State private var selectedAssignmentId: UUID?
    @State private var editingAssignment: Assignment?
    @State private var schedulingAssignment: Assignment?
    @State private var showFilters = false

    private var subjectMap: [UUID: Subject] {
        Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
    }

    private var visibleAssignments: [Assignment] {
        var items = assignments
        items = scope.scope == .completed ? items.filter(\.isCompleted) : items.filter { !$0.isCompleted }

        switch scope.scope {
        case .today:
            items = items.filter { $0.dueDate?.endOfDay ?? .distantFuture <= .now.endOfDay }
        case .upcoming:
            items = items.filter {
                guard let due = $0.dueDate else { return false }
                return due > .now && due <= .now.addingTimeInterval(7 * 86_400)
            }
        case .all, .dashboard, .completed:
            break
        }

        if let subjectId = scope.subjectId {
            let ids = Set(subjects
                .filter { $0.id == subjectId }
                .flatMap { StudyOperations.descendants(of: $0, in: subjects) }
                .map(\.id)
                + [subjectId])
            items = items.filter { task in
                guard let subjectId = task.subjectId else { return false }
                return ids.contains(subjectId)
            }
        }

        if !filter.searchText.isEmpty {
            let query = filter.searchText.lowercased()
            items = items.filter { task in
                let subjectName = task.subjectId.flatMap { subjectMap[$0] }?.name ?? ""
                let text = [task.title, task.details, task.submissionMethod, subjectName, task.subtasks.map(\.title).joined(separator: " ")]
                    .joined(separator: " ").lowercased()
                return text.contains(query)
            }
        }

        if let subject = filter.subjectId { items = items.filter { $0.subjectId == subject } }
        if filter.dueWindow != .all { items = items.filter { filter.dueWindow.contains($0.dueDate) } }
        if let priority = filter.priority { items = items.filter { $0.priority == priority } }
        if filter.hasChecklistOnly { items = items.filter { !$0.subtasks.isEmpty } }

        if scope.scope == .completed {
            return items.sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        }
        return SmartScoring.sorted(items).map(\.assignment)
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if visibleAssignments.isEmpty {
                emptyState
            } else {
                assignmentList
            }
        }
        .navigationTitle(scope.subjectId.map { subjectMap[$0]?.name ?? scope.scope.title } ?? scope.scope.title)
        .searchable(text: $filter.searchText, placement: .toolbar, prompt: "搜索标题、内容、提交方式或子任务")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showFilters.toggle() } label: {
                    Label("筛选", systemImage: filter.isDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .popover(isPresented: $showFilters, arrowEdge: .bottom) {
                    FilterPopover(filter: $filter, subjects: subjects)
                        .frame(width: 340)
                }
                Button(action: onNewAssignment) { Label("新建作业", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .inspector(isPresented: Binding(
            get: { selectedAssignmentId != nil },
            set: { if !$0 { selectedAssignmentId = nil } }
        )) {
            if let id = selectedAssignmentId, let assignment = assignments.first(where: { $0.id == id }) {
                AssignmentDetailView(
                    assignment: assignment,
                    subjects: subjects,
                    blocks: blocks,
                    onEdit: { editingAssignment = assignment; selectedAssignmentId = nil },
                    onSchedule: { schedulingAssignment = assignment }
                )
                .inspectorColumnWidth(min: 340, ideal: 390, max: 460)
            } else {
                ContentUnavailableView("未选择作业", systemImage: "sidebar.left")
            }
        }
        .sheet(item: $editingAssignment) { AssignmentEditorView(mode: .edit($0), subjects: subjects) }
        .sheet(item: $schedulingAssignment) { TimeBlockEditorView(subjects: subjects, assignment: $0) }
    }

    @ViewBuilder
    private var assignmentList: some View {
        #if os(macOS)
        List(selection: $selectedAssignmentId) {
            assignmentListContent
        }
        .listStyle(.inset)
        #else
        List {
            assignmentListContent
        }
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private var assignmentListContent: some View {
                    Section {
                        ForEach(Array(visibleAssignments.enumerated()), id: \.element.id) { index, item in
                            let task: Assignment = item
                            let taskSubject = task.subjectId.flatMap { subjectMap[$0] }
                            let rankValue: Int? = scope.scope == .completed ? nil : index + 1
                            AssignmentRow(
                                assignment: task,
                                subject: taskSubject,
                                rank: rankValue,
                                onToggle: { toggleComplete(task) },
                                onEdit: { editingAssignment = task },
                                onSchedule: { schedulingAssignment = task }
                            )
                            .tag(task.id)
                            .onTapGesture { selectedAssignmentId = task.id }
                        }
                    } header: {
                        Label(
                            scope.scope == .completed ? "最近完成" : "按紧迫度与自定义权重排序",
                            systemImage: scope.scope == .completed ? "checkmark.circle" : "sparkles"
                        )
                    }
    }

    private var summaryBar: some View {
        HStack(spacing: 10) {
            Label("\(visibleAssignments.count) 项", systemImage: "list.bullet")
                .foregroundStyle(.secondary)
            if !filter.isDefault {
                Text("已应用筛选").font(.caption).foregroundStyle(Color.accentColor)
                Button("清除") { filter.reset() }.platformLinkButtonStyle()
            }
            Spacer()
            if scope.scope != .completed && !visibleAssignments.isEmpty {
                Label("智能排序", systemImage: "arrow.up.arrow.down")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: scope.scope == .completed ? "checkmark.circle" : "tray",
            title: scope.scope == .completed ? "尚无已完成作业" : "这里空空如也",
            message: filter.isDefault ? "新建一份作业，或调整当前视图。" : "当前筛选条件下没有匹配结果。",
            actionTitle: filter.isDefault ? "新建作业" : "清除筛选",
            action: filter.isDefault ? onNewAssignment : { filter.reset() }
        )
    }

    private func toggleComplete(_ assignment: Assignment) {
        if assignment.isCompleted {
            assignment.status = .active
            assignment.completedAt = nil
            NotificationManager.shared.schedule(for: assignment)
        } else {
            assignment.status = .completed
            assignment.completedAt = .now
            assignment.subtasks.forEach { $0.isCompleted = true }
            NotificationManager.shared.cancel(for: assignment.id)
        }
        assignment.updatedAt = .now
        PersistentStore.save(context)
    }
}

struct AssignmentRow: View {
    @Bindable var assignment: Assignment
    let subject: Subject?
    var rank: Int?
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onSchedule: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isCompleted ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .platformHelp(assignment.isCompleted ? "恢复进行中" : "标记为已完成")

            if let rank, rank <= 5 {
                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 19, height: 19)
                    .background(rank == 1 ? Color.orange : Color.accentColor, in: Circle())
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(assignment.title)
                        .font(.body.weight(.medium))
                        .strikethrough(assignment.isCompleted)
                        .lineLimit(1)
                    if !assignment.subtasks.isEmpty {
                        Label("\(assignment.completedCount)/\(assignment.subtasks.count)", systemImage: "checklist")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 10) {
                    SubjectBadge(subject: subject)
                    SubmissionMethodView(value: assignment.submissionMethod, compact: true)
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 7) {
                DueLabel(date: assignment.dueDate, completed: assignment.isCompleted)
                HStack(spacing: 4) {
                    Image(systemName: assignment.priority.symbol)
                    Text(assignment.priority.label)
                }
                .font(.caption2)
                .foregroundStyle(assignment.priority == .critical ? .red : .secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            Button(assignment.isCompleted ? "恢复进行中" : "标记为已完成", action: onToggle)
            Button("编辑…", action: onEdit)
            Button("安排工作时间…", action: onSchedule)
        }
    }
}

private struct FilterPopover: View {
    @Binding var filter: AssignmentFilter
    let subjects: [Subject]

    var body: some View {
        Form {
            Picker("截止日期", selection: $filter.dueWindow) {
                ForEach(DueWindow.allCases) { Text($0.label).tag($0) }
            }
            Picker("科目", selection: $filter.subjectId) {
                Text("全部科目").tag(UUID?.none)
                ForEach(subjects.sorted { $0.name < $1.name }) {
                    Text($0.name).tag(UUID?.some($0.id))
                }
            }
            Picker("优先级", selection: $filter.priority) {
                Text("不限").tag(Priority?.none)
                ForEach(Priority.allCases) {
                    Text($0.label).tag(Priority?.some($0))
                }
            }
            Toggle("仅显示含子任务的作业", isOn: $filter.hasChecklistOnly)
            Button("重置全部筛选") { filter.reset() }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
