#!/usr/bin/env bash
# ClipboardManager installer
# Usage: bash install.sh
#        curl -fsSL <raw-url>/install.sh | bash

set -euo pipefail

APP_NAME="ClipboardManager"
BUNDLE_ID="com.fernandohaeser.clipboardmanager"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}==> ${NC}$*"; }
warn()  { echo -e "${YELLOW}==> ${NC}$*"; }
error() { echo -e "${RED}==> ERROR: ${NC}$*" >&2; exit 1; }

# ── 1. Prerequisites ─────────────────────────────────────────────────────────

info "Checking prerequisites…"

sw_vers_major=$(sw_vers -productVersion | cut -d. -f1)
sw_vers_minor=$(sw_vers -productVersion | cut -d. -f2)
if [[ "$sw_vers_major" -lt 14 ]]; then
  error "macOS 14 (Sonoma) or later required. Found $(sw_vers -productVersion)."
fi

if ! command -v swift &>/dev/null; then
  warn "Swift not found. Installing Xcode Command Line Tools…"
  xcode-select --install 2>/dev/null || true
  echo "After CLT install completes, re-run this script."
  exit 1
fi

# If piped (curl | bash), clone or use current dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [[ ! -f "$SCRIPT_DIR/Package.swift" ]]; then
  error "Run this script from the clipboard-manager repo root, or use the local install: bash install.sh"
fi

# ── 2. Build ─────────────────────────────────────────────────────────────────

info "Building ${APP_NAME} (release)..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BINARY=".build/release/$APP_NAME"
[[ -f "$BINARY" ]] || error "Build failed — binary not found at $BINARY"

# ── 3. Package .app bundle ───────────────────────────────────────────────────

info "Creating .app bundle at ${APP_BUNDLE}..."

# Stop running instance if any
if pgrep -x "$APP_NAME" &>/dev/null; then
  warn "Stopping running instance…"
  pkill -x "$APP_NAME" || true
  sleep 0.5
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

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
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
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
</dict>
</plist>
PLIST

# ── 4. LaunchAgent (auto-start at login) ─────────────────────────────────────

info "Installing LaunchAgent for login auto-start…"
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

# Unload stale agent if registered
launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENT_PLIST"

# ── 5. Permissions ───────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Grant two permissions for full functionality:"
echo ""
echo "  1. Accessibility  →  needed to simulate ⌘V paste"
echo "  2. Input Monitoring  →  needed for global hotkey ⌘⇧V"
echo ""
echo "  Add:  $APP_BUNDLE"
echo "  Path: System Settings → Privacy & Security → (each section)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -r -p "Open System Settings → Privacy & Security now? [Y/n] " open_settings
if [[ "$open_settings" =~ ^[Nn] ]]; then
  warn "Grant permissions manually before using paste or hotkey."
else
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  sleep 1
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
fi

# ── 6. Launch ────────────────────────────────────────────────────────────────

info "Launching ${APP_NAME}..."
open "$APP_BUNDLE"

echo ""
info "Done! $APP_NAME is running in the menu bar."
echo "  Auto-starts at login via LaunchAgent."
echo "  Logs: ~/Library/Logs/$APP_NAME.log"
echo "  Uninstall: bash uninstall.sh"
echo ""
