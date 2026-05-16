import Foundation
import AppKit

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
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

    static let currentVersion = "1.1.2"
    private static let apiURL = URL(string: "https://api.github.com/repos/maccopy/maccopy/releases/latest")!
    private static let releasePageURL = URL(string: "https://github.com/maccopy/maccopy/releases")!

    @Published var latestRelease: GitHubRelease?
    @Published var updateAvailable = false
    @Published var isChecking = false
    @Published var checkError: String?
    @Published var showChangelog = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadError: String?

    var zipAsset: GitHubAsset? {
        latestRelease?.assets.first { $0.name.hasSuffix(".zip") }
    }

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
            req.setValue("Maccopy/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            lastChecked = Date()
            latestRelease = release
            let newer = isNewer(release.tagName) && release.tagName != dismissedVersion
            updateAvailable = newer
            if newer {
                downloadAndInstall()
            }
        } catch {
            checkError = error.localizedDescription
        }
    }

    func dismiss() {
        dismissedVersion = latestRelease?.tagName
        updateAvailable = false
    }

    func downloadAndInstall() {
        guard let asset = zipAsset else {
            openReleasePage()
            return
        }
        guard let downloadURL = URL(string: asset.browserDownloadUrl) else { return }

        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        Task.detached(priority: .userInitiated) {
            do {
                let tmpDir = FileManager.default.temporaryDirectory
                let zipDest = tmpDir.appendingPathComponent(asset.name)
                let extractDir = tmpDir.appendingPathComponent("CMUpdate_\(UUID().uuidString)")

                // Download
                let (localURL, _) = try await URLSession.shared.download(from: downloadURL)
                try? FileManager.default.removeItem(at: zipDest)
                try FileManager.default.moveItem(at: localURL, to: zipDest)

                await MainActor.run { self.downloadProgress = 0.5 }

                // Extract
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzip.arguments = ["-q", "-o", zipDest.path, "-d", extractDir.path]
                try unzip.run()
                unzip.waitUntilExit()

                await MainActor.run { self.downloadProgress = 0.8 }

                let appSrc = extractDir.appendingPathComponent("Maccopy.app")
                guard FileManager.default.fileExists(atPath: appSrc.path) else {
                    throw NSError(domain: "UpdateChecker", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Maccopy.app not found in archive"])
                }

                let currentApp = Bundle.main.bundleURL.path
                let script = """
                #!/bin/bash
                sleep 1.5
                rm -rf '\(currentApp)'
                cp -R '\(appSrc.path)' '\(currentApp)'
                xattr -rd com.apple.quarantine '\(currentApp)' 2>/dev/null || true
                open '\(currentApp)'
                """
                let scriptPath = tmpDir.appendingPathComponent("cm_update.sh").path
                try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: scriptPath)

                await MainActor.run { self.downloadProgress = 1.0 }

                let releaseData = await MainActor.run { try? JSONEncoder().encode(self.latestRelease) }
                if let releaseData {
                    UserDefaults.standard.set(releaseData, forKey: "pendingChangelog")
                }

                let launcher = Process()
                launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
                launcher.arguments = [scriptPath]
                try launcher.run()

                await MainActor.run { NSApp.terminate(nil) }

            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadError = error.localizedDescription
                }
            }
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(Self.releasePageURL)
    }

    private func isNewer(_ tag: String) -> Bool {
        let remote = tag.trimmingCharacters(in: .init(charactersIn: "v"))
        return remote.compare(Self.currentVersion, options: .numeric) == .orderedDescending
    }
}
