import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }

    var formattedDate: String? {
        guard let raw = publishedAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: raw) else { return nil }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    var changelog: String {
        (body ?? "No changelog available.").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var versionDisplay: String {
        tagName.trimmingCharacters(in: .init(charactersIn: "v"))
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let currentVersion = "1.0.0"
    private static let apiURL = URL(string: "https://api.github.com/repos/FernandoHaeser/macos-clipboard-manager/releases/latest")!
    private static let releasePageURL = URL(string: "https://github.com/FernandoHaeser/macos-clipboard-manager/releases")!

    @Published var latestRelease: GitHubRelease?
    @Published var updateAvailable = false
    @Published var isChecking = false
    @Published var checkError: String?
    @Published var showChangelog = false

    private let defaults = UserDefaults.standard

    private var lastChecked: Date? {
        get { defaults.object(forKey: "updateLastChecked") as? Date }
        set { defaults.set(newValue, forKey: "updateLastChecked") }
    }

    private var dismissedVersion: String? {
        get { defaults.string(forKey: "updateDismissedVersion") }
        set { defaults.set(newValue, forKey: "updateDismissedVersion") }
    }

    private init() {}

    func checkOnLaunch() {
        guard PreferencesManager.shared.autoCheckUpdates else { return }
        if let last = lastChecked, Date().timeIntervalSince(last) < 86_400 { return }
        Task { await check() }
    }

    func check() async {
        isChecking = true
        checkError = nil
        defer { isChecking = false }
        do {
            var req = URLRequest(url: Self.apiURL, timeoutInterval: 10)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("ClipboardManager/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            lastChecked = Date()
            latestRelease = release
            updateAvailable = isNewer(release.tagName) && release.tagName != dismissedVersion
        } catch {
            checkError = error.localizedDescription
        }
    }

    func dismiss() {
        dismissedVersion = latestRelease?.tagName
        updateAvailable = false
    }

    func openReleasePage() {
        NSWorkspace.shared.open(Self.releasePageURL)
    }

    private func isNewer(_ tag: String) -> Bool {
        let remote = tag.trimmingCharacters(in: .init(charactersIn: "v"))
        return remote.compare(Self.currentVersion, options: .numeric) == .orderedDescending
    }
}
