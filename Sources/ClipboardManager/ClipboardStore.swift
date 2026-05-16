import AppKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var searchQuery: String = ""

    var filtered: [ClipboardEntry] {
        let sorted = pinnedFirst(entries)
        guard !searchQuery.isEmpty else { return sorted }
        return sorted.filter { $0.searchableText.localizedCaseInsensitiveContains(searchQuery) }
    }

    var onPaste: ((ClipboardEntry) -> Void)?

    private let storageURL: URL
    private let imagesDir: URL
    private var maxEntries: Int { PreferencesManager.shared.maxHistory }

    private init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("history.json")
        imagesDir = dir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Add

    func addText(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let topUnpinned = entries.first { !$0.isPinned }
        guard topUnpinned?.text != content else { return }
        entries.removeAll { $0.type == .text && $0.text == content && !$0.isPinned }
        let entry = ClipboardEntry.makeText(content)
        insert(entry)
        if entry.isURL {
            fetchLinkPreview(for: entry.id, urlString: content)
        }
    }

    func updateLinkPreview(id: UUID, preview: LinkPreview) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].linkPreview = preview
        save()
    }

    private func fetchLinkPreview(for id: UUID, urlString: String) {
        Task {
            guard let preview = await LinkPreviewFetcher.shared.fetch(urlString: urlString) else {
                return
            }
            updateLinkPreview(id: id, preview: preview)
        }
    }

    func addImage(_ image: NSImage) {
        guard let thumb = image.resized(maxDimension: 500),
            let png = thumb.pngData
        else { return }
        let fileName = "\(UUID().uuidString).png"
        try? png.write(to: imagesDir.appendingPathComponent(fileName))
        insert(.makeImage(fileName: fileName))
    }

    func addFile(_ url: URL) {
        guard
            entries.first(where: { $0.type == .file && $0.fileURLString == url.absoluteString })
                == nil
        else { return }
        insert(.makeFile(url: url))
    }

    private func insert(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        trimUnpinned()
        save()
        syncToiCloud()
    }

    private func trimUnpinned() {
        var unpinned = entries.filter { !$0.isPinned }
        while unpinned.count > maxEntries {
            let victim = unpinned.removeLast()
            if victim.type == .image, let fn = victim.imageFileName {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(fn))
            }
            entries.removeAll { $0.id == victim.id }
        }
    }

    // MARK: - Actions

    func paste(_ entry: ClipboardEntry) {
        onPaste?(entry)
    }

    func togglePin(_ entry: ClipboardEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].isPinned.toggle()
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        if entry.type == .image, let fn = entry.imageFileName {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(fn))
        }
        entries.removeAll { $0.id == entry.id }
        save()
        syncToiCloud()
    }

    func clear() {
        let pinned = entries.filter { $0.isPinned }
        for e in entries.filter({ !$0.isPinned }) {
            if e.type == .image, let fn = e.imageFileName {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(fn))
            }
        }
        entries = pinned
        save()
        syncToiCloud()
    }

    // MARK: - Image loading

    func loadImage(for entry: ClipboardEntry) async -> NSImage? {
        guard entry.type == .image, let fn = entry.imageFileName else { return nil }
        let url = imagesDir.appendingPathComponent(fn)
        return await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        let url = storageURL
        Task.detached(priority: .utility) {
            try? data.write(to: url)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = decoded
    }

    // MARK: - iCloud Drive sync (no entitlements required)

    private func syncToiCloud() {
        guard PreferencesManager.shared.iCloudSyncEnabled else { return }
        let syncable = entries.filter { $0.type == .text }
        guard let data = try? JSONEncoder().encode(syncable) else { return }
        Task.detached(priority: .background) {
            let iCloudRoot = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            guard FileManager.default.fileExists(atPath: iCloudRoot.path) else { return }
            let syncDir = iCloudRoot.appendingPathComponent("ClipboardManager")
            try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)
            try? data.write(to: syncDir.appendingPathComponent("history.json"))
        }
    }

    // MARK: - Helpers

    private func pinnedFirst(_ list: [ClipboardEntry]) -> [ClipboardEntry] {
        list.filter { $0.isPinned } + list.filter { !$0.isPinned }
    }
}
