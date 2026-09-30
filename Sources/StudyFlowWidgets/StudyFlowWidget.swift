import SwiftUI
import WidgetKit

@main
struct StudyFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompactStudyFlowWidget()
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
        completion(
            StudyFlowEntry(
                date: .now,
                snapshot: WidgetSnapshotStore.load() ?? .placeholder
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyFlowEntry>) -> Void) {
        let entry = StudyFlowEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        completion(
            Timeline(
                entries: [entry],
                policy: .after(.now.addingTimeInterval(15 * 60))
            )
        )
    }
}

private struct CompactStudyFlowWidget: Widget {
    let kind = "StudyFlowSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("最近作业")
        .description("突出显示最需要关注的 1 份作业。")
        .supportedFamilies([.systemSmall])
    }
}

private struct MediumStudyFlowWidget: Widget {
    let kind = "StudyFlowMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("待办作业")
        .description("横向展示最近 3 份作业。")
        .supportedFamilies([.systemMedium])
    }
}

private struct LargeStudyFlowWidget: Widget {
    let kind = "StudyFlowLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyFlowProvider()) { entry in
            StudyFlowWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("学习概览")
        .description("展示统计、最多 5 份作业及子任务进度。")
        .supportedFamilies([.systemLarge])
    }
}

private struct StudyFlowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyFlowEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            default:
                largeLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactHeader
            if let item = entry.snapshot?.items.first {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.subject)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                            .lineLimit(1)
                        Spacer(minLength: 5)
                        Text(shortDueText(item.dueDate))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isOverdue(item.dueDate) ? .red : .secondary)
                            .lineLimit(1)
                    }
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                    if item.totalSubtasks > 0 {
                        progressLabel(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptyState
            }
            Spacer(minLength: 0)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            if let items = entry.snapshot?.items, !items.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(items.prefix(3))) { item in
                        compactCard(item)
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            statistics
            if let snapshot = entry.snapshot, !snapshot.items.isEmpty {
                let items = Array(snapshot.items.prefix(5))
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        largeCard(item, rank: index + 1)
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(.tint)
            Text("StudyFlow")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 4)
            if let snapshot = entry.snapshot {
                Text("\(snapshot.activeCount)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("StudyFlow")
                    .font(.headline)
                if let snapshot = entry.snapshot {
                    Text("进行中 \(snapshot.activeCount) · 今天 \(snapshot.dueTodayCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 5)
            if let snapshot = entry.snapshot, snapshot.overdueCount > 0 {
                Label("\(snapshot.overdueCount) 逾期", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.14), in: Capsule())
            }
        }
    }

    private var statistics: some View {
        Group {
            if let snapshot = entry.snapshot {
                HStack(spacing: 7) {
                    statistic("已完成", snapshot.completedCount, symbol: "checkmark.circle.fill", tint: .green)
                    statistic("无日期", snapshot.activeCount - snapshot.dueTodayCount, symbol: "calendar", tint: .blue)
                    statistic("逾期", snapshot.overdueCount, symbol: "exclamationmark.triangle.fill", tint: .red)
                }
            }
        }
    }

    private func statistic(_ title: String, _ value: Int, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func compactCard(_ item: WidgetSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.subject)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                Spacer(minLength: 3)
                Text(shortDueText(item.dueDate))
                    .font(.caption2)
                    .foregroundStyle(isOverdue(item.dueDate) ? .red : .secondary)
                    .lineLimit(1)
            }
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            if item.totalSubtasks > 0 {
                progressLabel(item)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func largeCard(_ item: WidgetSnapshot.Item, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(rank == 1 ? Color.orange : Color.accentColor, in: Circle())
                Text(item.subject)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                Spacer(minLength: 3)
                Text(shortDueText(item.dueDate))
                    .font(.caption2)
                    .foregroundStyle(isOverdue(item.dueDate) ? .red : .secondary)
                    .lineLimit(1)
            }
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if item.totalSubtasks > 0 {
                HStack(spacing: 6) {
                    ProgressView(value: progress(item))
                        .tint(.accentColor)
                    Text("\(item.completedSubtasks)/\(item.totalSubtasks)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func progressLabel(_ item: WidgetSnapshot.Item) -> some View {
        HStack(spacing: 6) {
            ProgressView(value: progress(item))
                .frame(maxWidth: 62)
            Text("\(item.completedSubtasks)/\(item.totalSubtasks)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func progress(_ item: WidgetSnapshot.Item) -> Double {
        guard item.totalSubtasks > 0 else { return 0 }
        return Double(item.completedSubtasks) / Double(item.totalSubtasks)
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
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

    private func shortDueText(_ date: Date?) -> String {
        guard let date else { return "无日期" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInTomorrow(date) {
            return "明天"
        }
        if date < .now {
            return "逾期"
        }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}

private extension WidgetSnapshot {
    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        activeCount: 3,
        dueTodayCount: 1,
        overdueCount: 1,
        completedCount: 8,
        items: [
            Item(
                id: UUID(),
                title: "完成高数第三章习题",
                subject: "数学",
                dueDate: .now.addingTimeInterval(7_200),
                completedSubtasks: 2,
                totalSubtasks: 5,
                priorityRaw: 4,
                weight: 4
            ),
            Item(
                id: UUID(),
                title: "整理英语阅读笔记",
                subject: "英语",
                dueDate: .now.addingTimeInterval(86_400),
                completedSubtasks: 1,
                totalSubtasks: 3,
                priorityRaw: 3,
                weight: 3
            ),
            Item(
                id: UUID(),
                title: "完成物理实验报告",
                subject: "物理",
                dueDate: .now.addingTimeInterval(172_800),
                completedSubtasks: 0,
                totalSubtasks: 4,
                priorityRaw: 3,
                weight: 3
            ),
            Item(
                id: UUID(),
                title: "预习下一节课程",
                subject: "专业课",
                dueDate: nil,
                completedSubtasks: 0,
                totalSubtasks: 2,
                priorityRaw: 2,
                weight: 3
            ),
            Item(
                id: UUID(),
                title: "整理本周错题",
                subject: "数学",
                dueDate: .now.addingTimeInterval(345_600),
                completedSubtasks: 4,
                totalSubtasks: 6,
                priorityRaw: 3,
                weight: 3
            )
        ]
    )
}
