#!/usr/bin/env bash
# Creates a polished drag-to-install DMG for Clipboard Manager.
# Usage: bash Scripts/make_dmg.sh [output_dir]
# Output: ClipboardManager-<version>.dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR}"

APP_NAME="ClipboardManager"
BUNDLE_ID="com.fernandohaeser.clipboardmanager"
VERSION="${RELEASE_VERSION:-1.0.0}"
DMG_NAME="ClipboardManager-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
VOLUME_NAME="Clipboard Manager $VERSION"

APP_BUNDLE="$ROOT_DIR/.build/bundle/$APP_NAME.app"

BOLD=$'\033[1m'; RESET=$'\033[0m'
GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; RED=$'\033[0;31m'; DIM=$'\033[2m'
step() { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()   { echo "  ${GREEN}✓${RESET}  $*"; }
fail() { echo "  ${RED}✗${RESET}  $*" >&2; exit 1; }
dim()  { echo "  ${DIM}$*${RESET}"; }

# ── Build .app bundle ─────────────────────────────────────────────────────────
step "Building release bundle"
cd "$ROOT_DIR"
swift build -c release --quiet
BINARY=".build/release/$APP_NAME"
[[ -f "$BINARY" ]] || fail "Binary not found"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

ICON_PATH="$ROOT_DIR/.build/AppIcon.icns"
swift "$ROOT_DIR/Scripts/make_icon.swift" "$ICON_PATH" 2>/dev/null && \
    cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" && \
    ok "App icon generated" || true

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key>    <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>          <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>   <string>Clipboard Manager</string>
  <key>CFBundleExecutable</key>    <string>$APP_NAME</string>
  <key>CFBundleVersion</key>       <string>$VERSION</string>
  <key>CFBundleShortVersionString</key> <string>$VERSION</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>CFBundleIconFile</key>      <string>AppIcon</string>
  <key>LSUIElement</key>           <true/>
  <key>NSPrincipalClass</key>      <string>NSApplication</string>
  <key>LSMinimumSystemVersion</key> <string>14.0</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Needed to simulate ⌘V and paste items into other apps.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Clipboard Manager uses Apple Events to paste clipboard content.</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && ok "Code signed (ad-hoc)" || true
ok "App bundle ready: $APP_BUNDLE"

# ── Generate background image ─────────────────────────────────────────────────
step "Generating background image"
BG_PNG="$ROOT_DIR/.build/dmg_background.png"
if swift "$ROOT_DIR/Scripts/make_dmg_bg.swift" "$BG_PNG" 2>/dev/null; then
    ok "Background image generated"
else
    BG_PNG=""
    echo "  (background generation failed — DMG will have plain background)"
fi

# ── Create Install.command ────────────────────────────────────────────────────
step "Creating Install.command"
INSTALL_CMD="$ROOT_DIR/.build/Install.command"
cat > "$INSTALL_CMD" <<'INSTALLSCRIPT'
#!/usr/bin/env bash
# Installs Clipboard Manager — strips Gatekeeper quarantine automatically.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/ClipboardManager.app"
DEST="/Applications/ClipboardManager.app"

echo ""
echo "  Installing Clipboard Manager to /Applications…"

if [[ -d "$DEST" ]]; then
    osascript -e 'quit app "ClipboardManager"' 2>/dev/null || pkill -x ClipboardManager 2>/dev/null || true
    sleep 0.5
    rm -rf "$DEST"
fi

cp -r "$SRC" "$DEST"
xattr -cr "$DEST"
echo "  Installed."

echo "  Launching…"
open "$DEST"
echo ""
echo "  Done! Clipboard Manager is running in your menu bar."
echo "  The Setup Wizard will open shortly."
echo ""
read -rp "  Press Enter to close this window… " _
INSTALLSCRIPT
chmod +x "$INSTALL_CMD"
ok "Install.command ready"

# ── Stage DMG contents ────────────────────────────────────────────────────────
step "Staging DMG contents"
STAGING_PARENT="$(mktemp -d)"
STAGING="$STAGING_PARENT/dmg_root"
mkdir -p "$STAGING/.background"

cp -r "$APP_BUNDLE" "$STAGING/"
cp "$INSTALL_CMD" "$STAGING/Install.command"
ln -s /Applications "$STAGING/Applications"

if [[ -n "${BG_PNG:-}" && -f "$BG_PNG" ]]; then
    cp "$BG_PNG" "$STAGING/.background/bg.png"
fi
ok "Staged: $APP_NAME.app, Install.command, Applications symlink"

# ── Create read-write DMG for layout ─────────────────────────────────────────
step "Creating DMG"
rm -f "$DMG_PATH" "$ROOT_DIR/.build/rw.dmg"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -size 80m \
    "$ROOT_DIR/.build/rw.dmg" > /dev/null
ok "Read-write DMG created"

# ── Mount and apply Finder layout ─────────────────────────────────────────────
step "Applying Finder layout"
MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$ROOT_DIR/.build/rw.dmg" -mountpoint "$MOUNT_DIR" -quiet -nobrowse

# Set icon positions, window size, background image
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 100, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        try
            set background picture of viewOptions to file ".background:bg.png"
        end try
        set position of item "ClipboardManager.app" of container window to {165, 195}
        set position of item "Applications" of container window to {495, 195}
        set position of item "Install.command" of container window to {330, 340}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Hide .background folder from Finder
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true

sync
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
rm -rf "$MOUNT_DIR"
ok "Finder layout applied"

# ── Convert to compressed read-only DMG ──────────────────────────────────────
step "Compressing DMG"
hdiutil convert "$ROOT_DIR/.build/rw.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null
rm -f "$ROOT_DIR/.build/rw.dmg"
ok "Compressed: $(du -sh "$DMG_PATH" | cut -f1)"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$STAGING_PARENT"

echo
echo "${BOLD}${GREEN}DMG ready: $DMG_PATH${RESET}"
echo "  Size : $(du -sh "$DMG_PATH" | cut -f1)"
echo
echo "  Install options:"
echo "  ${DIM}1. Double-click Install.command (handles Gatekeeper automatically)"
echo "  2. Drag ClipboardManager → Applications, then right-click → Open${RESET}"
echo
