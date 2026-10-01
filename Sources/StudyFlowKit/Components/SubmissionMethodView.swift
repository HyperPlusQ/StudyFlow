import SwiftUI

struct SubmissionMethodView: View {
    let value: String
    var compact = false

    var body: some View {
        if let target = SubmissionMethodResolver.target(for: value) {
            Link(destination: target.destination) {
                Label {
                    Text(value)
                        .lineLimit(1)
                        .underline()
                } icon: {
                    SafeSystemImage(systemName: target.systemSymbol, fallback: "link")
                }
                .font(compact ? .caption : .callout)
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        } else if value.isEmpty {
            if compact {
                EmptyView()
            } else {
                Text("未填写").foregroundStyle(.tertiary)
            }
        } else {
            Label {
                Text(value)
                    .lineLimit(compact ? 1 : nil)
            } icon: {
                SafeSystemImage(systemName: "paperplane", fallback: "envelope")
            }
            .font(compact ? .caption : .callout)
            .foregroundStyle(compact ? .tertiary : .primary)
        }
    }

    private func helpText(for target: SubmissionMethodTarget) -> String {
        switch target {
        case .url:
            "在系统默认浏览器中打开"
        case .email:
            "在系统默认邮件应用中新建邮件"
        }
    }
}
