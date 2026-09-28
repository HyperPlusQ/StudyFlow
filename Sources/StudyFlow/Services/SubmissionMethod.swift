import AppKit
import Foundation

enum SubmissionMethodTarget: Equatable, Sendable {
    case url(URL)
    case email(String)

    var destination: URL {
        switch self {
        case let .url(url): url
        case let .email(address): URL(string: "mailto:\(address)") ?? URL(string: "about:blank")!
        }
    }

    var systemSymbol: String {
        switch self {
        case .url: "safari"
        case .email: "envelope"
        }
    }
}

enum SubmissionMethodResolver {
    static func target(for rawValue: String) -> SubmissionMethodTarget? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let lowered = value.lowercased()
        if lowered.hasPrefix("mailto:") {
            return emailTarget(in: value)
        }
        if lowered.hasPrefix("http://")
            || lowered.hasPrefix("https://")
            || lowered.hasPrefix("www.") {
            return urlTarget(in: value)
        }
        if let mailTarget = emailTarget(in: value) {
            return mailTarget
        }
        return urlTarget(in: value)
    }

    static func open(_ rawValue: String) {
        guard let target = target(for: rawValue) else { return }
        NSWorkspace.shared.open(target.destination)
    }

    private static func emailTarget(in value: String) -> SubmissionMethodTarget? {
        if value.lowercased().hasPrefix("mailto:") {
            let address = String(value.dropFirst(7))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidEmail(address) else { return nil }
            return .email(address)
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let matchRange = Range(match.range, in: value) else { return nil }

        let address = String(value[matchRange])
        return isValidEmail(address) ? .email(address) : nil
    }

    private static func urlTarget(in value: String) -> SubmissionMethodTarget? {
        guard !value.contains(where: \.isWhitespace) else { return nil }

        let candidate: String
        if value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://") {
            candidate = value
        } else if value.lowercased().hasPrefix("www.") {
            candidate = "https://\(value)"
        } else if looksLikeBareWebAddress(value) {
            candidate = "https://\(value)"
        } else {
            return nil
        }

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              host.contains(".")
        else { return nil }

        return .url(components.url ?? URL(string: candidate)!)
    }

    private static func looksLikeBareWebAddress(_ value: String) -> Bool {
        guard !value.hasPrefix("//"),
              !value.contains("://"),
              value.contains("."),
              !value.hasPrefix("."),
              !value.hasSuffix(".")
        else { return false }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-~:/?#[]@!$&'()*+,;=%"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#,
            options: [.caseInsensitive]
        ) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, range: range)?.range == range
    }
}
