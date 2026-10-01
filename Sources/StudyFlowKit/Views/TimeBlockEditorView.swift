import SwiftData
import SwiftUI

struct TimeBlockEditorView: View {
    let subjects: [Subject]
    var assignment: Assignment?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var startDate: Date
    @State private var durationMinutes: Int
    @State private var subjectId: UUID?
    @State private var notes: String = ""

    init(subjects: [Subject], assignment: Assignment? = nil) {
        self.subjects = subjects
        self.assignment = assignment
        let nextHour = Calendar.current.date(bySetting: .minute, value: 0, of: .now)
            .flatMap { Calendar.current.date(byAdding: .hour, value: 1, to: $0) }
            ?? .now
        _title = State(initialValue: assignment?.title ?? "")
        _startDate = State(initialValue: nextHour)
        _durationMinutes = State(initialValue: 50)
        _subjectId = State(initialValue: assignment?.subjectId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("工作时间块") {
                    TextField("标题", text: $title, prompt: Text("例如：精读教材第 3 章"))
                    DatePicker("开始时间", selection: $startDate)
                    Picker("时长", selection: $durationMinutes) {
                        Text("25 分钟").tag(25)
                        Text("50 分钟").tag(50)
                        Text("60 分钟").tag(60)
                        Text("90 分钟").tag(90)
                        Text("120 分钟").tag(120)
                    }
                }
                Section("归类") {
                    Picker("科目", selection: $subjectId) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(subjects.sorted { $0.name < $1.name }) {
                            Text($0.name).tag(UUID?.some($0.id))
                        }
                    }
                    TextField("备注", text: $notes, prompt: Text("地点、资料或完成标准"))
                }
                if assignment != nil {
                    Section {
                        Label("时间块会与所选作业关联，用于仪表盘统计。", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("安排工作时间")
            .platformSheetFrame()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入日程") { save() }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let block = TimeBlock(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            assignmentId: assignment?.id,
            subjectId: subjectId ?? assignment?.subjectId,
            startDate: startDate,
            durationMinutes: durationMinutes,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(block)
        PersistentStore.save(context)
        dismiss()
    }
}
