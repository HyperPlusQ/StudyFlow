import SwiftData
import SwiftUI

struct SubjectEditorView: View {
    let existing: Subject?
    let subjects: [Subject]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SubmissionHistoryEntry.lastUsedAt, order: .reverse)
    private var submissionHistory: [SubmissionHistoryEntry]

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var parentId: UUID?

    private static let availableIcons = [
        "book.closed", "function", "atom", "flask", "globe", "paintbrush", "music.note",
        "hammer", "code", "brain", "languages", "chart.line.uptrend.xy", "case",
        "leaf", "heart", "building.columns", "doc.text", "tray.full"
    ].filter(PlatformSymbolAvailability.contains) + ["circle"]
    private static let colors = [
        "#4F7DF3", "#8B5CF6", "#EC4899", "#F97316",
        "#EAB308", "#22C55E", "#14B8A6", "#0EA5E9", "#64748B"
    ]

    init(existing: Subject?, subjects: [Subject]) {
        self.existing = existing
        self.subjects = subjects
        _name = State(initialValue: existing?.name ?? "")
        _symbol = State(initialValue: PlatformSymbolAvailability.resolve(existing?.symbol))
        _colorHex = State(initialValue: existing?.colorHex ?? "#4F7DF3")
        _parentId = State(initialValue: existing?.parentId)
    }

    private var historyEntries: [SubmissionHistoryEntry] {
        guard let existing else { return [] }
        return submissionHistory.filter { $0.subjectId == existing.id }
    }

    private var allowedParents: [Subject] {
        guard let existing else { return subjects }
        let excluded = Set(StudyOperations.descendants(of: existing, in: subjects).map(\.id) + [existing.id])
        return subjects.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("科目名称", text: $name, prompt: Text("例如：高等数学"))
                    ColorSwatchPicker(selection: $colorHex, colors: Self.colors)
                    IconPicker(selection: $symbol, icons: Self.availableIcons)
                }

                Section("层级结构") {
                    Picker("上级科目", selection: $parentId) {
                        Text("根级科目").tag(UUID?.none)
                        ForEach(allowedParents.sorted { $0.name < $1.name }) {
                            Text($0.name).tag(UUID?.some($0.id))
                        }
                    }
                    Text(parentId == nil ? "该科目显示在侧边栏顶层。" : "该科目将作为子科目嵌套显示。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if existing != nil {
                    Section("提交方式历史") {
                        if historyEntries.isEmpty {
                            Text("这个科目还没有历史记录。为作业填写并保存提交方式后会自动出现在这里。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(historyEntries) { entry in
                                HStack(spacing: 10) {
                                    SubmissionMethodView(value: entry.value)
                                    Spacer()
                                    Button(role: .destructive) {
                                        SubmissionHistoryStore.delete(entry, context: context)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("从本科目的历史记录中删除")
                                    .accessibilityLabel("删除提交记录“\(entry.value)”")
                                }
                            }
                        }
                        Text("历史记录只用于快速填写，不会改变已有作业；可逐条手动删除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "新建科目" : "编辑科目")
            .frame(width: 520, height: 620)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.name = cleanName
            existing.symbol = PlatformSymbolAvailability.resolve(symbol)
            existing.colorHex = colorHex
            existing.parentId = parentId
        } else {
            let subject = Subject(
                name: cleanName,
                symbol: PlatformSymbolAvailability.resolve(symbol),
                colorHex: colorHex,
                parentId: parentId,
                sortOrder: (subjects.filter { $0.parentId == parentId }.map(\.sortOrder).max() ?? -1) + 1
            )
            context.insert(subject)
        }
        PersistentStore.save(context)
        dismiss()
    }
}
