import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.31; g = 0.49; b = 0.95
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension Date {
    var dueLabel: String {
        if isInSameDay(as: .now) { return "今天" }
        if Calendar.current.isDateInTomorrow(self) { return "明天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if Calendar.current.isDate(self, equalTo: .now, toGranularity: .year) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月d日"
        }
        return formatter.string(from: self)
    }

    var dueDateTimeLabel: String {
        "\(dueLabel) \(formatted(date: .omitted, time: .shortened))"
    }
}

struct SubjectBadge: View {
    let subject: Subject?
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: subject?.symbol ?? "square.dashed")
                .font(.caption2)
                .foregroundStyle(subject.map { Color(hex: $0.colorHex) } ?? .secondary)
            if !compact {
                Text(subject?.name ?? "未分类")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}

struct DueLabel: View {
    let date: Date?
    var completed = false

    var body: some View {
        if completed {
            Label("已完成", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        } else if let date {
            let overdue = date < .now
            Label(date.dueLabel, systemImage: overdue ? "exclamationmark.triangle.fill" : "clock")
                .foregroundStyle(overdue ? .red : .secondary)
                .font(.caption)
                .fontWeight(overdue ? .semibold : .regular)
        } else {
            Label("无日期", systemImage: "minus.circle")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    var tint = Color.accentColor

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .accentColor
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}
