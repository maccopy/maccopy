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

## Quick Start

```bash
./run.sh
```

`run.sh` runs `swift build -c release` and launches the binary.

Or manually:

```bash
swift build -c release
.build/release/ClipboardManager
```

---

## First-Run Permissions

macOS will prompt for two permissions. Grant both for full functionality:

| Permission | Path | Needed for |
|---|---|---|
| **Accessibility** | System Settings → Privacy & Security → Accessibility | Simulating ⌘V keystroke to paste |
| **Input Monitoring** | System Settings → Privacy & Security → Input Monitoring | Global hotkey (⌘⇧V) detection |

Add the **Terminal** app (or whichever terminal you use to run `./run.sh`) to both lists.

After granting, re-run `./run.sh`.

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
├── run.sh                                # Build + launch script
└── README.md
```

---

## How It Works

```
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
- Must run from a terminal with Accessibility + Input Monitoring permissions granted

---

## Roadmap (post-MVP)

- [ ] Build as proper `.app` bundle with Xcode so permissions attach to the app, not the terminal
- [ ] Image and file clipboard support
- [ ] Preferences window (hotkey, max history, launch at login)
- [ ] Keyboard navigation (arrow keys + Enter to paste)
- [ ] Pin/favourite items
- [ ] iCloud sync via CloudKit
# macos-clipboard-manager
