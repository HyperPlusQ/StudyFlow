import SwiftUI

struct IconPicker: View {
    @Binding var selection: String
    let icons: [String]
    let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    SafeSystemImage(systemName: icon, fallback: "circle")
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 30, height: 30)
                        .background(selection == icon ? Color.accentColor.opacity(0.18) : Color.clear)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(selection == icon ? Color.accentColor : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel(icon)
                .accessibilityAddTraits(selection == icon ? .isSelected : [])
                .help(icon)
            }
        }
    }
}

struct ColorSwatchPicker: View {
    @Binding var selection: String
    let colors: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(colors, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                        if selection == hex {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.readableForeground(onHex: hex))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle().inset(by: 11))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("颜色 \(hex)")
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
                .help(hex)
            }
        }
    }
}
