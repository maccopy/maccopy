# Clipboard Manager

Native macOS clipboard history manager — POC/MVP inspired by [Maccy](https://maccy.app/).

Built with **Swift + AppKit + SwiftUI**. Runs as a menu bar app with no Dock icon.

---

## Features

| Feature | Details |
|---|---|
| Clipboard history | Up to 50 text items |
| Persistent storage | JSON at `~/Library/Application Support/ClipboardManager/history.json` |
| Global hotkey | **⌘ Shift V** |
| Live search | Filter by typing — updates instantly |
| Paste | Double-click any row → sets clipboard + fires ⌘V into the focused app |
| Delete | Hover a row → trash icon removes that entry |
| Menu bar icon | `doc.on.clipboard.fill` SF Symbol |
| Right-click menu | Open / Clear History / Quit |

---

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)

---

## Install (one command)

```bash
bash install.sh
```

`install.sh`:
1. Builds release binary via `swift build`
2. Packages `ClipboardManager.app` into `~/Applications/`
3. Installs a LaunchAgent → auto-starts at login
4. Opens System Settings for the two required permissions
5. Launches the app

Permissions attach to the `.app` bundle, not the terminal.

**Uninstall:**
```bash
bash uninstall.sh
```

---

## Manual run (dev/testing)

```bash
./run.sh
```

Builds and launches the raw binary (no `.app`, permissions attach to terminal).

---

## First-Run Permissions

Two permissions required — `install.sh` opens System Settings automatically:

| Permission | Path | Needed for |
|---|---|---|
| **Accessibility** | System Settings → Privacy & Security → Accessibility | Simulating ⌘V keystroke to paste |
| **Input Monitoring** | System Settings → Privacy & Security → Input Monitoring | Global hotkey (⌘⇧V) detection |

Add `~/Applications/ClipboardManager.app` to both lists.

---

## Usage

| Action | How |
|---|---|
| Open/close history | **⌘ Shift V** from any app |
| Open via menu bar | Click `📋` icon |
| Paste an item | **Double-click** the row |
| Search | Type in the search box at the top |
| Delete one item | Hover the row → click trash icon |
| Clear all | Footer → **Clear All** or right-click icon → Clear History |
| Quit | Footer → **Quit** or right-click icon → Quit |

---

## Project Structure

```
clipboard-manager/
├── Package.swift                         # Swift Package Manifest (macOS 14+, links Carbon)
├── Sources/ClipboardManager/
│   ├── main.swift                        # NSApplication setup and entry point
│   ├── AppDelegate.swift                 # Status bar, popover toggle, paste logic
│   ├── ClipboardStore.swift              # @MainActor ObservableObject — history + JSON persistence
│   ├── ClipboardMonitor.swift            # Timer-based NSPasteboard polling (0.5 s)
│   ├── HotkeyManager.swift               # Carbon RegisterEventHotKey (⌘⇧V)
│   ├── PopoverController.swift           # NSPopover lifecycle + outside-click-to-close
│   ├── ContentView.swift                 # SwiftUI root: search bar + list + footer
│   └── ClipboardRowView.swift            # SwiftUI row: preview text + hover actions
├── install.sh                            # One-command installer: build → .app bundle → LaunchAgent → permissions
├── uninstall.sh                          # Removes app, LaunchAgent, optionally history data
├── run.sh                                # Dev runner: build + launch raw binary
└── README.md
```

---

## How It Works

```text
NSPasteboard.general
      │  polled every 500 ms via Timer
      ▼
ClipboardMonitor.poll()
      │  changeCount differs → read string
      ▼
ClipboardStore.add(_:)         @MainActor
      │  deduplicates, prepends, trims to 50, saves JSON
      ▼
ContentView (SwiftUI)          @ObservedObject redraws automatically

──── User picks an item ────

double-click row
      │
AppDelegate.performPaste(_:)
      ├── NSPasteboard.general.setString(...)
      ├── popover.close()
      └── DispatchQueue.main.asyncAfter(0.15 s)
            └── CGEvent(keyboardEventSource:, virtualKey: 0x09 'V', keyDown: true/false)
                  flags = .maskCommand
                  post(tap: .cghidEventTap)
```

---

## Architecture Notes

- **No Dock icon** — `NSApp.setActivationPolicy(.accessory)` in `main.swift`
- **Left click** status item → toggle popover; **right click** → context NSMenu
- `PopoverController` sets `behavior = .applicationDefined` and closes on the first global mouse-down outside the popover
- `ClipboardStore.onPaste` is a closure set by `AppDelegate` during setup — decouples SwiftUI from AppKit paste logic
- `HotkeyManager` uses Carbon's `RegisterEventHotKey` (no Accessibility needed for the hotkey itself, only for CGEvent paste simulation)

---

## Known Limitations (MVP)

- Text only — images, files, rich text not captured
- No configurable hotkey (hardcoded ⌘⇧V)
- No item pinning / favourites
- No dark/light mode accent customisation beyond system defaults

---

## Roadmap (post-MVP)

- [x] Build as proper `.app` bundle so permissions attach to the app, not the terminal (`install.sh`)
- [ ] Image and file clipboard support
- [ ] Preferences window (hotkey, max history, launch at login)
- [ ] Keyboard navigation (arrow keys + Enter to paste)
- [ ] Pin/favourite items
- [ ] iCloud sync via CloudKit
