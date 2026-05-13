import AppKit
import SwiftUI

@MainActor
final class PopoverController {
    private let popover = NSPopover()
    private var clickMonitor: Any?

    func setup(onPaste: @escaping (ClipboardEntry) -> Void) {
        ClipboardStore.shared.onPaste = onPaste

        let hostingVC = NSHostingController(rootView: ContentView())
        hostingVC.view.frame = NSRect(x: 0, y: 0, width: 440, height: 540)

        popover.contentViewController = hostingVC
        popover.contentSize = NSSize(width: 440, height: 540)
        popover.behavior = .applicationDefined
        popover.animates = true
    }

    var isShown: Bool { popover.isShown }

    func show(relativeTo button: NSStatusBarButton) {
        ClipboardStore.shared.searchQuery = ""
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    func close() {
        popover.performClose(nil)
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }
}
