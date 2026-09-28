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

extension View {
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
