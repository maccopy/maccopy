import AppKit

final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = -1

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        Task { @MainActor in
            let store = ClipboardStore.shared

            // File URLs take priority
            if let urls = pb.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL], !urls.isEmpty {
                for url in urls { store.addFile(url) }
                return
            }

            // Images next
            if let image = NSImage(pasteboard: pb) {
                // Only capture if no string representation (avoid capturing icons from file copy)
                if pb.string(forType: .string) == nil {
                    store.addImage(image)
                    return
                }
            }

            // Fall through to text
            if let text = pb.string(forType: .string) {
                store.addText(text)
            }
        }
    }
}
