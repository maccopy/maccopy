# Maccopy

Native macOS clipboard history — text, images, and files. Lives in the menu bar. Zero dependencies.

Built with **Swift + AppKit + SwiftUI**. Requires macOS 14 Sonoma or later.

## Screenshots

<img width="501" height="282" alt="image" src="https://github.com/user-attachments/assets/7fb21481-5b50-47f9-ac01-df8d8fc0cfc8" />

<img width="500" height="282" alt="image" src="https://github.com/user-attachments/assets/4f094505-ff88-4c07-b5dc-962679239276" />

<img width="501" height="284" alt="image" src="https://github.com/user-attachments/assets/0212f6ae-cde6-4fa8-8f4e-3ca8c1ef9d2b" />

<img width="501" height="282" alt="image" src="https://github.com/user-attachments/assets/d2e6e00d-f52f-41c1-add6-3c763f84e17e" />

---

## Install

### Option A — Homebrew (recommended)

```bash
brew tap maccopy/homebrew-tap
brew install --cask maccopy
```

Updates via `brew upgrade --cask maccopy`.

---

### Option B — Installer package

1. Go to [**Releases**](https://github.com/maccopy/maccopy/releases/latest)
2. Download `Maccopy-x.x.x.dmg`
3. Open the DMG → double-click **Install Maccopy.pkg** → follow the wizard

The installer copies the app to `/Applications`, removes the Gatekeeper quarantine flag, and opens the Setup Wizard automatically.

> **macOS may warn** "Apple cannot verify the developer." Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. One-time step for unsigned apps.

---

### Option C — One-liner (builds from source or downloads pre-built)

```bash
curl -fsSL https://raw.githubusercontent.com/maccopy/maccopy/main/install.sh | bash
```

Tries to download a pre-built binary first. Falls back to building from source (requires Xcode Command Line Tools).

---

## Features

| | Feature | Details |
| --- | --- | --- |
| 📋 | **Clipboard history** | Text, images, and files — up to 1000 items |
| 🖼 | **Image thumbnails** | Inline previews + expanded preview pane |
| 📁 | **File tracking** | File name, extension badge, and size |
| 🔗 | **Link previews** | Favicon + page title for copied URLs |
| 📌 | **Pin / favourite** | Pinned items stay at the top permanently |
| ⌨️ | **Keyboard navigation** | Arrow keys, ↵ to paste, ⌘1–9 quick paste |
| 🔍 | **Live search** | Instant filter across all item types |
| 🎨 | **Accent colors** | 9 color themes: Blue, Purple, Indigo, Pink, Orange, Mint, Teal, Green, Red |
| 🌗 | **Appearance** | System / Light / Dark theme, glass/blur toggle, overlay opacity, row density |
| 🖱 | **Right-click menu** | Context menu on every row: Paste, Copy, Pin, Delete |
| 🔔 | **Auto-updates** | Detects + installs updates automatically; shows changelog popup after relaunch |
| ☁️ | **iCloud sync** | Syncs text history to iCloud Drive |
| ⚙️ | **Preferences** | Hotkey, history limit, appearance, update settings |
| 🧙 | **Setup Wizard** | 5-step onboarding for permissions and first-time config |

---

## Usage

| Action | How |
| --- | --- |
| Open history | **⌘⇧V** from any app, or click the menu bar icon |
| Navigate list | **↑ / ↓** arrow keys |
| Paste item | **↵ Enter** (selected) or **double-click** any row |
| Quick paste | **⌘1** through **⌘9** — pastes first 9 items instantly |
| Search | Type in the search bar — filters all types live |
| Pin item | Hover → pin button, or right-click → Pin |
| Delete item | Hover → trash button, or right-click → Delete |
| Preview item | Select any item — preview pane expands below the list |
| Clear all | Footer → **Clear** (asks for confirmation) |
| Preferences | Footer → **Preferences**, or right-click icon → Preferences… |
| Quit | Right-click icon → Quit |

---

## Preferences

Open via footer → **Preferences** or right-click the menu bar icon → **Preferences…**

| Setting | Description |
| --- | --- |
| **Global Hotkey** | Change via Setup Wizard |
| **Maximum items** | 10–1000 (default 50) |
| **Theme** | System / Light / Dark |
| **Row density** | Compact / Comfortable / Spacious |
| **Popover width** | 360–600 px |
| **Glass / blur effect** | NSVisualEffect material background |
| **Overlay opacity** | 40–100% |
| **Accent color** | 9 color choices |
| **Show type icon** | Icon badge per item type |
| **Show timestamps** | Relative time on each row |
| **Show character count** | Char count / domain for URLs |
| **Launch at login** | LaunchAgent toggle |
| **iCloud sync** | Writes text history to iCloud Drive |
| **Auto-check updates** | Checks GitHub Releases on launch (once per day) |

---

## Permissions

Two are needed for full functionality. The Setup Wizard requests both on first launch.

| Permission | Used for |
| --- | --- |
| **Accessibility** | Simulate ⌘V to paste into the active app |
| **Input Monitoring** | Detect the global hotkey ⌘⇧V |

Grant via **System Settings → Privacy & Security** if the wizard dialogs are dismissed.

---

## Uninstall

```bash
bash uninstall.sh
```

Or via Homebrew:

```bash
brew uninstall --cask maccopy
```

Or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/maccopy/maccopy/main/uninstall.sh | bash
```

---

## Build from source

```bash
git clone https://github.com/maccopy/maccopy.git
cd maccopy
bash install.sh          # full install
# or
./run.sh                 # quick dev run (no .app bundle)
```

Build a release DMG:

```bash
RELEASE_VERSION=1.1.1 bash Scripts/make_dmg.sh
```

Build + publish a full GitHub release:

```bash
bash Scripts/make_release.sh 1.2.0
```

This builds the DMG, creates `Maccopy.zip` for Homebrew, computes the SHA256, commits, tags, and creates a draft GitHub release.

---

## Requirements

- macOS 14 Sonoma or later
- **Homebrew / DMG install:** no additional requirements
- **Build from source:** Xcode Command Line Tools (`xcode-select --install`)

---

## Releasing a new version

```bash
bash Scripts/make_release.sh 1.2.0
```

Then:
1. `git push && git push --tags`
2. Publish the draft release on GitHub
3. Copy `Casks/maccopy.rb` to the [maccopy/homebrew-tap](https://github.com/maccopy/homebrew-tap) repo and push

---

## Project structure

```text
clipboard-manager/
├── Package.swift
├── Sources/Maccopy/
│   ├── main.swift                  entry point
│   ├── AppDelegate.swift           status bar, popover, paste, TCC permissions
│   ├── ClipboardEntry.swift        model — text / image / file, pin flag, Codable
│   ├── ClipboardStore.swift        history — add, delete, pin, trim, iCloud sync
│   ├── ClipboardMonitor.swift      NSPasteboard polling
│   ├── HotkeyManager.swift         Carbon RegisterEventHotKey
│   ├── PreferencesManager.swift    UserDefaults-backed settings + AccentColorTheme
│   ├── PermissionRequester.swift   Accessibility + Input Monitoring TCC
│   ├── PopoverController.swift     NSPopover lifecycle + window transparency
│   ├── UpdateChecker.swift         GitHub Releases API — auto-update + changelog
│   ├── ContentView.swift           SwiftUI root — search, list, preview, update banner
│   ├── ClipboardRowView.swift      row — preview, thumbnail, action buttons, context menu
│   ├── LinkPreviewFetcher.swift    async URL metadata + favicon fetcher
│   ├── SetupWizardView.swift       5-step onboarding
│   ├── PreferencesView.swift       preferences window — appearance, updates, permissions
│   └── Extensions.swift            NSImage resize + PNG export
├── Scripts/
│   ├── make_icon.swift             CoreGraphics icon renderer → AppIcon.icns
│   ├── make_dmg.sh                 builds .app + .pkg + DMG
│   └── make_release.sh             full release: build → zip → sha256 → gh release
├── Casks/
│   └── maccopy.rb                  Homebrew cask formula (copy to maccopy/homebrew-tap)
├── install.sh                      downloads pre-built or builds from source
├── uninstall.sh
└── run.sh
```

---

## How it works

```text
NSPasteboard  (polled every 500 ms)
      │
ClipboardMonitor.poll()
      ├── file URLs  → ClipboardStore.addFile(_:)
      ├── NSImage    → ClipboardStore.addImage(_:)  saves PNG thumbnail
      └── String     → ClipboardStore.addText(_:)
                              │
                        JSON + images/ saved to
                        ~/Library/Application Support/Maccopy/
                              │ (if iCloud sync on)
                        ~/iCloud Drive/Maccopy/history.json

User picks an item → ↵ Enter / double-click / ⌘1-9
      │
AppDelegate.performPaste(_:)
      ├── NSPasteboard.clearContents()
      ├── write text / image / URL back to pasteboard
      ├── popover.close()   ← previous app regains focus
      └── 150 ms later: CGEvent(V, .maskCommand) → cghidEventTap

Update check (on launch, once per day)
      │
UpdateChecker.check()
      ├── fetches GitHub Releases API
      ├── compares semver tags
      └── if newer: auto-downloads ZIP → extracts → shell script replaces .app → relaunch
                              │
                        on next launch: reads UserDefaults("pendingChangelog")
                              └── shows Changelog window with release notes
```
