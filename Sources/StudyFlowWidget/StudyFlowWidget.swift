import SwiftUI
import WidgetKit

@main
struct StudyFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmallStudyFlowWidget()
        MediumStudyFlowWidget()
        LargeStudyFlowWidget()
    }
}

private struct StudyFlowEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

private struct StudyFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyFlowEntry {
        StudyFlowEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyFlowEntry) -> Void) {
        completion(StudyFlowEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyFlowEntry>) -> Void) {
        let entry = StudyFlowEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(Date.now.addingTimeInterval(15 * 60))))
    }
}

private struct SmallStudyFlowWidget: Widget {
    let kind = "StudyFlowSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("紧凑作业")
        .description("显示最重要的 1 份作业。")
        .supportedFamilies([.systemSmall])
    }
}

private struct MediumStudyFlowWidget: Widget {
    let kind = "StudyFlowMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("作业列表")
        .description("显示统计信息和最近 3 份作业。")
        .supportedFamilies([.systemMedium])
    }
}

private struct LargeStudyFlowWidget: Widget {
    let kind = "StudyFlowLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("学习概览")
        .description("显示完整统计、作业清单与子任务进度。")
        .supportedFamilies([.systemLarge])
    }
}

private struct StudyFlowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            switch family {
            case .systemSmall:
                smallContent
            case .systemMedium:
                mediumContent
            default:
                largeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("StudyFlow")
                .font(.headline)
                .foregroundStyle(.primary)
            if let snapshot = entry.snapshot {
                Text("进行中 \(snapshot.activeCount) · 今天 \(snapshot.dueTodayCount) · 逾期 \(snapshot.overdueCount)")
                    .font(.caption)
                    .foregroundStyle(snapshot.overdueCount > 0 ? .red : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var smallContent: some View {
        Group {
            if let item = entry.snapshot?.items.first {
                taskRow(item, showProgress: false)
            } else {
                emptyState
            }
        }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let items = entry.snapshot?.items, !items.isEmpty {
                ForEach(items.prefix(3)) { taskRow($0, showProgress: false) }
            } else {
                emptyState
            }
        }
    }

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot = entry.snapshot {
                Text("已完成 \(snapshot.completedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if snapshot.items.isEmpty {
                    emptyState
                } else {
                    ForEach(snapshot.items) { taskRow($0, showProgress: true) }
                }
            } else {
                emptyState
            }
        }
    }

    private func taskRow(_ item: WidgetSnapshot.Item, showProgress: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(item.subject)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(dueText(item.dueDate))
                    .font(.caption2)
                    .foregroundStyle(isOverdue(item.dueDate) ? .red : .secondary)
                    .lineLimit(1)
            }
            Text(item.title)
                .font(showProgress ? .subheadline : .footnote)
                .foregroundStyle(.primary)
                .lineLimit(family == .systemLarge ? 2 : 1)
            if showProgress, item.totalSubtasks > 0 {
                Text("子任务 \(item.completedSubtasks)/\(item.totalSubtasks)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无进行中作业")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private func isOverdue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return date < .now
    }

    private func dueText(_ date: Date?) -> String {
        guard let date else { return "无截止日期" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天 " + date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 " + date.formatted(date: .omitted, time: .shortened)
        }
        if date < .now {
            return "已逾期"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}

private extension WidgetSnapshot {
    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        activeCount: 3,
        dueTodayCount: 1,
        overdueCount: 0,
        completedCount: 8,
        items: [
            Item(
                id: UUID(),
                title: "完成高数第三章习题",
                subject: "数学",
                dueDate: Date.now.addingTimeInterval(7200),
                completedSubtasks: 2,
                totalSubtasks: 5
            ),
            Item(
                id: UUID(),
                title: "整理英语阅读笔记",
                subject: "英语",
                dueDate: Date.now.addingTimeInterval(86400),
                completedSubtasks: 1,
                totalSubtasks: 3
            )
        ]
    )
}
