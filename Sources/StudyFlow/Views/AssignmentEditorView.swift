import AppKit
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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

/// 作业图片附件的编辑态，保存时再写入 SwiftData。
private struct DraftAttachment: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let imageData: Data
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
    @State private var attachments: [DraftAttachment]
    @State private var isImportingAttachments = false
    @State private var pickedPhotos: [PhotosPickerItem] = []

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
            _attachments = State(initialValue: [])
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
            _attachments = State(initialValue: assignment.attachments
                .sorted { $0.createdAt < $1.createdAt }
                .map {
                    DraftAttachment(
                        id: $0.id,
                        fileName: $0.fileName,
                        mimeType: $0.mimeType,
                        imageData: $0.imageData
                    )
                })
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
                    LabeledContent("智能评分") {
                        Text(scorePreview)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
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
                            .help("选择本科目曾经使用过的提交方式")
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
                    if attachments.isEmpty {
                        Text("可添加题目截图、草稿或参考图片。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(attachments) { attachment in
                                    AttachmentDraftThumbnail(
                                        attachment: attachment,
                                        onPreview: {
                                            AttachmentPreviewWindowController.shared.present(
                                                fileName: attachment.fileName,
                                                mimeType: attachment.mimeType,
                                                data: attachment.imageData
                                            )
                                        },
                                        onDelete: {
                                            attachments.removeAll { $0.id == attachment.id }
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // 系统媒体选择器：直接访问照片图库，无需额外的相册权限。
                    PhotosPicker(
                        selection: $pickedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("从照片中选择图片…", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: pickedPhotos) { _, items in
                        guard !items.isEmpty else { return }
                        Task { await importPickedPhotos(items) }
                    }

                    Button {
                        isImportingAttachments = true
                    } label: {
                        Label("从文件中选择图片…", systemImage: "folder")
                    }
                    .fileImporter(
                        isPresented: $isImportingAttachments,
                        allowedContentTypes: [.image],
                        allowsMultipleSelection: true
                    ) { result in
                        importAttachments(from: result)
                    }
                } header: {
                    Text("图片附件")
                } footer: {
                    Text("图片会随 ZIP 备份和 iCloud 同步一起保存。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach($subtasks) { $subtask in
                        HStack {
                            Toggle("", isOn: $subtask.isCompleted)
                                .toggleStyle(.checkbox)
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
                            .help("删除子任务")
                            .accessibilityLabel("删除子任务")
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
            .frame(minWidth: 560, minHeight: 640)
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

    private var scorePreview: String {
        let draft = Assignment(
            title: title,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            status: .active,
            weight: weight
        )
        return "\(Int(SmartScoring.score(for: draft))) 分"
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
        reconcileAttachments(for: assignment)
        updateSubjectRegistration(for: assignment)
        PersistentStore.save(context)
        NotificationManager.shared.schedule(for: assignment)
        NotificationManager.scheduleAllSubjectReminders(subjects: subjects, assignments: allAssignments(including: assignment))
        synchronizeCalendarAfterSave(for: assignment)
        dismiss()
    }

    /// 仅读取当前上下文中的作业，用于刷新全部科目的布置提醒。
    private func allAssignments(including assignment: Assignment) -> [Assignment] {
        var result = ((try? context.fetch(FetchDescriptor<Assignment>())) ?? [])
        if !result.contains(where: { $0.id == assignment.id }) {
            result.append(assignment)
        }
        return result
    }

    /// 新建作业或将作业移动到另一科目时，重置该科目的登记计时。
    private func updateSubjectRegistration(for assignment: Assignment) {
        let isNew: Bool
        if case .new = mode { isNew = true } else { isNew = false }

        if isNew, let id = subjectId {
            if let subject = subjects.first(where: { $0.id == id }) {
                subject.lastAssignmentRegisteredAt = assignment.createdAt
            }
            return
        }

        guard case let .edit(existing) = mode, existing.subjectId != subjectId else { return }
        if let oldID = existing.subjectId,
           let oldSubject = subjects.first(where: { $0.id == oldID }) {
            NotificationManager.shared.cancelSubjectReminder(for: oldSubject.id)
        }
        if let newID = subjectId,
           let newSubject = subjects.first(where: { $0.id == newID }) {
            newSubject.lastAssignmentRegisteredAt = .now
        }
    }

    private func reconcileAttachments(for assignment: Assignment) {
        let existingByID = Dictionary(
            uniqueKeysWithValues: assignment.attachments.map { ($0.id, $0) }
        )
        let retainedIDs = Set(attachments.map(\.id))
        for draft in attachments where existingByID[draft.id] == nil {
            let attachment = ImageAttachment(
                id: draft.id,
                fileName: draft.fileName,
                mimeType: draft.mimeType,
                imageData: draft.imageData,
                assignment: assignment
            )
            context.insert(attachment)
        }
        for existing in assignment.attachments where !retainedIDs.contains(existing.id) {
            context.delete(existing)
        }
    }

    /// 读取媒体选择器（照片图库）返回的图片并加入附件草稿。
    @MainActor
    private func importPickedPhotos(_ items: [PhotosPickerItem]) async {
        defer { pickedPhotos = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  !data.isEmpty,
                  !attachments.contains(where: { $0.imageData == data })
            else { continue }

            let mimeType = Self.mimeType(forImageData: data)
            attachments.append(
                DraftAttachment(
                    id: UUID(),
                    fileName: Self.fileName(for: item, mimeType: mimeType),
                    mimeType: mimeType,
                    imageData: data
                )
            )
        }
    }

    /// 按二进制头识别图片类型，避免照片导出的通用文件名猜错扩展名。
    private static func mimeType(forImageData data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        guard bytes.count >= 4 else { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]),
           bytes.count >= 12,
           String(decoding: bytes[8..<12], as: UTF8.self) == "WEBP" {
            return "image/webp"
        }
        if bytes.count >= 12,
           String(decoding: bytes[4..<8], as: UTF8.self) == "ftyp" {
            let brand = String(decoding: bytes[8..<12], as: UTF8.self).lowercased()
            let heicBrands = ["heic", "heix", "hevc", "hevx", "mif1", "msf1"]
            if heicBrands.contains(where: { brand.hasPrefix($0) }) { return "image/heic" }
        }
        return "image/jpeg"
    }

    /// 照片资源可能没有文件名，用资源标识加识别出的扩展名生成可读名称。
    private static func fileName(for item: PhotosPickerItem, mimeType: String) -> String {
        let fileExtension = BackupArchive.fileExtension(for: mimeType)
        if let identifier = item.itemIdentifier, !identifier.isEmpty {
            let safe = identifier
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            return safe.lowercased().hasSuffix(".\(fileExtension)") ? safe : "\(safe).\(fileExtension)"
        }
        return "照片-\(Int(Date().timeIntervalSince1970)).\(fileExtension)"
    }

    /// 读取系统选择器返回的图片并加入附件草稿。
    private func importAttachments(from result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            let fileName = url.lastPathComponent
            let mimeType = Self.mimeType(forExtension: url.pathExtension)
            guard !attachments.contains(where: { $0.fileName == fileName && $0.imageData == data }) else { continue }
            attachments.append(
                DraftAttachment(
                    id: UUID(),
                    fileName: fileName,
                    mimeType: mimeType,
                    imageData: data
                )
            )
        }
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": "image/png"
        case "gif": "image/gif"
        case "heic", "heif": "image/heic"
        case "webp": "image/webp"
        case "bmp": "image/bmp"
        default: "image/jpeg"
        }
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


/// 附件编辑器中的缩略图：点击全屏预览，右下角删除。
private struct AttachmentDraftThumbnail: View {
    let attachment: DraftAttachment
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onPreview) {
            AttachmentThumbnailImage(id: attachment.id, data: attachment.imageData)
                .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("全屏预览附件：\(attachment.fileName)")
        .overlay(alignment: .bottomTrailing) {
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.55))
                    .font(.title3)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("删除附件")
            .accessibilityLabel("删除附件“\(attachment.fileName)”")
        }
    }
}
