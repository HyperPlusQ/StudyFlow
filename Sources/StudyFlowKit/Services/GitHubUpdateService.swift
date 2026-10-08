import Foundation

enum UpdateCheckState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(version: String, url: URL)
    case failed(message: String)
}

enum GitHubUpdateService {
    struct ReleaseInfo: Equatable, Sendable {
        let version: String
        let url: URL
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private struct GitHubTag: Decodable {
        let name: String
    }

    private struct GitHubAPIError: Error, Sendable {
        let statusCode: Int
    }

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/HyperPlusQ/StudyFlow/releases/latest"
    )!
    private static let tagsURL = URL(
        string: "https://api.github.com/repos/HyperPlusQ/StudyFlow/tags?per_page=30"
    )!

    /// 与 Xcode 工程版本保持一致，应用包缺失时也能报告正确版本。
    static let bundledVersion = "1.6.1"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? bundledVersion
    }

    static var projectURL: URL {
        URL(string: "https://github.com/HyperPlusQ/StudyFlow")!
    }

    static var releasesURLString: String {
        "https://github.com/HyperPlusQ/StudyFlow/releases"
    }

    /// 查询 GitHub 最新版本并比较当前版本。
    static func checkForUpdates() async -> UpdateCheckState {
        do {
            let latest = try await fetchLatestRelease()
            let latestVersion = normalizedVersion(latest.version)
            if isNewer(latestVersion, than: normalizedVersion(currentVersion)) {
                return .updateAvailable(version: latestVersion, url: latest.url)
            }
            return .upToDate(version: normalizedVersion(currentVersion))
        } catch let error as GitHubAPIError where error.statusCode == 404 {
            do {
                let latest = try await fetchLatestTag()
                let latestVersion = normalizedVersion(latest.version)
                if isNewer(latestVersion, than: normalizedVersion(currentVersion)) {
                    return .updateAvailable(version: latestVersion, url: latest.url)
                }
                return .upToDate(version: normalizedVersion(currentVersion))
            } catch {
                return .failed(message: friendlyMessage(for: error))
            }
        } catch {
            return .failed(message: friendlyMessage(for: error))
        }
    }

    static func normalizedVersion(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    /// 按语义版本判断新版本是否更新。
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = semanticComponents(lhs)
        let right = semanticComponents(rhs)
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue != rightValue { return leftValue > rightValue }
        }
        return false
    }

    private static func fetchLatestRelease() async throws -> ReleaseInfo {
        let release: GitHubRelease = try await fetch(releasesURL)
        guard let url = URL(string: release.htmlURL) else {
            throw GitHubAPIError(statusCode: 500)
        }
        return ReleaseInfo(version: release.tagName, url: url)
    }

    private static func fetchLatestTag() async throws -> ReleaseInfo {
        let tags: [GitHubTag] = try await fetch(tagsURL)
        let candidates = tags
            .map { normalizedVersion($0.name) }
            .filter { semanticComponents($0).count >= 2 }
        guard let newest = candidates.max(by: { compareVersions($0, $1) == .orderedAscending }),
              let url = URL(string: "https://github.com/HyperPlusQ/StudyFlow/tree/\(newest)")
        else {
            throw GitHubAPIError(statusCode: 404)
        }
        return ReleaseInfo(version: newest, url: url)
    }

    private static func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("StudyFlow-Update-Checker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubAPIError(statusCode: http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func semanticComponents(_ version: String) -> [Int] {
        version
            .split(separator: "-", maxSplits: 1)
            .first?
            .split(separator: ".")
            .compactMap { Int($0) } ?? []
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = semanticComponents(lhs)
        let right = semanticComponents(rhs)
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let apiError = error as? GitHubAPIError {
            switch apiError.statusCode {
            case 403, 429: "GitHub API 请求次数受限，请稍后重试。"
            case 404: "未找到 StudyFlow 的公开版本。"
            default: "GitHub 返回错误（HTTP \(apiError.statusCode)）。"
            }
        } else {
            "无法连接 GitHub，请检查网络连接后重试。"
        }
    }
}
