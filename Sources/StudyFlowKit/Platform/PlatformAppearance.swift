import SwiftUI

#if os(macOS)
import AppKit

extension Color {
    static var studyFlowWindowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var studyFlowControlBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}
#elseif os(iOS)
import UIKit

extension Color {
    static var studyFlowWindowBackground: Color {
        Color(uiColor: .systemBackground)
    }

    static var studyFlowControlBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }
}
#endif

enum PlatformSymbolAvailability {
    static func contains(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        #if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #elseif os(iOS)
        return UIImage(systemName: name) != nil
        #else
        return false
        #endif
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

/// Replaces missing or unavailable SF Symbols with a stable native fallback.
struct SafeSystemImage: View {
    let systemName: String
    var fallback = "book.closed"

    var body: some View {
        Image(systemName: PlatformSymbolAvailability.resolve(systemName, fallback: fallback))
    }
}

/// A restrained, color-aware backdrop shared by the split view and inspector.
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

extension View {
    /// Uses Apple's native Liquid Glass button on supported systems, with a
    /// larger continuous-corner bordered fallback on earlier releases.
    @ViewBuilder
    func studyFlowGlassButtonStyle(
        prominent: Bool = false,
        cornerRadius: CGFloat = 18
    ) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
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

    @ViewBuilder
    func studyFlowGlassSurface(cornerRadius: CGFloat = 20, prominent: Bool = false) -> some View {
        let radius = max(cornerRadius, 20)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(macOS 26.0, iOS 26.0, *) {
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
        #if os(macOS)
        if #available(macOS 26.0, *) {
            // Preserve the system toolbar's native Liquid Glass material.
            self
        } else if #available(macOS 15.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            toolbarBackground(.hidden, for: .windowToolbar)
        }
        #else
        if #available(iOS 26.0, *) {
            // Preserve the system navigation bar's native Liquid Glass material.
            self
        } else if #available(iOS 18.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            toolbarBackground(.hidden, for: .navigationBar)
        }
        #endif
    }
}

extension View {
    /// Uses a fixed native sheet size on macOS and a full-screen adaptive
    /// detent on iOS so the same editor works on every screen ratio.
    @ViewBuilder
    func platformSheetFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(iOS)
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        #else
        self.frame(width: width, height: height)
        #endif
    }

    /// `.help` is a macOS presentation affordance; keeping the call behind a
    /// shared helper prevents the shared target from depending on AppKit.
    @ViewBuilder
    func platformHelp(_ text: String) -> some View {
        #if os(macOS)
        help(text)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformCheckboxStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.switch)
        #endif
    }
}

extension View {
    /// `.buttonStyle(.link)` is a macOS-only affordance.
    @ViewBuilder
    func platformNavigationSubtitle(_ text: String) -> some View {
        #if os(macOS)
        navigationSubtitle(text)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformLinkButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.link)
        #else
        buttonStyle(.borderless)
        #endif
    }
}
