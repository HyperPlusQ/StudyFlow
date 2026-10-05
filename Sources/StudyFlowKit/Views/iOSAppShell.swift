import SwiftData
import SwiftUI

enum IOSTab: Hashable, CaseIterable {
    case dashboard
    case assignments
    case schedule
    case subjects
    case settings
}

/// 使用原生分段控件切换作业范围，底部标签栏仍负责页面导航。
struct IOSAssignmentsPage: View {
    let assignments: [Assignment]
    let subjects: [Subject]
    let blocks: [TimeBlock]
    @Binding var filter: AssignmentFilter
    let onNewAssignment: () -> Void

    @State private var scope: ListScope = .all

    var body: some View {
        VStack(spacing: 0) {
            Picker("作业范围", selection: $scope) {
                Text("今天").tag(ListScope.today)
                Text("一周").tag(ListScope.upcoming)
                Text("全部").tag(ListScope.all)
                Text("完成").tag(ListScope.completed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            AssignmentListView(
                scope: SidebarSelection(scope: scope),
                assignments: assignments,
                subjects: subjects,
                blocks: blocks,
                filter: $filter,
                onNewAssignment: onNewAssignment
            )
        }
    }
}

/// 独立日程页面，采用与安卓端一致的分页导航模型。
struct ScheduleView: View {
    let blocks: [TimeBlock]
    let subjects: [Subject]
    let onNewBlock: () -> Void

    @Environment(\.modelContext) private var context

    private struct DayGroup: Identifiable {
        let date: Date
        let blocks: [TimeBlock]
        var id: Date { date }
    }

    private var subjectMap: [UUID: Subject] {
        Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
    }

    private var groups: [DayGroup] {
        Dictionary(grouping: blocks, by: { $0.startDate.startOfDay })
            .map { date, items in
                DayGroup(date: date, blocks: items.sorted { $0.startDate < $1.startDate })
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "暂无日程",
                    systemImage: "calendar",
                    description: Text("将作业拆成工作时间块后，日程会显示在这里。")
                )
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.blocks) { block in
                            row(for: block)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(block)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(dayHeader(for: group.date))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("日程")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewBlock) {
                    SafeSystemImage(systemName: "plus", fallback: "calendar")
                }
                .accessibilityLabel("新建时间块")
            }
        }
    }

    private func row(for block: TimeBlock) -> some View {
        let subject = block.subjectId.flatMap { subjectMap[$0] }
        return HStack(spacing: 13) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(block.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("\(block.durationMinutes) 分钟")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 78, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(subject.map { Color(hex: $0.colorHex) } ?? Color.accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(block.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    SubjectBadge(subject: subject)
                    if !block.notes.isEmpty {
                        Text(block.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func dayHeader(for date: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: .now) {
            return "今天 · \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        if Calendar.current.isDate(
            date,
            inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        ) {
            return "明天 · \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return date.formatted(date: .complete, time: .omitted)
    }

    private func delete(_ block: TimeBlock) {
        context.delete(block)
        PersistentStore.save(context)
    }
}

/// 底部标签栏使用的原生 iOS 科目管理页面。
struct SubjectsView: View {
    @Binding var selection: SidebarSelection
    let subjects: [Subject]
    let assignments: [Assignment]
    let onNewSubject: () -> Void
    let onEditSubject: (Subject) -> Void

    @Environment(\.modelContext) private var context
    @State private var expandedSubjects: Set<UUID> = []
    @State private var pendingDelete: Subject?

    private var roots: [Subject] {
        subjects.filter { $0.parentId == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeAssignments: [Assignment] {
        assignments.filter { !$0.isCompleted }
    }

    var body: some View {
        List {
            Section {
                if roots.isEmpty {
                    ContentUnavailableView(
                        "还没有科目",
                        systemImage: "books.vertical",
                        description: Text("新建科目，为作业建立清晰的分类层级。")
                    )
                } else {
                    ForEach(roots) { root in
                        subjectOutline(for: root, level: 0)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("科目")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewSubject) {
                    SafeSystemImage(systemName: "plus", fallback: "circle")
                }
                .accessibilityLabel("新建科目")
            }
        }
        .alert(
            "删除“\(pendingDelete?.name ?? "")”？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                guard let subject = pendingDelete else { return }
                StudyOperations.delete(subject, from: subjects, assignments: assignments, context: context)
                if selection.subjectId == subject.id {
                    selection = SidebarSelection(scope: .all)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("该科目将从所有作业和时间块中移除。其子科目会提升到上一级。")
        }
    }

    private func subjectOutline(for subject: Subject, level: Int) -> AnyView {
        let children = subjects
            .filter { $0.parentId == subject.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        if children.isEmpty {
            return AnyView(subjectRow(subject, level: level))
        } else {
            return AnyView(DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedSubjects.contains(subject.id) },
                    set: { expanded in
                        if expanded {
                            expandedSubjects.insert(subject.id)
                        } else {
                            expandedSubjects.remove(subject.id)
                        }
                    }
                )
            ) {
                ForEach(children) { child in
                    subjectOutline(for: child, level: level + 1)
                }
            } label: {
                HStack(spacing: 10) {
                    SafeSystemImage(systemName: subject.symbol, fallback: "book.closed")
                        .foregroundStyle(Color(hex: subject.colorHex))
                    Text(subject.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                }
            }
            .padding(.leading, CGFloat(level) * 12))
        }
    }

    private func subjectRow(_ subject: Subject, level: Int) -> some View {
        let descendantIds = Set(
            StudyOperations.descendants(of: subject, in: subjects).map(\.id) + [subject.id]
        )
        let count = activeAssignments.filter {
            guard let subjectId = $0.subjectId else { return false }
            return descendantIds.contains(subjectId)
        }.count

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: subject.colorHex).opacity(0.18))
                    .frame(width: 34, height: 34)
                SafeSystemImage(systemName: subject.symbol, fallback: "book.closed")
                    .foregroundStyle(Color(hex: subject.colorHex))
            }

            Text(subject.name)
                .font(.body.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())

            Button {
                onEditSubject(subject)
            } label: {
                SafeSystemImage(systemName: "ellipsis", fallback: "circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("编辑“\(subject.name)”")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onEditSubject(subject) }
        .contextMenu {
            Button("编辑…") { onEditSubject(subject) }
            Button("删除…", role: .destructive) { pendingDelete = subject }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = subject
            } label: {
                Label("删除", systemImage: "trash")
            }
            Button {
                onEditSubject(subject)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .padding(.leading, CGFloat(level) * 20)
    }
}
