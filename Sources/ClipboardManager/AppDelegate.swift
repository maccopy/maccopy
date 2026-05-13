import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = PopoverController()
    private let monitor = ClipboardMonitor()
    private var hotkey: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        popover.setup { [weak self] entry in
            self?.performPaste(entry)
        }

        monitor.start()

        hotkey = HotkeyManager { [weak self] in self?.togglePopover() }
        hotkey.register()
    }

    // ── Status bar ────────────────────────────────────────────────────────────

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Clipboard Manager")
        img?.isTemplate = true
        button.image = img
        button.action = #selector(handleStatusClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover()
        }
    }

    private func showContextMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open History   ⌘⇧V", action: #selector(togglePopover), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Clipboard Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Attach temporarily so NSStatusItem positions it correctly
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button)
        }
    }

    @objc private func clearHistory() {
        ClipboardStore.shared.clear()
    }

    // ── Paste ─────────────────────────────────────────────────────────────────

    private func performPaste(_ entry: ClipboardEntry) {
        // Write to clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.text, forType: .string)

        // Close popover first so previous app can regain focus
        popover.close()

        // Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard
                let src = CGEventSource(stateID: .hidSystemState),
                let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
                let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            else { return }

            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotkey.unregister()
    }
}
