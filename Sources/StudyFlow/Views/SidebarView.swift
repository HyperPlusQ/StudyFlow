import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSelection
    let subjects: [Subject]
    let assignments: [Assignment]
    let onNewAssignment: () -> Void
    let onNewSubject: (Subject?) -> Void
    let onEditSubject: (Subject) -> Void

    @Environment(\.modelContext) private var context
    @State private var subjectPendingDelete: Subject?
    @State private var expandedSubjects: Set<UUID> = []

    private var roots: [Subject] {
        subjects.filter { $0.parentId == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeAssignments: [Assignment] { assignments.filter { !$0.isCompleted } }

    var body: some View {
        List(selection: $selection) {
            Section {
                sidebarItem(scope: .today, count: activeAssignments.filter { item in
                    guard let due = item.dueDate else { return false }
                    return due <= .now.endOfDay
                }.count)
                sidebarItem(scope: .upcoming, count: activeAssignments.filter {
                    guard let due = $0.dueDate else { return false }
                    return due > .now && due <= (.now.addingTimeInterval(7 * 86_400))
                }.count)
                sidebarItem(scope: .all, count: activeAssignments.count)
                sidebarItem(scope: .completed, count: assignments.filter(\.isCompleted).count)
            }

            Section("仪表盘") {
                sidebarItem(scope: .dashboard)
            }

            Section {
                ForEach(roots) { root in
                    subjectOutline(for: root, level: 0)
                }
                .onDelete { offsets in
                    let sorted = roots
                    offsets.map { sorted[$0] }.forEach { subjectPendingDelete = $0 }
                }
            } header: {
                HStack {
                    Text("科目")
                    Spacer()
                    Button { onNewSubject(nil) } label: {
                        SafeSystemImage(systemName: "plus", fallback: "circle")
                    }
                    .buttonStyle(.borderless)
                    .help("新建科目")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("StudyFlow")
        .navigationSubtitle("学习与作业")
        .safeAreaInset(edge: .bottom) {
            Button(action: onNewAssignment) {
                HStack(spacing: 7) {
                    SafeSystemImage(systemName: "plus", fallback: "circle")
                    Text("新建作业")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: [.command])
            .padding(10)
            .background(.bar)
        }
        .alert(
            "删除“\(subjectPendingDelete?.name ?? "")”？",
            isPresented: Binding(
                get: { subjectPendingDelete != nil },
                set: { if !$0 { subjectPendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let subject = subjectPendingDelete {
                    StudyOperations.delete(subject, from: subjects, assignments: assignments, context: context)
                    if selection.subjectId == subject.id { selection = SidebarSelection(scope: .all) }
                }
                subjectPendingDelete = nil
            }
            Button("取消", role: .cancel) { subjectPendingDelete = nil }
        } message: {
            Text("该科目将从所有作业和时间块中移除。其子科目会提升到上一级。")
        }
    }

    private func subjectOutline(for subject: Subject, level: Int) -> AnyView {
        let children = subjects
            .filter { $0.parentId == subject.id }
            .sorted { $0.sortOrder < $1.sortOrder }
        let count = activeAssignments.filter { $0.subjectId == subject.id }.count

        if children.isEmpty {
            return AnyView(subjectRow(subject, count: count, level: level))
        } else {
            return AnyView(DisclosureGroup(isExpanded: Binding(
                get: { expandedSubjects.contains(subject.id) },
                set: { expanded in
                    if expanded { expandedSubjects.insert(subject.id) }
                    else { expandedSubjects.remove(subject.id) }
                }
            )) {
                ForEach(children) { child in
                    subjectOutline(for: child, level: level + 1)
                }
            } label: {
                subjectLabel(subject, count: count, level: level)
            }
            .contextMenu {
                subjectContextMenu(for: subject)
            })
        }
    }

    @ViewBuilder
    private func subjectRow(_ subject: Subject, count: Int, level: Int) -> some View {
        Button {
            selection = SidebarSelection(scope: .all, subjectId: subject.id)
        } label: {
            subjectLabel(subject, count: count, level: level)
        }
        .buttonStyle(.plain)
        .tag(SidebarSelection(scope: .all, subjectId: subject.id))
        .contextMenu {
            subjectContextMenu(for: subject)
        }
    }

    private func subjectLabel(_ subject: Subject, count: Int, level: Int) -> some View {
        HStack(spacing: 7) {
            SafeSystemImage(systemName: subject.symbol, fallback: "book.closed")
                .foregroundStyle(Color(hex: subject.colorHex))
                .frame(width: 16)
            Text(subject.name)
                .lineLimit(1)
            Spacer(minLength: 6)
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.leading, CGFloat(level) * 13)
        .contentShape(Rectangle())
    }

    private func subjectContextMenu(for subject: Subject) -> some View {
        Group {
            Button("编辑科目…") { onEditSubject(subject) }
            Button("新建子科目…") { onNewSubject(subject) }
            Divider()
            Button("删除科目", role: .destructive) { subjectPendingDelete = subject }
        }
    }

    private func sidebarItem(scope: ListScope, count: Int? = nil) -> some View {
        Button {
            selection = SidebarSelection(scope: scope)
        } label: {
            HStack {
                SafeSystemImage(systemName: scope.symbol, fallback: "circle")
                    .frame(width: 16)
                Text(scope.title)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
        .tag(SidebarSelection(scope: scope))
    }
}
