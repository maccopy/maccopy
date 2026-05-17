import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private let popover = PopoverController()
    private let monitor = ClipboardMonitor()
    private var hotkey: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusItem()

        popover.setup { [weak self] entry in
            self?.performPaste(entry)
        }

        monitor.start()

        let combo = PreferencesManager.shared.hotkey
        hotkey = HotkeyManager(combo: combo) { [weak self] in self?.togglePopover() }
        hotkey.register()

        // Register with TCC on every launch so the app appears in Privacy panes.
        // These calls are safe to repeat — they only prompt once per permission state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Accessibility: needed for CGEvent paste simulation
            if !PermissionRequester.accessibilityGranted {
                PermissionRequester.requestAccessibility()
            }
            // Input Monitoring: needed for global hotkey
            if !PermissionRequester.inputMonitoringGranted {
                PermissionRequester.requestInputMonitoring()
            }
        }

        if !PreferencesManager.shared.hasCompletedSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                SetupWizardWindowController.show()
            }
        }

        PreferencesManager.shared.applyAppearance()

        if let data = UserDefaults.standard.data(forKey: "pendingChangelog"),
            let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
        {
            UserDefaults.standard.removeObject(forKey: "pendingChangelog")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ChangelogWindowController.show(release: release)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkOnLaunch()
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        updateStatusBarIcon()
        button.action = #selector(handleStatusClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let style = PreferencesManager.shared.statusBarIconStyle
        if style == .maccopy {
            button.image = makeMaccopyStatusIcon()
        } else {
            let img = NSImage(systemSymbolName: style.symbolName, accessibilityDescription: "Maccopy")
            img?.isTemplate = true
            button.image = img
        }
        // Force white icon regardless of system theme
        button.appearance = NSAppearance(named: .darkAqua)
    }

    private func makeMaccopyStatusIcon() -> NSImage {
        // Shape bounding box in SVG 100×100 viewBox:
        //   x: 27–67 (w=40), y top-down: 15–66 (h=51)
        // Scale to fill ~14px within 18px, constrained by height (taller than wide).
        // s=0.215 gives h=51*0.215≈11px; ox/oy center the shape.
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let s: CGFloat = 0.215
            let ox: CGFloat = -1.1  // horizontal centering offset
            let oy: CGFloat = -2.0  // vertical centering offset
            let flip: CGFloat = 100

            // Back page (semi-transparent)
            let backPage = NSBezierPath(
                roundedRect: NSRect(
                    x: ox + 35 * s, y: oy + (flip - 40 - 40) * s,
                    width: 32 * s, height: 40 * s),
                xRadius: 5 * s, yRadius: 5 * s)
            NSColor.white.withAlphaComponent(0.5).set()
            backPage.fill()

            // Front page
            let frontPage = NSBezierPath(
                roundedRect: NSRect(
                    x: ox + 27 * s, y: oy + (flip - 34 - 40) * s,
                    width: 32 * s, height: 40 * s),
                xRadius: 5 * s, yRadius: 5 * s)
            NSColor.white.set()
            frontPage.fill()

            // Leaf / tab at top of front page
            let leaf = NSBezierPath()
            leaf.move(to: NSPoint(x: ox + 43 * s, y: oy + (flip - 34) * s))
            leaf.curve(
                to: NSPoint(x: ox + 53 * s, y: oy + (flip - 15) * s),
                controlPoint1: NSPoint(x: ox + 43 * s, y: oy + (flip - 26) * s),
                controlPoint2: NSPoint(x: ox + 47 * s, y: oy + (flip - 18) * s))
            leaf.curve(
                to: NSPoint(x: ox + 43 * s, y: oy + (flip - 34) * s),
                controlPoint1: NSPoint(x: ox + 54 * s, y: oy + (flip - 22) * s),
                controlPoint2: NSPoint(x: ox + 51 * s, y: oy + (flip - 29) * s))
            leaf.close()
            NSColor.white.set()
            leaf.fill()

            return true
        }
        img.isTemplate = false
        return img
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

        let hotDisplay = PreferencesManager.shared.hotkey.displayString
        let open = NSMenuItem(title: "Open History  (\(hotDisplay))", action: #selector(togglePopover), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferencesAction), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        menu.addItem(prefsItem)

        let wizardItem = NSMenuItem(title: "Setup Wizard…", action: #selector(openWizardAction), keyEquivalent: "")
        wizardItem.target = self
        menu.addItem(wizardItem)
        menu.addItem(.separator())

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistoryAction), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Maccopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Actions

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button)
        }
    }

    @objc private func openPreferencesAction() { openPreferences() }

    func openPreferences() {
        popover.close()
        PreferencesWindowController.show()
    }

    @objc private func openWizardAction() {
        popover.close()
        SetupWizardWindowController.show()
    }

    @objc private func clearHistoryAction() {
        ClipboardStore.shared.clear()
    }

    // MARK: - Paste

    private func performPaste(_ entry: ClipboardEntry) {
        if entry.type == .image {
            Task {
                let pb = NSPasteboard.general
                pb.clearContents()
                if let image = await ClipboardStore.shared.loadImage(for: entry) {
                    pb.writeObjects([image])
                }
                await MainActor.run { triggerPaste() }
            }
            return
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.type {
        case .text:
            if let text = entry.text { pb.setString(text, forType: .string) }
        case .file:
            if let url = entry.fileURL { pb.writeObjects([url as NSURL]) }
        case .image:
            break
        }
        triggerPaste()
    }

    private func triggerPaste() {
        popover.close()
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
