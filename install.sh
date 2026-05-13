#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          Clipboard Manager — Installer v2                    ║
# ║  Builds, bundles, icons, signs, and launches the app.       ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

APP_NAME="ClipboardManager"
BUNDLE_ID="com.fernandohaeser.clipboardmanager"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

# ── Colours ──────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
BLUE=$'\033[0;34m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
CYAN=$'\033[0;36m'

step()  { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()    { echo "  ${GREEN}✓${RESET}  $*"; }
warn()  { echo "  ${YELLOW}⚠${RESET}  $*"; }
fail()  { echo "  ${RED}✗${RESET}  $*" >&2; exit 1; }
dim()   { echo "  ${DIM}$*${RESET}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo
echo "${BOLD}${CYAN}╔══════════════════════════════════════════╗"
echo "║       Clipboard Manager  Installer     ║"
echo "╚══════════════════════════════════════════╝${RESET}"
echo
echo "  This wizard will:"
echo "  ${DIM}1. Check prerequisites"
echo "  2. Build the app from source"
echo "  3. Generate the app icon"
echo "  4. Install to ~/Applications"
echo "  5. Set up login item"
echo "  6. Configure permissions"
echo "  7. Launch Clipboard Manager${RESET}"
echo

read -r -p "  Press ${BOLD}Enter${RESET} to begin, or Ctrl+C to cancel… " _

# ── Step 1: Prerequisites ─────────────────────────────────────────────────────
step "Step 1/7 — Checking prerequisites"

macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$macos_major" -lt 14 ]]; then
  fail "macOS 14 Sonoma or later required. Found $(sw_vers -productVersion)."
fi
ok "macOS $(sw_vers -productVersion)"

if ! command -v swift &>/dev/null; then
  warn "Swift not found. Launching Xcode Command Line Tools installer…"
  xcode-select --install 2>/dev/null || true
  echo
  fail "Re-run this script after Xcode Command Line Tools installation completes."
fi
ok "Swift $(swift --version 2>&1 | head -1 | awk '{print $NF}')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [[ ! -f "$SCRIPT_DIR/Package.swift" ]]; then
  fail "Run from the clipboard-manager repo root directory."
fi
ok "Source directory: $SCRIPT_DIR"

# ── Step 2: Build ─────────────────────────────────────────────────────────────
step "Step 2/7 — Building (release configuration)"
cd "$SCRIPT_DIR"
dim "swift build -c release"
swift build -c release 2>&1 | grep -v "^Build complete" | tail -5 || true
swift build -c release --quiet

BINARY=".build/release/$APP_NAME"
[[ -f "$BINARY" ]] || fail "Binary not found at $BINARY"
ok "Build succeeded"

# ── Step 3: App Icon ──────────────────────────────────────────────────────────
step "Step 3/7 — Generating app icon"
ICON_PATH="$SCRIPT_DIR/.build/AppIcon.icns"
dim "swift Scripts/make_icon.swift"
if swift "$SCRIPT_DIR/Scripts/make_icon.swift" "$ICON_PATH" 2>/dev/null; then
  ok "Icon generated"
else
  warn "Icon generation failed — using system default"
  ICON_PATH=""
fi

# ── Step 4: Bundle ────────────────────────────────────────────────────────────
step "Step 4/7 — Creating .app bundle"

# Stop running instance
if pgrep -x "$APP_NAME" &>/dev/null; then
  warn "Stopping running instance…"
  pkill -x "$APP_NAME" || true
  sleep 0.6
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy icon
if [[ -n "$ICON_PATH" && -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Info.plist
ICON_KEY=""
if [[ -n "$ICON_PATH" && -f "$ICON_PATH" ]]; then
  ICON_KEY="  <key>CFBundleIconFile</key>
  <string>AppIcon</string>"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Clipboard Manager</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleVersion</key>
  <string>2.0</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Clipboard Manager needs Accessibility access to simulate ⌘V and paste items into other apps.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Clipboard Manager uses Apple Events to paste clipboard content.</string>
  $ICON_KEY
</dict>
</plist>
PLIST

# Ad-hoc code sign (allows running without Gatekeeper issues for local apps)
if command -v codesign &>/dev/null; then
  codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && ok "Code signed (ad-hoc)" || warn "Code sign skipped"
fi

ok "Bundle created at $APP_BUNDLE"

# ── Step 5: Login Item ────────────────────────────────────────────────────────
step "Step 5/7 — Setting up login item"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$BUNDLE_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_BUNDLE/Contents/MacOS/$APP_NAME</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/$APP_NAME.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/$APP_NAME.log</string>
</dict>
</plist>
PLIST

launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENT_PLIST"
ok "LaunchAgent installed (auto-starts at login)"

# ── Step 6: Permissions ───────────────────────────────────────────────────────
step "Step 6/7 — Configuring permissions"
echo
echo "  Clipboard Manager needs ${BOLD}two permissions${RESET} to work fully:"
echo
echo "  ${BOLD}1. Accessibility${RESET}  — to simulate ⌘V and paste into apps"
echo "  ${BOLD}2. Input Monitoring${RESET} — to detect the global hotkey (⌘⇧V)"
echo
echo "  Add ${BOLD}$APP_BUNDLE${RESET}"
echo "  in ${DIM}System Settings → Privacy & Security → (each section)${RESET}"
echo

read -r -p "  Open System Settings now? [Y/n] " open_prefs
if [[ ! "$open_prefs" =~ ^[Nn] ]]; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  sleep 1
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
  ok "System Settings opened"
else
  warn "Grant permissions manually in System Settings → Privacy & Security"
fi

# ── Step 7: Launch ────────────────────────────────────────────────────────────
step "Step 7/7 — Launching Clipboard Manager"
open "$APP_BUNDLE"
sleep 0.8
ok "Clipboard Manager launched"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "${BOLD}${GREEN}╔══════════════════════════════════════════╗"
echo "║        Installation Complete! 🎉        ║"
echo "╚══════════════════════════════════════════╝${RESET}"
echo
echo "  ${BOLD}Getting started:${RESET}"
echo "  ${DIM}• Click the clipboard icon (📋) in the menu bar"
echo "  • Or press ⌘⇧V from any app"
echo "  • The in-app Setup Wizard will guide you through first-time config"
echo
echo "  ${BOLD}Installed:${RESET}   $APP_BUNDLE"
echo "  ${BOLD}Logs:${RESET}        ~/Library/Logs/$APP_NAME.log"
echo "  ${BOLD}Uninstall:${RESET}   bash uninstall.sh${RESET}"
echo
