import AppKit
import SwiftUI

/// Verifies SF Symbol availability on the current macOS runtime and provides
/// stable native fallbacks so a missing glyph never renders as a blank slot.
enum PlatformSymbolAvailability {
    static func contains(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
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

struct SafeSystemImage: View {
    let systemName: String
    var fallback = "book.closed"

    var body: some View {
        Image(systemName: PlatformSymbolAvailability.resolve(systemName, fallback: fallback))
    }
}
