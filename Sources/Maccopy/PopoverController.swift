import AppKit
import SwiftUI

@MainActor
final class PopoverController {
    private let popover = NSPopover()
    private var clickMonitor: Any?

    func setup(onPaste: @escaping (ClipboardEntry) -> Void) {
        ClipboardStore.shared.onPaste = onPaste

        let prefs = PreferencesManager.shared
        let hostingVC = NSHostingController(rootView: ContentView())
        hostingVC.view.frame = NSRect(x: 0, y: 0, width: prefs.popoverWidth, height: prefs.popoverHeight)

        popover.contentViewController = hostingVC
        popover.contentSize = NSSize(width: prefs.popoverWidth, height: prefs.popoverHeight)
        popover.behavior = .applicationDefined
        popover.animates = true
    }

    var isShown: Bool { popover.isShown }

    func show(relativeTo button: NSStatusBarButton) {
        ClipboardStore.shared.searchQuery = ""

        // Sync size in case preference changed since last open
        let prefs = PreferencesManager.shared
        popover.contentSize = NSSize(width: prefs.popoverWidth, height: prefs.popoverHeight)

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Window is created asynchronously by NSPopover; configure on next runloop tick
        DispatchQueue.main.async { self.configurePopoverWindow() }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    // Make the NSPopover window fully transparent so SwiftUI controls all background rendering.
    // Without this, the popover's own NSVisualEffectView blends with the opaque window
    // background, making semi-transparent SwiftUI backgrounds blend against white/black
    // instead of the actual screen content behind the popover.
    private func configurePopoverWindow() {
        guard let window = popover.contentViewController?.view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // Match window appearance to the user's preference so NSScrollView scroll
        // indicators (and other AppKit widgets) use the correct light/dark rendering.
        window.appearance = PreferencesManager.shared.appearanceMode.nsAppearance

        // Disable the popover's own visual effect view so SwiftUI .background(...)
        // (regularMaterial or solid color) has sole control over the appearance.
        if let effectView = window.contentView?.subviews
            .first(where: { $0 is NSVisualEffectView }) as? NSVisualEffectView
        {
            effectView.isHidden = true
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
