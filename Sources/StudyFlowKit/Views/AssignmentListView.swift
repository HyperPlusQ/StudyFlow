import SwiftData
import SwiftUI
import UIKit

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
    @State private var previewedAttachmentID: UUID?

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
        .fullScreenCover(
            isPresented: Binding(
                get: { previewedAttachmentID != nil },
                set: { if !$0 { previewedAttachmentID = nil } }
            )
        ) {
            if let attachment = assignments.lazy.flatMap(\.attachments).first(where: { $0.id == previewedAttachmentID }) {
                AttachmentPreviewView(
                    attachment: attachment,
                    onDismiss: { previewedAttachmentID = nil }
                )
            }
        }
        .navigationTitle(scope.subjectId.map { subjectMap[$0]?.name ?? scope.scope.title } ?? scope.scope.title)
        .searchable(text: $filter.searchText, placement: .toolbar, prompt: "搜索标题、内容、提交方式或子任务")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 类比相册的筛选按钮：非全屏、锚定在按钮下方的弹出式菜单。
                Menu {
                    Picker("截止日期", selection: $filter.dueWindow) {
                        ForEach(DueWindow.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("优先级", selection: $filter.priority) {
                        Text("不限").tag(Priority?.none)
                        ForEach(Priority.allCases) {
                            Text($0.label).tag(Priority?.some($0))
                        }
                    }
                    Toggle("仅含子任务", isOn: $filter.hasChecklistOnly)
                    Picker("科目", selection: $filter.subjectId) {
                        Text("全部科目").tag(UUID?.none)
                        ForEach(subjects.sorted { $0.name < $1.name }) {
                            Text($0.name).tag(UUID?.some($0.id))
                        }
                    }
                    if !filter.isDefault {
                        Divider()
                        Button("重置筛选") { filter.reset() }
                    }
                } label: {
                    SafeSystemImage(
                        systemName: filter.isDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill",
                        fallback: "slider.horizontal.3"
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("筛选")
                Button(action: onNewAssignment) {
                    SafeSystemImage(systemName: "plus", fallback: "circle")
                }
                .accessibilityLabel("新建作业")
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedAssignmentId != nil },
            set: { if !$0 { selectedAssignmentId = nil } }
        )) {
            NavigationStack {
                assignmentDetailContent
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { selectedAssignmentId = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $editingAssignment) { AssignmentEditorView(mode: .edit($0), subjects: subjects) }
        .sheet(item: $schedulingAssignment) { TimeBlockEditorView(subjects: subjects, assignment: $0) }
    }

    @ViewBuilder
    private var assignmentDetailContent: some View {
        if let id = selectedAssignmentId,
           let assignment = assignments.first(where: { $0.id == id }) {
            AssignmentDetailView(
                assignment: assignment,
                subjects: subjects,
                blocks: blocks,
                onEdit: {
                    editingAssignment = assignment
                    selectedAssignmentId = nil
                },
                onSchedule: { schedulingAssignment = assignment }
            )
        } else {
            ContentUnavailableView("未选择作业", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private var assignmentList: some View {
        List {
            assignmentListContent
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
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
                                onOpen: { selectedAssignmentId = task.id },
                                onEdit: { editingAssignment = task },
                                onSchedule: { schedulingAssignment = task },
                                previewedAttachmentID: $previewedAttachmentID
                            )
                            .tag(task.id)
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
                Button("清除") { filter.reset() }
                    .buttonStyle(.borderless)
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
        .background(.ultraThinMaterial)
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
        synchronizeCalendarAfterCompletion(for: assignment)
    }

    @MainActor
    private func synchronizeCalendarAfterCompletion(for assignment: Assignment) {
        let subjectName = assignment.subjectId.flatMap { subjectMap[$0]?.name }

        Task {
            do {
                try await CalendarService.shared.synchronizeAfterAssignmentChange(
                    assignment,
                    subjectName: subjectName
                )
                PersistentStore.save(context)
            } catch {
                NSLog("StudyFlow 日历同步失败：%@", error.localizedDescription)
            }
        }
    }
}

struct AssignmentRow: View {
    @Bindable var assignment: Assignment
    let subject: Subject?
    var rank: Int?
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onSchedule: () -> Void
    @Binding var previewedAttachmentID: UUID?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                SafeSystemImage(
                    systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle",
                    fallback: "circle"
                )
                    .font(.title3)
                    .foregroundStyle(assignment.isCompleted ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(assignment.isCompleted ? "恢复进行中" : "标记为已完成")

            if let rank, rank <= 5 {
                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 19, height: 19)
                    .background(
                        (rank == 1 ? Color.orange : Color.accentColor).opacity(0.18),
                        in: Circle()
                    )
                    .overlay(
                        Circle().strokeBorder(
                            rank == 1 ? Color.orange : Color.accentColor,
                            lineWidth: 1
                        )
                    )
                    .accessibilityLabel("智能排序第 \(rank) 名")
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(assignment.title)
                        .font(.body.weight(.medium))
                        .strikethrough(assignment.isCompleted)
                        .fixedSize(horizontal: false, vertical: true)
                    if !assignment.subtasks.isEmpty {
                        Label(
                            "\(assignment.completedCount)/\(assignment.subtasks.count)",
                            systemImage: "checklist"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if !assignment.details.isEmpty {
                    Text(assignment.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SubjectBadge(subject: subject)
                    Spacer(minLength: 8)
                    DueLabel(date: assignment.dueDate, completed: assignment.isCompleted)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SubmissionMethodView(value: assignment.submissionMethod, compact: true)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        SafeSystemImage(systemName: assignment.priority.symbol, fallback: "exclamationmark")
                        Text(assignment.priority.label)
                    }
                    .font(.caption2)
                    .foregroundStyle(assignment.priority == .critical ? .red : .secondary)
                }

                if !assignment.attachments.isEmpty {
                    AssignmentAttachmentThumbnails(
                        attachments: assignment.attachments,
                        previewedAttachmentID: $previewedAttachmentID
                    )
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button(assignment.isCompleted ? "恢复进行中" : "标记为已完成", action: onToggle)
            Button("编辑…", action: onEdit)
            Button("安排工作时间…", action: onSchedule)
        }
    }
}

/// 作业行内的图片附件缩略图，最多展示三张并以数量角标表示剩余附件。
private struct AssignmentAttachmentThumbnails: View {
    let attachments: [ImageAttachment]
    @Binding var previewedAttachmentID: UUID?

    private var sortedAttachments: [ImageAttachment] {
        attachments.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sortedAttachments.prefix(3), id: \.id) { attachment in
                Button {
                    previewedAttachmentID = attachment.id
                } label: {
                    AttachmentThumbnailImage(attachment: attachment)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("全屏查看附件：\(attachment.fileName)")
            }

            if sortedAttachments.count > 3 {
                Text("+\(sortedAttachments.count - 3)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 38, minHeight: 38)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("还有 \(sortedAttachments.count - 3) 张附件")
            }
        }
    }
}
