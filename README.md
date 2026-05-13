# Clipboard Manager

Native macOS clipboard history — text, images, and files. Lives in the menu bar. Zero dependencies.

Built with **Swift + AppKit + SwiftUI**. Requires macOS 14 Sonoma or later.

---

## Install

### Option A — Download DMG (recommended, no Xcode needed)

1. Go to [**Releases**](https://github.com/FernandoHaeser/macos-clipboard-manager/releases/latest)
2. Download `ClipboardManager-x.x.x.dmg`
3. Open the DMG → drag **ClipboardManager** to **Applications**
4. Launch from Applications or Spotlight

> **First launch blocked by Gatekeeper?** Right-click the app → **Open** → **Open** in the dialog. Only needed once.

---

### Option B — One-liner installer (builds from source or downloads pre-built)

```bash
curl -fsSL https://raw.githubusercontent.com/FernandoHaeser/macos-clipboard-manager/main/install.sh | bash
```

The installer automatically tries to download a pre-built binary from the latest release. If unavailable, it builds from source (requires Xcode Command Line Tools).

---

## Features

| | Feature | Details |
|---|---|---|
| 📋 | **Clipboard history** | Text, images, and files — up to 1000 items |
| 🖼 | **Image thumbnails** | Inline previews for copied images |
| 📁 | **File tracking** | File name + size for copied files |
| 📌 | **Pin / favourite** | Pinned items stay at the top permanently |
| ⌨️ | **Keyboard navigation** | Arrow keys, Enter to paste, Escape to close |
| 🔍 | **Live search** | Instant filter across all item types |
| 🎨 | **Appearance** | Glass/blur toggle, theme (system/light/dark), row density, font size |
| 🔔 | **Auto-updates** | Checks GitHub Releases, shows in-app changelog |
| ☁️ | **iCloud sync** | Syncs text history across Macs |
| ⚙️ | **Preferences** | Hotkey, history limit, appearance, update settings |
| 🧙 | **Setup Wizard** | 5-step onboarding for permissions & first-time config |

---

## Usage

| Action | How |
|---|---|
| Open history | **⌘⇧V** from any app, or click the menu bar icon |
| Navigate list | **↑ / ↓** arrow keys |
| Paste item | **Enter** (selected) or **double-click** any row |
| Search | Type in the search bar — filters all types live |
| Pin item | Hover → **pin** button (orange) |
| Delete item | Hover → **trash** button |
| Clear all | Footer → **Clear**, or right-click icon → Clear History |
| Preferences | Footer → **Preferences**, or right-click icon → Preferences… |
| Quit | Right-click icon → Quit |

---

## Permissions

Two are needed for full functionality. The Setup Wizard requests both on first launch.

| Permission | Used for |
|---|---|
| **Accessibility** | Simulate ⌘V to paste into the active app |
| **Input Monitoring** | Detect the global hotkey ⌘⇧V |

Grant via **System Settings → Privacy & Security** if the wizard dialogs are dismissed.

---

## Uninstall

```bash
bash uninstall.sh
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/FernandoHaeser/macos-clipboard-manager/main/uninstall.sh | bash
```

---

## Build from source

```bash
git clone https://github.com/FernandoHaeser/macos-clipboard-manager.git
cd macos-clipboard-manager
bash install.sh          # full install
# or
./run.sh                 # quick dev run (no .app bundle)
```

To build a DMG locally:

```bash
bash Scripts/make_dmg.sh
```

---

## Requirements

- macOS 14 Sonoma or later
- **DMG install:** no additional requirements
- **Build from source:** Xcode Command Line Tools (`xcode-select --install`)

---

## Releasing a new version

1. Update `static let currentVersion` in `UpdateChecker.swift`
2. Commit and tag: `git tag v1.2.3 && git push origin v1.2.3`
3. GitHub Actions builds the DMG automatically and attaches it to the release

---

## Project structure

```
clipboard-manager/
├── Package.swift
├── Sources/ClipboardManager/
│   ├── main.swift                  entry point
│   ├── AppDelegate.swift           status bar, popover, paste, TCC permissions
│   ├── ClipboardEntry.swift        model — text / image / file, pin flag, Codable
│   ├── ClipboardStore.swift        history — add, delete, pin, trim, iCloud sync
│   ├── ClipboardMonitor.swift      NSPasteboard polling
│   ├── HotkeyManager.swift         Carbon RegisterEventHotKey
│   ├── PreferencesManager.swift    UserDefaults-backed settings
│   ├── PermissionRequester.swift   Accessibility + Input Monitoring TCC
│   ├── PopoverController.swift     NSPopover lifecycle
│   ├── UpdateChecker.swift         GitHub Releases API — version check + changelog
│   ├── ContentView.swift           SwiftUI root — search, list, update banner
│   ├── ClipboardRowView.swift      row — preview, thumbnail, action buttons
│   ├── SetupWizardView.swift       5-step onboarding
│   ├── PreferencesView.swift       preferences window — appearance, updates, permissions
│   └── Extensions.swift            NSImage resize + PNG export
├── Scripts/
│   ├── make_icon.swift             CoreGraphics icon renderer → AppIcon.icns
│   └── make_dmg.sh                 creates drag-to-install DMG
├── .github/workflows/
│   └── release.yml                 builds + publishes DMG on new version tags
├── install.sh                      downloads pre-built or builds from source
├── uninstall.sh
└── run.sh
```

---

## How it works

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
