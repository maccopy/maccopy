import AppKit
import Foundation

struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let date: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var searchQuery: String = ""

    var filtered: [ClipboardEntry] {
        guard !searchQuery.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }

    private let maxEntries = 50
    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    var onPaste: ((ClipboardEntry) -> Void)?

    private init() { load() }

    func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard entries.first?.text != text else { return }

        entries.insert(ClipboardEntry(text: text), at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func paste(_ entry: ClipboardEntry) {
        onPaste?(entry)
    }

    func clear() {
        entries.removeAll()
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
