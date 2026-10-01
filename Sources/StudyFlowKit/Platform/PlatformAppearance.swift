import SwiftUI

import UIKit

extension Color {
    static var studyFlowWindowBackground: Color {
        Color(uiColor: .systemBackground)
    }

    static var studyFlowControlBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }
}

enum PlatformSymbolAvailability {
    static func contains(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return UIImage(systemName: name) != nil
    }

    static func resolve(_ name: String?, fallback: String = "book.closed") -> String {
        if let name, contains(name) {
            return name
        }
        if contains(fallback) {
            return fallback
        }
        return contains("circle") ? "circle" : fallback
    }
}

/// 将缺失或当前系统不可用的 SF Symbol 替换为稳定图标。
struct SafeSystemImage: View {
    let systemName: String
    var fallback = "book.closed"

    var body: some View {
        Image(systemName: PlatformSymbolAvailability.resolve(systemName, fallback: fallback))
    }
}

/// 页面共享的低饱和度、支持动态颜色的背景。
struct StudyFlowBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.studyFlowWindowBackground

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10),
                    Color.accentColor.opacity(0)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )

            RadialGradient(
                colors: [
                    Color.purple.opacity(colorScheme == .dark ? 0.11 : 0.065),
                    Color.purple.opacity(0)
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.cyan.opacity(colorScheme == .dark ? 0.055 : 0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}


/// 透明、无填充的原生按钮样式，用于设置页操作按钮。
private struct StudyFlowTransparentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.tint)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

extension View {
    /// 支持的系统使用原生 Liquid Glass 按钮，旧系统回退为大圆角边框按钮。
    @ViewBuilder
    func studyFlowGlassButtonStyle(
        prominent: Bool = false,
        cornerRadius: CGFloat = 18
    ) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if prominent {
                buttonStyle(.borderedProminent).clipShape(shape)
            } else {
                buttonStyle(.bordered).clipShape(shape)
            }
        }
    }

    /// 设置页使用的透明按钮样式：不绘制填充和边框，仅保留系统着色与按压反馈。
    func studyFlowTransparentButtonStyle() -> some View {
        buttonStyle(StudyFlowTransparentButtonStyle())
    }

    @ViewBuilder
    func studyFlowGlassSurface(cornerRadius: CGFloat = 20, prominent: Bool = false) -> some View {
        let radius = max(cornerRadius, 20)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 26.0, *) {
            let glass: Glass = .regular
            self
                .clipShape(shape)
                .glassEffect(glass, in: shape)
        } else {
            background {
                if prominent {
                    shape.fill(.regularMaterial)
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(0.16),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
        }
    }

    @ViewBuilder
    func platformTransparentToolbar() -> some View {
        if #available(iOS 26.0, *) {
            // 保留系统导航栏自带的 Liquid Glass 材质。
            self
        } else if #available(iOS 18.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

extension View {
    /// 使用自适应全屏 Sheet，兼容不同尺寸的 iPhone 和 iPad。
    @ViewBuilder
    func platformSheetFrame() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
    }

    @ViewBuilder
    func platformCheckboxStyle() -> some View {
        toggleStyle(.switch)
    }
}
