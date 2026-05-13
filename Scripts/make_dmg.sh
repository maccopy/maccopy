#!/usr/bin/env bash
# Builds a polished .pkg-based DMG for Clipboard Manager.
#
# Install flow for users:
#   1. Open DMG  →  double-click "Install Clipboard Manager.pkg"
#   2. Standard macOS installer wizard runs
#   3. postinstall script strips quarantine + resets setup wizard
#   4. App launches automatically
#
# Usage: bash Scripts/make_dmg.sh [output_dir]
# Env:   RELEASE_VERSION=1.2.3  (default: 1.0.0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR}"

APP_NAME="ClipboardManager"
BUNDLE_ID="com.fernandohaeser.clipboardmanager"
VERSION="${RELEASE_VERSION:-1.0.0}"
VOLUME_NAME="Clipboard Manager $VERSION"
DMG_PATH="$OUTPUT_DIR/ClipboardManager-${VERSION}.dmg"

APP_BUNDLE="$ROOT_DIR/.build/bundle/$APP_NAME.app"
BUILD_DIR="$ROOT_DIR/.build"

BOLD=$'\033[1m'; RESET=$'\033[0m'
GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; RED=$'\033[0;31m'; DIM=$'\033[2m'
step() { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()   { echo "  ${GREEN}✓${RESET}  $*"; }
fail() { echo "  ${RED}✗${RESET}  $*" >&2; exit 1; }

# ── 1. Build .app bundle ──────────────────────────────────────────────────────
step "Building release binary"
cd "$ROOT_DIR"
swift build -c release --quiet
BINARY=".build/release/$APP_NAME"
[[ -f "$BINARY" ]] || fail "Binary not found at $BINARY"
ok "Binary built"

step "Bundling .app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

ICON_PATH="$BUILD_DIR/AppIcon.icns"
swift "$ROOT_DIR/Scripts/make_icon.swift" "$ICON_PATH" 2>/dev/null && \
    cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" && \
    ok "Icon generated" || true

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

codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && ok "App bundle signed (ad-hoc)" || true

# ── 2. Build .pkg installer ───────────────────────────────────────────────────
step "Building .pkg installer"

PKG_ROOT="$(mktemp -d)"
PKG_SCRIPTS="$(mktemp -d)"
PKG_COMPONENT="$BUILD_DIR/ClipboardManager-component.pkg"
PKG_FINAL="$BUILD_DIR/ClipboardManager-${VERSION}.pkg"

# App goes into /Applications
mkdir -p "$PKG_ROOT/Applications"
cp -r "$APP_BUNDLE" "$PKG_ROOT/Applications/"

# postinstall: strip quarantine + reset setup wizard + launch
cat > "$PKG_SCRIPTS/postinstall" <<'POSTINSTALL'
#!/bin/bash
set -e
APP="/Applications/ClipboardManager.app"

# Strip Gatekeeper quarantine — prevents "not opened" error
/usr/bin/xattr -cr "$APP" 2>/dev/null || true

# Reset setup wizard so it opens on first launch after (re)install
/usr/bin/defaults delete com.fernandohaeser.clipboardmanager hasCompletedSetup 2>/dev/null || true

# Launch the app (delay gives installer time to finish UI)
(sleep 1.5 && /usr/bin/open "$APP") &

exit 0
POSTINSTALL
chmod +x "$PKG_SCRIPTS/postinstall"

# Build component package
pkgbuild \
    --root "$PKG_ROOT" \
    --scripts "$PKG_SCRIPTS" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$PKG_COMPONENT" \
    > /dev/null

# Wrap with productbuild for a polished installer wizard
DIST_XML="$(mktemp).xml"
cat > "$DIST_XML" <<DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Clipboard Manager $VERSION</title>
    <background file="bg.png" alignment="center" scaling="tofit"/>
    <welcome file="welcome.rtf"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" visible="false">
        <pkg-ref id="$BUNDLE_ID"/>
    </choice>
    <pkg-ref id="$BUNDLE_ID" version="$VERSION" onConclusion="none">ClipboardManager-component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

# Welcome text (RTF)
WELCOME_RTF="$(mktemp).rtf"
cat > "$WELCOME_RTF" <<RTF
{\rtf1\ansi\ansicpg1252
{\fonttbl\f0\fswiss Helvetica;}
\f0\fs26\b Clipboard Manager $VERSION\b0\
\
\fs22 Native macOS clipboard history for text, images, and files. Lives in your menu bar.\
\
\b What this installer does:\b0\
\
\pard\tx220\li220\fi-220
\f0 \'95 Copies ClipboardManager.app to /Applications\
\'95 Removes macOS security quarantine\
\'95 Opens the Setup Wizard automatically\
\pard\
\
No administrator password required.\
}
RTF

# Resources dir for productbuild (bg + welcome)
DIST_RESOURCES="$(mktemp -d)"
BG_PNG="$BUILD_DIR/dmg_background.png"
swift "$ROOT_DIR/Scripts/make_dmg_bg.swift" "$BG_PNG" 540 360 2>/dev/null && \
    cp "$BG_PNG" "$DIST_RESOURCES/bg.png" || true
cp "$WELCOME_RTF" "$DIST_RESOURCES/welcome.rtf"

productbuild \
    --distribution "$DIST_XML" \
    --resources "$DIST_RESOURCES" \
    --package-path "$BUILD_DIR" \
    "$PKG_FINAL" \
    > /dev/null 2>&1 || {
    # Fallback: use component pkg directly if productbuild fails
    cp "$PKG_COMPONENT" "$PKG_FINAL"
}

# Cleanup temp dirs
rm -rf "$PKG_ROOT" "$PKG_SCRIPTS" "$DIST_RESOURCES"
rm -f "$DIST_XML" "$WELCOME_RTF"

[[ -f "$PKG_FINAL" ]] || fail ".pkg not found at $PKG_FINAL"
ok "Installer package: $(du -sh "$PKG_FINAL" | cut -f1)"

# ── 3. Generate DMG background ────────────────────────────────────────────────
step "Generating DMG background"
BG_PNG="$BUILD_DIR/dmg_background.png"
swift "$ROOT_DIR/Scripts/make_dmg_bg.swift" "$BG_PNG" 540 360 2>/dev/null && \
    ok "Background generated" || { BG_PNG=""; echo "  (skipped)"; }

# ── 4. Stage DMG contents ─────────────────────────────────────────────────────
step "Staging DMG"
STAGING_PARENT="$(mktemp -d)"
STAGING="$STAGING_PARENT/root"
mkdir -p "$STAGING/.background"

# Primary: the .pkg installer (renamed for clarity)
cp "$PKG_FINAL" "$STAGING/Install Clipboard Manager.pkg"

# Background image
[[ -n "${BG_PNG:-}" && -f "$BG_PNG" ]] && cp "$BG_PNG" "$STAGING/.background/bg.png"

ok "Staged .pkg installer"

# ── 5. Create + layout DMG ────────────────────────────────────────────────────
step "Creating DMG"
rm -f "$DMG_PATH" "$BUILD_DIR/rw.dmg"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -size 60m \
    "$BUILD_DIR/rw.dmg" > /dev/null

MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$BUILD_DIR/rw.dmg" -mountpoint "$MOUNT_DIR" -quiet -nobrowse

# Finder layout: single .pkg, centered
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 120, 840, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        try
            set background picture of viewOptions to file ".background:bg.png"
        end try
        set position of item "Install Clipboard Manager.pkg" of container window to {270, 195}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Hide .background
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || \
    chflags hidden "$MOUNT_DIR/.background" 2>/dev/null || true

sync
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
rm -rf "$MOUNT_DIR"

# Convert to compressed read-only
hdiutil convert "$BUILD_DIR/rw.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null
rm -f "$BUILD_DIR/rw.dmg"

rm -rf "$STAGING_PARENT"
ok "Compressed: $(du -sh "$DMG_PATH" | cut -f1)"

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "${BOLD}${GREEN}DMG ready:${RESET} $DMG_PATH"
echo "  Size   : $(du -sh "$DMG_PATH" | cut -f1)"
echo "  Install: open DMG → double-click 'Install Clipboard Manager.pkg'"
echo
