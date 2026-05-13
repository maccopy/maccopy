#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          Clipboard Manager — Installer v3                    ║
# ║  Downloads pre-built DMG when available, builds from        ║
# ║  source as fallback. Requires macOS 14+.                    ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

APP_NAME="ClipboardManager"
BUNDLE_ID="com.fernandohaeser.clipboardmanager"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
GITHUB_REPO="FernandoHaeser/macos-clipboard-manager"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO/releases/latest"

# ── Colours ───────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
BLUE=$'\033[0;34m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'; CYAN=$'\033[0;36m'

step()  { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()    { echo "  ${GREEN}✓${RESET}  $*"; }
warn()  { echo "  ${YELLOW}⚠${RESET}  $*"; }
fail()  { echo "  ${RED}✗${RESET}  $*" >&2; exit 1; }
dim()   { echo "  ${DIM}$*${RESET}"; }
info()  { echo "  $*"; }

# ── Handle --bundle-only flag (called from make_dmg.sh) ───────────────────────
BUNDLE_ONLY=false
for arg in "$@"; do [[ "$arg" == "--bundle-only" ]] && BUNDLE_ONLY=true; done

if $BUNDLE_ONLY; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    swift build -c release --quiet
    BINARY=".build/release/$APP_NAME"
    [[ -f "$BINARY" ]] || exit 1
    BDST=".build/bundle/$APP_NAME.app"
    mkdir -p "$BDST/Contents/MacOS" "$BDST/Contents/Resources"
    cp "$BINARY" "$BDST/Contents/MacOS/$APP_NAME"
    chmod +x "$BDST/Contents/MacOS/$APP_NAME"
    ICON_PATH=".build/AppIcon.icns"
    swift Scripts/make_icon.swift "$ICON_PATH" 2>/dev/null && \
        cp "$ICON_PATH" "$BDST/Contents/Resources/AppIcon.icns" || true
    cat > "$BDST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key>    <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>          <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>   <string>Clipboard Manager</string>
  <key>CFBundleExecutable</key>    <string>$APP_NAME</string>
  <key>CFBundleVersion</key>       <string>1.0.0</string>
  <key>CFBundleShortVersionString</key> <string>1.0.0</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>CFBundleIconFile</key>      <string>AppIcon</string>
  <key>LSUIElement</key>           <true/>
  <key>NSPrincipalClass</key>      <string>NSApplication</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Needed to simulate ⌘V and paste items into other apps.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Clipboard Manager uses Apple Events to paste clipboard content.</string>
</dict></plist>
PLIST
    codesign --force --deep --sign - "$BDST" 2>/dev/null || true
    exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo
echo "${BOLD}${CYAN}╔══════════════════════════════════════════╗"
echo "║      Clipboard Manager  Installer       ║"
echo "╚══════════════════════════════════════════╝${RESET}"
echo

# ── Step 1: macOS version ─────────────────────────────────────────────────────
step "Step 1 — Checking macOS version"
macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$macos_major" -lt 14 ]]; then
    fail "macOS 14 Sonoma or later required. Found $(sw_vers -productVersion)."
fi
ok "macOS $(sw_vers -productVersion)"

# ── Step 2: Try pre-built binary from GitHub Releases ────────────────────────
step "Step 2 — Checking for pre-built release"
DOWNLOADED_DMG=""
if command -v curl &>/dev/null; then
    LATEST_JSON="$(curl -fsSL --connect-timeout 5 "$GITHUB_API" 2>/dev/null || true)"
    if [[ -n "$LATEST_JSON" ]]; then
        DMG_URL="$(echo "$LATEST_JSON" | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -1 | grep -o 'https://[^"]*' || true)"
        TAG="$(echo "$LATEST_JSON" | grep -o '"tag_name": *"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"' || true)"
        if [[ -n "$DMG_URL" ]]; then
            info "Found pre-built release: ${BOLD}$TAG${RESET}"
            TMPDIR_INST="$(mktemp -d)"
            DMG_FILE="$TMPDIR_INST/ClipboardManager.dmg"
            info "Downloading DMG…"
            if curl -fsSL --progress-bar "$DMG_URL" -o "$DMG_FILE"; then
                DOWNLOADED_DMG="$DMG_FILE"
                ok "Downloaded $TAG DMG"
            else
                warn "Download failed — will build from source"
                rm -rf "$TMPDIR_INST"
            fi
        else
            warn "No DMG asset in latest release — will build from source"
        fi
    else
        warn "GitHub API unreachable — will build from source"
    fi
fi

# ── Step 3a: Install from DMG (fast path) ─────────────────────────────────────
if [[ -n "$DOWNLOADED_DMG" ]]; then
    step "Step 3 — Installing from DMG"

    # Stop running instance
    if pgrep -x "$APP_NAME" &>/dev/null; then
        warn "Stopping running instance…"
        pkill -x "$APP_NAME" || true
        sleep 0.8
    fi

    MOUNT_POINT="$(mktemp -d)"
    hdiutil attach "$DOWNLOADED_DMG" -mountpoint "$MOUNT_POINT" -quiet -nobrowse
    mkdir -p "$INSTALL_DIR"
    rm -rf "$APP_BUNDLE"
    cp -r "$MOUNT_POINT/$APP_NAME.app" "$APP_BUNDLE"
    hdiutil detach "$MOUNT_POINT" -quiet || true
    rm -rf "$(dirname "$DOWNLOADED_DMG")" "$MOUNT_POINT"

    # Remove quarantine so Gatekeeper doesn't block the unsigned app
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true

    ok "Installed to $APP_BUNDLE"
    BUILT_FROM_SOURCE=false
