# Clipboard Manager

Native macOS clipboard history — text, images, and files. Lives in the menu bar. Zero dependencies.

Built with **Swift + AppKit + SwiftUI**. Requires macOS 14 Sonoma or later.

---

## Install — one command

```bash
curl -fsSL https://raw.githubusercontent.com/FernandoHaeser/macos-clipboard-manager/main/install.sh | bash
```

That's it. The installer will:

1. Clone the repo to a temp directory
2. Check Swift / macOS version
3. Build a release binary
4. Generate the app icon (`AppIcon.icns`)
5. Package `ClipboardManager.app` → `~/Applications/`
6. Ad-hoc code-sign the bundle
7. Install a LaunchAgent (auto-starts at login)
8. Trigger Accessibility + Input Monitoring permission dialogs
9. Launch the app
10. Clean up the temp clone

---

## Features

| | Feature | Details |
|---|---|---|
| 📋 | **Text history** | Up to 50 items (configurable 10–500) |
| 🖼 | **Image support** | Captures images from clipboard, shows thumbnails |
| 📁 | **File support** | Captures file URLs, shows name + size |
| 📌 | **Pin / favourite** | Pin any item — stays at the top permanently |
| ⌨️ | **Keyboard navigation** | Arrow keys to move, Enter to paste, Escape to close |
| 🔍 | **Live search** | Instant filter across all item types |
| ☁️ | **iCloud Drive sync** | Syncs text history across your Macs (no entitlements needed) |
| ⚙️ | **Preferences window** | Hotkey display, history size, launch at login, iCloud toggle |
| 🧙 | **Setup Wizard** | 5-step onboarding — walks through permissions & preferences |
| 🎨 | **Custom icon** | Generated at install time via CoreGraphics |

---

## Usage

| Action | How |
|---|---|
| Open history | **⌘⇧V** from any app, or click the 📋 menu bar icon |
| Navigate | **↑ / ↓** arrow keys; **↓** from search bar jumps to list |
| Paste item | **Enter** (selected) or **double-click** any row |
| Search | Type in the search box — filters all types live |
| Pin item | Hover a row → **pin** button (orange); pinned items stay at top |
| Delete item | Hover a row → **trash** button |
| Clear all | Footer → **Clear**, or right-click icon → Clear History |
| Preferences | Footer → **Preferences**, or right-click icon → Preferences… |
| Quit | Right-click icon → Quit |

---

## Permissions

Two are required for full functionality. The app requests both automatically on first launch.

| Permission | Needed for | How to grant |
|---|---|---|
| **Accessibility** | Simulating ⌘V to paste into the active app | System Settings → Privacy & Security → Accessibility → add `ClipboardManager.app` |
| **Input Monitoring** | Detecting the global hotkey ⌘⇧V | System Settings → Privacy & Security → Input Monitoring → add `ClipboardManager.app` |

> The Setup Wizard (shown on first launch) has **"Request … Access"** buttons that trigger the system dialogs directly.

---

## Uninstall

```bash
bash uninstall.sh
```

Or from a fresh clone:

```bash
curl -fsSL https://raw.githubusercontent.com/FernandoHaeser/macos-clipboard-manager/main/uninstall.sh | bash
```

---

## Manual / dev build

```bash
git clone https://github.com/FernandoHaeser/macos-clipboard-manager.git
cd macos-clipboard-manager
bash install.sh          # full install
# or
./run.sh                 # quick dev launch (raw binary, no .app bundle)
```

---

## Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools — install with `xcode-select --install`
- Internet access (first install only, to clone the repo)

---

## Project Structure

```
clipboard-manager/
├── Package.swift
├── Sources/ClipboardManager/
│   ├── main.swift                  entry point
│   ├── AppDelegate.swift           status bar, popover, paste, TCC permission requests
│   ├── ClipboardEntry.swift        model — text / image / file, pin flag, Codable
│   ├── ClipboardStore.swift        history store — add, delete, pin, trim, iCloud sync
│   ├── ClipboardMonitor.swift      NSPasteboard polling — text, image, file URL detection
│   ├── HotkeyManager.swift         Carbon RegisterEventHotKey — reads hotkey from prefs
│   ├── PreferencesManager.swift    UserDefaults-backed preferences — hotkey, history, login
│   ├── PermissionRequester.swift   AXIsProcessTrustedWithOptions + CGRequestListenEventAccess
│   ├── PopoverController.swift     NSPopover lifecycle, outside-click to close
│   ├── ContentView.swift           SwiftUI root — search, List with sections, keyboard nav
│   ├── ClipboardRowView.swift      row — text preview / image thumbnail / file icon + actions
│   ├── SetupWizardView.swift       5-step onboarding NSWindow
│   ├── PreferencesView.swift       preferences NSWindow
│   └── Extensions.swift            NSImage resize + PNG export
├── Scripts/
│   └── make_icon.swift             headless CoreGraphics icon renderer → AppIcon.icns
├── install.sh                      installer (works via curl | bash or local bash)
├── uninstall.sh
└── run.sh
```

---

## How It Works

```
NSPasteboard  (polled every 500 ms)
      │
ClipboardMonitor.poll()
      ├── file URLs  → ClipboardStore.addFile(_:)
      ├── NSImage    → ClipboardStore.addImage(_:)  saves PNG thumbnail
      └── String     → ClipboardStore.addText(_:)
                              │
                        JSON + images/ saved to
                        ~/Library/Application Support/ClipboardManager/
                              │ (if iCloud sync on)
                        ~/iCloud Drive/ClipboardManager/history.json

User picks an item → Enter / double-click
      │
AppDelegate.performPaste(_:)
      ├── NSPasteboard.clearContents()
      ├── write text / image / URL back to pasteboard
      ├── popover.close()   ← previous app regains focus
      └── 150 ms later: CGEvent(V, .maskCommand) → cghidEventTap
```
