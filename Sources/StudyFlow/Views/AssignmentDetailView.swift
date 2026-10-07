import SwiftData
import SwiftUI
import AppKit

struct AssignmentDetailView: View {
    @Bindable var assignment: Assignment
    let subjects: [Subject]
    let blocks: [TimeBlock]
    let onEdit: () -> Void
    let onSchedule: () -> Void

    @Environment(\.modelContext) private var context
    @State private var newSubtaskTitle = ""
    @State private var notice: String?
    @State private var confirmDelete = false
    @State private var isSyncing = false

    private var subject: Subject? {
        assignment.subjectId.flatMap { id in subjects.first { $0.id == id } }
    }

    private var relatedBlocks: [TimeBlock] {
        blocks.filter { $0.assignmentId == assignment.id }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Divider()
                metadata
                if !assignment.details.isEmpty {
                    section("详细内容") {
                        Text(assignment.details)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                attachmentSection
                checklist
                timeBlocks
                Divider()
                actions
            }
            .padding(22)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("同步日历", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
        .alert("删除这份作业？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                NotificationManager.shared.cancel(for: assignment.id)
                if assignment.calendarEventIdentifier != nil {
                    _ = try? CalendarService.shared.removeEvent(for: assignment)
                }
                context.delete(assignment)
                PersistentStore.save(context)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("相关子任务也会一并删除，此操作无法撤销。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(assignment.title)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        SubjectBadge(subject: subject)
                        Label(assignment.priority.label, systemImage: assignment.priority.symbol)
                            .font(.caption)
                            .foregroundStyle(assignment.priority == .critical ? .red : .secondary)
                    }
                }
                Spacer()
                Button {
                    toggleCompletion()
                } label: {
                    Label(
                        assignment.isCompleted ? "恢复进行中" : "标记完成",
                        systemImage: assignment.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            ProgressView(value: assignment.progress) {
                HStack {
                    Text("完成进度")
                    Spacer()
                    Text("\(assignment.completedCount)/\(assignment.subtasks.count) 子任务")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
        }
    }

    private var metadata: some View {
        GroupBox {
            VStack(spacing: 12) {
                LabeledContent("截止日期") {
                    if let due = assignment.dueDate {
                        Text(due.dueDateTimeLabel)
                            .foregroundStyle(due < .now && !assignment.isCompleted ? .red : .primary)
                    } else {
                        Text("未设置").foregroundStyle(.tertiary)
                    }
                }
                LabeledContent("提交方式") {
                    SubmissionMethodView(value: assignment.submissionMethod)
                }
                LabeledContent("提醒") {
                    Text(reminderLabel)
                }
                LabeledContent("智能评分") {
                    Text("\(Int(SmartScoring.score(for: assignment)))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
    }

    /// 展示作业中的图片附件，保持清晰的内容优先布局。
    private var attachmentSection: some View {
        section("图片附件") {
            if assignment.attachments.isEmpty {
                Text("尚未添加图片附件。")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 10),
                        count: 4
                    ),
                    spacing: 10
                ) {
                    ForEach(assignment.attachments.sorted { $0.createdAt < $1.createdAt }, id: \.id) { attachment in
                        if let image = NSImage(data: attachment.imageData) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.primary.opacity(0.08))
                                }
                                .accessibilityLabel("附件：\(attachment.fileName)")
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 150)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("无法预览附件：\(attachment.fileName)")
                        }
                    }
                }
            }
        }
    }

    private var checklist: some View {
        section("子任务清单") {
            if assignment.subtasks.isEmpty {
                Text("将大作业拆成小步骤，更容易开始和追踪。")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(assignment.subtasks.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { subtask in
                        HStack(spacing: 9) {
                            Toggle("", isOn: Binding(
                                get: { subtask.isCompleted },
                                set: { value in
                                    subtask.isCompleted = value
                                    PersistentStore.save(context)
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            Text(subtask.title)
                                .strikethrough(subtask.isCompleted)
                                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                            Spacer()
                            Button {
                                context.delete(subtask)
                                PersistentStore.save(context)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.tertiary)
                            .help("删除子任务")
                            .accessibilityLabel("删除子任务“\(subtask.title)”")
                        }
                        .padding(.vertical, 7)
                        Divider()
                    }
                }
            }
            HStack {
                TextField("添加子任务…", text: $newSubtaskTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加") { addSubtask() }
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
    }

    private var timeBlocks: some View {
        section("工作时间块") {
            if relatedBlocks.isEmpty {
                Text("尚未安排专注时间。")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(relatedBlocks) { block in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title).font(.callout.weight(.medium))
                            Text("\(block.startDate.dueDateTimeLabel) · \(block.durationMinutes) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            context.delete(block)
                            PersistentStore.save(context)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .help("删除时间块")
                        .accessibilityLabel("删除时间块“\(block.title)”")
                    }
                    .padding(.vertical, 5)
                }
            }
            Button(action: onSchedule) {
                Label("安排工作时间…", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onEdit) {
                Label("编辑作业…", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                Task { await performCalendarAction() }
            } label: {
                HStack(spacing: 7) {
                    SafeSystemImage(
                        systemName: calendarActionSymbol,
                        fallback: "calendar"
                    )
                    Text(calendarActionTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(
                isSyncing ||
                (assignment.calendarEventIdentifier == nil && assignment.dueDate == nil)
            )

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("删除作业", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
    }

    private var reminderLabel: String {
        guard assignment.dueDate != nil, !assignment.isCompleted else { return "已完成或无日期" }
        if assignment.reminderLeadHours == 0 { return "截止时提醒" }
        return "提前 \(assignment.reminderLeadHours) 小时"
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title).font(.headline)
            content()
        }
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = Subtask(
            title: title,
            sortOrder: (assignment.subtasks.map(\.sortOrder).max() ?? -1) + 1,
            assignment: assignment
        )
        context.insert(item)
        assignment.updatedAt = .now
        PersistentStore.save(context)
        newSubtaskTitle = ""
    }

    private var calendarActionTitle: String {
        if isSyncing { return "正在处理…" }
        return assignment.calendarEventIdentifier != nil ? "取消日历同步" : "添加到系统日历"
    }

    private var calendarActionSymbol: String {
        assignment.calendarEventIdentifier != nil ? "calendar.badge.minus" : "calendar.badge.plus"
    }

    private func toggleCompletion() {
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
        synchronizeCalendarAfterCompletion()
    }

    @MainActor
    private func synchronizeCalendarAfterCompletion() {
        Task {
            do {
                try await CalendarService.shared.synchronizeAfterAssignmentChange(
                    assignment,
                    subjectName: subject?.name
                )
                PersistentStore.save(context)
            } catch {
                NSLog("StudyFlow 日历同步失败：%@", error.localizedDescription)
            }
        }
    }

    private func performCalendarAction() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            if assignment.calendarEventIdentifier != nil {
                try CalendarService.shared.removeEvent(for: assignment)
                PersistentStore.save(context)
                notice = "已取消这份作业的日历同步。"
            } else {
                try await CalendarService.shared.sync(assignment, subjectName: subject?.name)
                PersistentStore.save(context)
                notice = "作业已同步到系统日历。"
            }
        } catch {
            notice = error.localizedDescription
        }
    }
}
