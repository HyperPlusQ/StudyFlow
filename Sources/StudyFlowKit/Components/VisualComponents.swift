import Foundation
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

    /// 根据十六进制背景的相对亮度选择对比度更高的前景色，避免浅色背景上的固定白色不可读。
    static func readableForeground(onHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return .primary }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return .primary }

        func linearized(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        let red = linearized(Double((value >> 16) & 0xFF) / 255)
        let green = linearized(Double((value >> 8) & 0xFF) / 255)
        let blue = linearized(Double(value & 0xFF) / 255)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        let contrastWithWhite = 1.05 / (luminance + 0.05)
        let contrastWithBlack = (luminance + 0.05) / 0.05
        return contrastWithWhite >= contrastWithBlack ? .white : .black
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
            SafeSystemImage(
                systemName: subject?.symbol ?? "square.dashed",
                fallback: "square.dashed"
            )
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
        .accessibilityLabel("完成进度")
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
                HStack(spacing: 6) {
                    SafeSystemImage(systemName: symbol, fallback: "circle")
                    Text(title)
                }
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
                .studyFlowGlassSurface(cornerRadius: 20)
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
            SafeSystemImage(systemName: symbol, fallback: "tray")
                .font(.system(.largeTitle, design: .default).weight(.light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .studyFlowGlassButtonStyle(prominent: true)
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
                SafeSystemImage(systemName: systemImage, fallback: "circle")
                    .foregroundStyle(.secondary)
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
