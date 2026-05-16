#!/usr/bin/env bash
# Build a release, zip the .app, and publish to GitHub.
#
# Usage:
#   bash Scripts/make_release.sh 1.2.0
#
# Requirements:
#   - gh CLI authenticated (gh auth login)
#   - swift, hdiutil, pkgbuild, productbuild available (Xcode CLT)
#
# What it does:
#   1. Bumps version in UpdateChecker.swift
#   2. Builds the release binary and .app bundle
#   3. Creates Maccopy-<version>.dmg  (for direct download)
#   4. Creates Maccopy.zip            (for Homebrew cask)
#   5. Prints sha256 so you can update maccopy/homebrew-tap manually
#   6. Creates a GitHub draft release with both assets attached

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>   e.g.  $0 1.2.0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

BOLD=$'\033[1m'; RESET=$'\033[0m'
GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'
step() { echo; echo "${BOLD}${BLUE}▶ $*${RESET}"; }
ok()   { echo "  ${GREEN}✓${RESET}  $*"; }

# ── 1. Bump version in source ─────────────────────────────────────────────────
step "Bumping version to $VERSION"
CHECKER="Sources/Maccopy/UpdateChecker.swift"
sed -i '' "s/static let currentVersion = \"[^\"]*\"/static let currentVersion = \"$VERSION\"/" "$CHECKER"
ok "UpdateChecker.swift → $VERSION"

# ── 2. Build DMG ─────────────────────────────────────────────────────────────
step "Building release"
RELEASE_VERSION="$VERSION" bash Scripts/make_dmg.sh
DMG_PATH="$ROOT_DIR/Maccopy-${VERSION}.dmg"
[[ -f "$DMG_PATH" ]] || { echo "DMG not found: $DMG_PATH" >&2; exit 1; }
ok "DMG: $(du -sh "$DMG_PATH" | cut -f1)"

# ── 3. Zip the .app for Homebrew ──────────────────────────────────────────────
step "Creating Maccopy.zip"
ZIP_PATH="$ROOT_DIR/Maccopy.zip"
rm -f "$ZIP_PATH"
cd .build/bundle
zip -r "$ZIP_PATH" Maccopy.app --quiet
cd "$ROOT_DIR"
ok "ZIP: $(du -sh "$ZIP_PATH" | cut -f1)"

# ── 4. Compute SHA256 ─────────────────────────────────────────────────────────
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
ok "SHA256: $SHA256"

# ── 5. Commit version bump + tag ─────────────────────────────────────────────
step "Committing and tagging v$VERSION"
git add "$CHECKER"
git commit -m "chore: release v$VERSION" || ok "(nothing new to commit)"
git tag -f "v$VERSION"
ok "Tagged v$VERSION"

# ── 6. GitHub draft release ───────────────────────────────────────────────────
step "Creating GitHub draft release v$VERSION"
gh release create "v$VERSION" \
    "$ZIP_PATH" \
    "$DMG_PATH" \
    --title "v$VERSION" \
    --draft \
    --generate-notes
ok "Draft release created"

# ── Next steps ────────────────────────────────────────────────────────────────
echo
echo "${BOLD}Next steps:${RESET}"
echo "  1. git push && git push --tags"
echo "  2. Publish the draft: github.com/FernandoHaeser/macos-clipboard-manager/releases"
echo "  3. Update maccopy/homebrew-tap Casks/maccopy.rb:"
echo "       version \"$VERSION\""
echo "       sha256  \"$SHA256\""
echo
echo "  Users install with:"
echo "    brew tap maccopy/tap"
echo "    brew install --cask maccopy"
echo