else
    # ── Step 3b: Build from source (fallback) ─────────────────────────────────
    step "Step 3 — Building from source"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
    if [[ ! -f "$SCRIPT_DIR/Package.swift" ]]; then
        # Running via curl | bash — clone repo first
        CLONE_TMP="$(mktemp -d)"
        info "Cloning repository…"
        if ! git clone --depth=1 --quiet "https://github.com/$GITHUB_REPO.git" "$CLONE_TMP" 2>&1; then
            fail "git clone failed. Check internet connection and git installation."
        fi
        # Re-invoke from cloned copy (with source available)
        bash "$CLONE_TMP/install.sh"
        STATUS=$?
        rm -rf "$CLONE_TMP"
        exit $STATUS
    fi

    if ! command -v swift &>/dev/null; then
        warn "Swift not found. Launching Xcode Command Line Tools installer…"
        xcode-select --install 2>/dev/null || true
        echo
        fail "Re-run after Xcode Command Line Tools installation completes."
    fi
    ok "Swift $(swift --version 2>&1 | head -1 | awk '{print $NF}')"

    cd "$SCRIPT_DIR"
    dim "swift build -c release"
    swift build -c release --quiet
    BINARY=".build/release/$APP_NAME"
    [[ -f "$BINARY" ]] || fail "Binary not found at $BINARY"
    ok "Build succeeded"

    step "Step 3b — Bundling .app"
    if pgrep -x "$APP_NAME" &>/dev/null; then
        warn "Stopping running instance…"
        pkill -x "$APP_NAME" || true
        sleep 0.6
    fi

    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
    cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    ICON_PATH="$SCRIPT_DIR/.build/AppIcon.icns"
    if swift "$SCRIPT_DIR/Scripts/make_icon.swift" "$ICON_PATH" 2>/dev/null; then
        cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
        ok "App icon generated"
    else
        warn "Icon generation failed — using system default"
        ICON_PATH=""
    fi

    ICON_KEY=""
    [[ -n "${ICON_PATH:-}" && -f "${ICON_PATH:-}" ]] && ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
    cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key>    <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>          <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>   <string>Clipboard Manager</string>
  <key>CFBundleExecutable</key>    <string>$APP_NAME</string>
  <key>CFBundleVersion</key>       <string>1.0.0</string>
  <key>CFBundleShortVersionString</key> <string>1.0.0</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>LSUIElement</key>           <true/>
  <key>NSPrincipalClass</key>      <string>NSApplication</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Needed to simulate ⌘V and paste items into other apps.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Clipboard Manager uses Apple Events to paste clipboard content.</string>
  $ICON_KEY
</dict></plist>
PLIST

    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && ok "Code signed (ad-hoc)" || warn "Code sign skipped"
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true
    ok "Bundle created at $APP_BUNDLE"
    BUILT_FROM_SOURCE=true
fi

# ── Step 4: LaunchAgent ───────────────────────────────────────────────────────
step "Step 4 — Setting up login item"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>$BUNDLE_ID</string>
  <key>ProgramArguments</key>
  <array><string>$APP_BUNDLE/Contents/MacOS/$APP_NAME</string></array>
  <key>RunAtLoad</key>         <false/>
  <key>KeepAlive</key>         <false/>
  <key>StandardOutPath</key>   <string>$HOME/Library/Logs/$APP_NAME.log</string>
  <key>StandardErrorPath</key> <string>$HOME/Library/Logs/$APP_NAME.log</string>
</dict>
</plist>
PLIST
launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
ok "LaunchAgent installed (enable auto-login in app Preferences)"

# ── Step 5: Permissions ───────────────────────────────────────────────────────
step "Step 5 — Permissions"
echo
echo "  Clipboard Manager needs ${BOLD}two permissions${RESET} to work fully:"
echo
echo "  ${BOLD}1. Accessibility${RESET}       — simulate ⌘V keystroke to paste into apps"
echo "  ${BOLD}2. Input Monitoring${RESET}    — detect the global hotkey (⌘⇧V)"
echo
echo "  The in-app Setup Wizard will guide you through both."
echo "  Or grant manually: System Settings → Privacy & Security"
echo

read -r -p "  Open System Settings now? [Y/n] " open_prefs
if [[ ! "$open_prefs" =~ ^[Nn] ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    sleep 0.8
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    ok "System Settings opened"
else
    warn "Grant permissions manually when prompted by the Setup Wizard"
fi

# ── Step 6: Launch ────────────────────────────────────────────────────────────
step "Step 6 — Launching Clipboard Manager"
defaults delete "$BUNDLE_ID" hasCompletedSetup 2>/dev/null || true
open "$APP_BUNDLE"
sleep 1.2
ok "Clipboard Manager launched — Setup Wizard will appear shortly"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "${BOLD}${GREEN}╔══════════════════════════════════════════╗"
echo "║      Installation complete! 🎉          ║"
echo "╚══════════════════════════════════════════╝${RESET}"
echo
echo "  ${BOLD}Getting started:${RESET}"
echo "  ${DIM}• Click the clipboard icon in the menu bar"
echo "  • Or press ⌘⇧V from any app"
echo "  • The Setup Wizard will open automatically${RESET}"
echo
echo "  ${BOLD}Installed:${RESET}   $APP_BUNDLE"
echo "  ${BOLD}Logs:${RESET}        ~/Library/Logs/$APP_NAME.log"
echo "  ${BOLD}Uninstall:${RESET}   bash uninstall.sh"
if ${BUILT_FROM_SOURCE:-false}; then
    echo "  ${DIM}Built from source — next install will download pre-built binary${RESET}"
fi
echo
