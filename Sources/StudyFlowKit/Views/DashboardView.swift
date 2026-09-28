import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    let assignments: [Assignment]
    let subjects: [Subject]
    let blocks: [TimeBlock]
    let onNewBlock: () -> Void

    private var active: [Assignment] { assignments.filter { !$0.isCompleted } }
    private var completed: [Assignment] { assignments.filter(\.isCompleted) }

    private var completionRate: Double {
        assignments.isEmpty ? 0 : Double(completed.count) / Double(assignments.count)
    }

    private var dueToday: [Assignment] {
        active.filter {
            guard let due = $0.dueDate else { return false }
            return due <= .now.endOfDay
        }
    }

    private var overdue: [Assignment] {
        active.filter { $0.dueDate ?? .distantFuture < .now }
    }

    private var scheduledMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }

    private var subjectTime: [(subject: Subject?, minutes: Int)] {
        let grouped = Dictionary(grouping: blocks, by: \.subjectId)
        return grouped.map { id, items in
            (
                subject: id.flatMap { sid in subjects.first { $0.id == sid } },
                minutes: items.reduce(0) { $0 + $1.durationMinutes }
            )
        }
        .sorted { $0.minutes > $1.minutes }
    }

    private var subjectProgress: [(subject: Subject, rate: Double)] {
        subjects.compactMap { subject in
            let tasks = assignments.filter { $0.subjectId == subject.id }
            guard !tasks.isEmpty else { return nil }
            return (
                subject: subject,
                rate: Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
            )
        }
        .sorted { $0.rate > $1.rate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                HStack(alignment: .top, spacing: 20) {
                    timeDistribution
                    completionChart
                }
                HStack(alignment: .top, spacing: 20) {
                    upcomingFocus
                    schedulePreview
                }
            }
            .padding(24)
        }
        .background(.clear)
        .navigationTitle("仪表盘")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewBlock) {
                    SafeSystemImage(systemName: "clock.badge.plus", fallback: "clock")
                }
                .accessibilityLabel("新建时间块")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("学习概览")
                .font(.largeTitle.bold())
            Text("掌握时间投入、完成率与接下来最值得关注的作业。")
                .foregroundStyle(.secondary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
            StatCard(
                title: "进行中",
                value: "\(active.count)",
                symbol: "list.bullet.rectangle",
                tint: .blue,
                caption: "\(assignments.count) 份作业总计"
            )
            StatCard(
                title: "今天截止",
                value: "\(dueToday.count)",
                symbol: "calendar.badge.clock",
                tint: .orange,
                caption: dueToday.isEmpty ? "今天节奏轻松" : "建议优先处理"
            )
            StatCard(
                title: "已逾期",
                value: "\(overdue.count)",
                symbol: "exclamationmark.triangle",
                tint: overdue.isEmpty ? .green : .red,
                caption: overdue.isEmpty ? "没有逾期项目" : "需要立即关注"
            )
            StatCard(
                title: "累计专注",
                value: formatMinutes(scheduledMinutes),
                symbol: "timer",
                tint: .purple,
                caption: "来自所有工作时间块"
            )
        }
    }

    private var timeDistribution: some View {
        dashboardCard("时间投入分布", subtitle: "按科目统计计划专注时长") {
            if subjectTime.isEmpty {
                emptyChart("clock", "暂无时间数据", "为作业安排工作时间块后，这里会展示投入分布。")
            } else {
                Chart(subjectTime, id: \.subject?.id) { item in
                    SectorMark(
                        angle: .value("分钟", item.minutes),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.subject.map { Color(hex: $0.colorHex) } ?? Color.gray)
                    .cornerRadius(4)
                }
                .frame(height: 235)
                HStack(spacing: 14) {
                    ForEach(subjectTime.prefix(4), id: \.subject?.id) { item in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(item.subject.map { Color(hex: $0.colorHex) } ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(item.subject?.name ?? "未分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatMinutes(item.minutes))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    private var completionChart: some View {
        dashboardCard("科目完成率", subtitle: "已完成作业占该科目全部作业的比例") {
            if subjectProgress.isEmpty {
                emptyChart("chart.bar", "暂无完成数据", "创建并完成作业后即可查看各科目表现。")
            } else {
                Chart(subjectProgress, id: \.subject.id) { item in
                    BarMark(
                        x: .value("完成率", item.rate),
                        y: .value("科目", item.subject.name)
                    )
                    .foregroundStyle(Color(hex: item.subject.colorHex))
                    .annotation(position: .trailing) {
                        Text("\(Int(item.rate * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text("\(Int(raw * 100))%")
                            }
                        }
                    }
                }
                .frame(height: 235)
            }
        }
    }

    private var upcomingFocus: some View {
        dashboardCard("智能优先", subtitle: "截止日期、优先级与自定义权重综合排序") {
            if active.isEmpty {
                emptyChart("sparkles", "没有待办作业", "完成当前任务后可以稍作休息。")
            } else {
                VStack(spacing: 12) {
                    ForEach(SmartScoring.sorted(active).prefix(5).map(\.assignment), id: \.id) { task in
                        HStack(spacing: 10) {
                            Text("\(SmartScoring.score(for: task), specifier: "%.0f")")
                                .font(.caption.monospacedDigit())
                                .frame(width: 46)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.callout.weight(.medium)).lineLimit(1)
                                HStack {
                                    SubjectBadge(subject: task.subjectId.flatMap { id in subjects.first { $0.id == id } })
                                    DueLabel(date: task.dueDate)
                                }
                            }
                            Spacer()
                            SafeSystemImage(systemName: task.priority.symbol, fallback: "exclamationmark")
                                .foregroundStyle(task.priority == .critical ? .red : .secondary)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var schedulePreview: some View {
        dashboardCard("接下来的时间块", subtitle: "未来 7 天的专注安排") {
            let upcoming = blocks
                .filter { $0.endDate >= .now && $0.startDate <= .now.addingTimeInterval(7 * 86_400) }
                .sorted { $0.startDate < $1.startDate }
                .prefix(6)
            if upcoming.isEmpty {
                emptyChart("calendar", "未来一周未安排", "把待办事项转成可执行的日程。")
            } else {
                VStack(spacing: 11) {
                    ForEach(Array(upcoming), id: \.id) { block in
                        HStack(alignment: .top, spacing: 10) {
                            VStack {
                                Text(block.startDate.formatted(.dateTime.month(.abbreviated)))
                                    .font(.caption2.bold())
                                Text(block.startDate.formatted(.dateTime.day()))
                                    .font(.title3.bold())
                            }
                            .frame(width: 42)
                            .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(block.title).font(.callout.weight(.medium)).lineLimit(1)
                                Text("\(block.startDate.formatted(date: .omitted, time: .shortened)) · \(block.durationMinutes) 分钟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func dashboardCard(_ title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyFlowGlassSurface(cornerRadius: 17)
    }

    private func emptyChart(_ symbol: String, _ title: String, _ message: String) -> some View {
        VStack(spacing: 8) {
            SafeSystemImage(systemName: symbol, fallback: "circle")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text(title).font(.callout.weight(.medium))
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 210)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = Double(minutes) / 60
        return hours < 10 ? String(format: "%.1f 小时", hours) : "\(Int(hours.rounded())) 小时"
    }
}
