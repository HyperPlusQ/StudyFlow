import SwiftData
import SwiftUI

private struct DraftSubtask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct AssignmentEditorView: View {
    enum Mode {
        case new
        case edit(Assignment)
    }

    let mode: Mode
    let subjects: [Subject]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SubmissionHistoryEntry.lastUsedAt, order: .reverse)
    private var submissionHistory: [SubmissionHistoryEntry]

    @State private var title: String
    @State private var details: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var submissionMethod: String
    @State private var subjectId: UUID?
    @State private var priority: Priority
    @State private var weight: Int
    @State private var reminderLeadHours: Int
    @State private var subtasks: [DraftSubtask]

    init(mode: Mode, subjects: [Subject]) {
        self.mode = mode
        self.subjects = subjects
        switch mode {
        case .new:
            _title = State(initialValue: "")
            _details = State(initialValue: "")
            _hasDueDate = State(initialValue: true)
            _dueDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 24, to: .now) ?? .now)
            _submissionMethod = State(initialValue: "")
            _subjectId = State(initialValue: nil)
            _priority = State(initialValue: .medium)
            _weight = State(initialValue: 3)
            _reminderLeadHours = State(initialValue: 24)
            _subtasks = State(initialValue: [])
        case let .edit(assignment):
            _title = State(initialValue: assignment.title)
            _details = State(initialValue: assignment.details)
            _hasDueDate = State(initialValue: assignment.dueDate != nil)
            _dueDate = State(initialValue: assignment.dueDate ?? .now.addingTimeInterval(86_400))
            _submissionMethod = State(initialValue: assignment.submissionMethod)
            _subjectId = State(initialValue: assignment.subjectId)
            _priority = State(initialValue: assignment.priority)
            _weight = State(initialValue: assignment.weight)
            _reminderLeadHours = State(initialValue: assignment.reminderLeadHours)
            _subtasks = State(initialValue: assignment.subtasks
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { DraftSubtask(id: $0.id, title: $0.title, isCompleted: $0.isCompleted) })
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var submissionSuggestions: [SubmissionHistoryEntry] {
        guard let subjectId else { return [] }
        var seen = Set<String>()
        return submissionHistory.filter { entry in
            guard entry.subjectId == subjectId else { return false }
            return seen.insert(entry.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("作业信息") {
                    TextField("标题", text: $title, prompt: Text("例如：完成线性代数习题 4.2"))
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $details)
                        .frame(minHeight: 110)
                        .overlay(alignment: .topLeading) {
                            if details.isEmpty {
                                Text("补充题目要求、评分标准或备注…")
                                    .foregroundStyle(.tertiary)
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }
                    Picker("科目", selection: $subjectId) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(subjects.sorted { $0.name < $1.name }) {
                            Text($0.name).tag(UUID?.some($0.id))
                        }
                    }
                }

                Section("截止与优先级") {
                    Toggle("设置截止日期", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("截止时间", selection: $dueDate)
                        Picker("提醒", selection: $reminderLeadHours) {
                            Text("准时提醒").tag(0)
                            Text("提前 1 小时").tag(1)
                            Text("提前 6 小时").tag(6)
                            Text("提前 24 小时").tag(24)
                            Text("提前 48 小时").tag(48)
                        }
                    }
                    Picker("优先级", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("自定义权重", selection: $weight) {
                        Text("1 · 很低").tag(1)
                        Text("2 · 较低").tag(2)
                        Text("3 · 标准").tag(3)
                        Text("4 · 较高").tag(4)
                        Text("5 · 最高").tag(5)
                    }
                }

                Section("提交方式") {
                    HStack(spacing: 7) {
                        TextField(
                            "渠道或方式",
                            text: $submissionMethod,
                            prompt: Text("例如：Canvas 上传、网址、邮箱或纸质提交")
                        )

                        if !submissionSuggestions.isEmpty {
                            Menu {
                                ForEach(submissionSuggestions) { entry in
                                    Button(entry.value) {
                                        submissionMethod = entry.value
                                    }
                                }
                                Divider()
                                Text("在“编辑科目”中可删除历史记录")
                            } label: {
                                Image(systemName: "chevron.down.circle")
                                    .frame(width: 22, height: 22)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                    }

                    if !submissionSuggestions.isEmpty {
                        Text("已记住本科目使用过的 \(submissionSuggestions.count) 种提交方式；可在科目编辑窗口中手动删除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("保存后，本科目会记住该提交方式，便于下次快速填写。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach($subtasks) { $subtask in
                        HStack {
                            Toggle("", isOn: $subtask.isCompleted)
                                .platformCheckboxStyle()
                                .labelsHidden()
                            TextField("子任务", text: $subtask.title, prompt: Text("拆解成可执行的下一步"))
                                .textFieldStyle(.plain)
                            Button {
                                subtasks.removeAll { $0.id == subtask.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }

                    Button {
                        subtasks.append(DraftSubtask())
                    } label: {
                        Label("添加子任务", systemImage: "plus")
                    }
                } header: {
                    Text("子任务清单")
                } footer: {
                    Text("完成后可自动追踪进度；完成作业时会一并勾选。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(modeTitle)
            .platformSheetFrame()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(!canSave)
                }
            }
        }
    }

    private var modeTitle: String {
        if case .edit = mode { return "编辑作业" }
        return "新建作业"
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubmission = submissionMethod.trimmingCharacters(in: .whitespacesAndNewlines)

        let assignment: Assignment
        switch mode {
        case .new:
            assignment = Assignment(
                title: cleanTitle,
                details: cleanDetails,
                dueDate: hasDueDate ? dueDate : nil,
                submissionMethod: cleanSubmission,
                subjectId: subjectId,
                priority: priority,
                weight: weight,
                reminderLeadHours: reminderLeadHours
            )
            context.insert(assignment)
        case let .edit(existing):
            assignment = existing
            existing.title = cleanTitle
            existing.details = cleanDetails
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.submissionMethod = cleanSubmission
            existing.subjectId = subjectId
            existing.priority = priority
            existing.weight = weight
            existing.reminderLeadHours = reminderLeadHours
            existing.updatedAt = .now
        }

        reconcileSubtasks(for: assignment)
        PersistentStore.save(context)
        NotificationManager.shared.schedule(for: assignment)
        synchronizeCalendarAfterSave(for: assignment)
        dismiss()
    }

    @MainActor
    private func synchronizeCalendarAfterSave(for assignment: Assignment) {
        let subjectName = assignment.subjectId.flatMap { id in
            subjects.first { $0.id == id }?.name
        }

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

    private func reconcileSubtasks(for assignment: Assignment) {
        let existingById = Dictionary(uniqueKeysWithValues: assignment.subtasks.map { ($0.id, $0) })
        var retainedIds: Set<UUID> = []

        for (index, draft) in subtasks.enumerated()
        where !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = existingById[draft.id] {
                existing.title = cleanTitle
                existing.isCompleted = draft.isCompleted
                existing.sortOrder = index
                retainedIds.insert(existing.id)
            } else {
                let item = Subtask(
                    id: draft.id,
                    title: cleanTitle,
                    isCompleted: draft.isCompleted,
                    sortOrder: index,
                    assignment: assignment
                )
                context.insert(item)
                retainedIds.insert(item.id)
            }
        }

        for existing in assignment.subtasks where !retainedIds.contains(existing.id) {
            context.delete(existing)
        }
    }
}
