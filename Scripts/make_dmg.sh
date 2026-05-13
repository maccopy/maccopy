#!/usr/bin/env bash
# Creates a drag-to-install DMG for Clipboard Manager.
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
STAGING_DIR="$(mktemp -d)/dmg_root"

# ── Colours ───────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'; RESET=$'\033[0m'
GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; RED=$'\033[0;31m'
step() { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()   { echo "  ${GREEN}✓${RESET}  $*"; }
fail() { echo "  ${RED}✗${RESET}  $*" >&2; exit 1; }

# ── Build app bundle if not already present ───────────────────────────────────
step "Building app bundle"
bash "$SCRIPT_DIR/../install.sh" --bundle-only 2>/dev/null || {
    # If install.sh doesn't support --bundle-only, build manually
    cd "$ROOT_DIR"
    swift build -c release --quiet
    BINARY=".build/release/$APP_NAME"
    [[ -f "$BINARY" ]] || fail "Binary not found"

    mkdir -p "$ROOT_DIR/.build/bundle/$APP_NAME.app/Contents/MacOS"
    mkdir -p "$ROOT_DIR/.build/bundle/$APP_NAME.app/Contents/Resources"
    cp "$BINARY" "$ROOT_DIR/.build/bundle/$APP_NAME.app/Contents/MacOS/$APP_NAME"
    chmod +x "$ROOT_DIR/.build/bundle/$APP_NAME.app/Contents/MacOS/$APP_NAME"

    # Icon
    ICON_PATH="$ROOT_DIR/.build/AppIcon.icns"
    swift "$ROOT_DIR/Scripts/make_icon.swift" "$ICON_PATH" 2>/dev/null && \
        cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" || true

    # Info.plist
    cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
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
  <string>Clipboard Manager needs Accessibility access to simulate ⌘V and paste items into other apps.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Clipboard Manager uses Apple Events to paste clipboard content.</string>
</dict>
</plist>
PLIST

    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
}

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found at $APP_BUNDLE"
ok "App bundle ready"

# ── Stage DMG contents ────────────────────────────────────────────────────────
step "Staging DMG contents"
mkdir -p "$STAGING_DIR"
cp -r "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
ok "Staged: $APP_NAME.app + Applications symlink"

# ── Create DMG ────────────────────────────────────────────────────────────────
step "Creating DMG"
rm -f "$DMG_PATH"

# Create compressed DMG directly from staging dir
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" \
    > /dev/null

ok "DMG created: $DMG_PATH"

# ── Set DMG window layout via AppleScript ─────────────────────────────────────
step "Applying DMG window layout"
VOLUME_MOUNT="$(mktemp -d)"
hdiutil attach "$DMG_PATH" -mountpoint "$VOLUME_MOUNT" -quiet -nobrowse

osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 720, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set position of item "$APP_NAME.app" of container window to {140, 160}
        set position of item "Applications" of container window to {380, 160}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

hdiutil detach "$VOLUME_MOUNT" -quiet || true
rm -rf "$VOLUME_MOUNT"

# Convert to final compressed DMG (re-create to capture layout)
TEMP_DMG="${DMG_PATH%.dmg}_layout.dmg"
mv "$DMG_PATH" "$TEMP_DMG"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" > /dev/null
rm -f "$TEMP_DMG"

ok "Window layout applied"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$(dirname "$STAGING_DIR")"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "${BOLD}${GREEN}DMG ready: $DMG_PATH${RESET}"
echo "  Size: $(du -sh "$DMG_PATH" | cut -f1)"
echo
