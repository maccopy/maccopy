#!/usr/bin/env bash
# Build a release, zip the .app, update the cask formula, and publish to GitHub.
#
# Usage:
#   bash Scripts/make_release.sh 1.2.0
#
# Requirements:
#   - gh CLI authenticated (gh auth login)
#   - swift, hdiutil, pkgbuild, productbuild available (Xcode CLT)
#
# What it does:
#   1. Bumps version in UpdateChecker.swift + Info.plist (via make_dmg.sh)
#   2. Builds the release binary and .app bundle
#   3. Creates ClipboardManager-<version>.dmg  (for direct download)
#   4. Creates ClipboardManager.zip            (for Homebrew cask)
#   5. Updates Casks/clipboard-manager.rb with new version + sha256
#   6. Creates a GitHub draft release with both assets attached
#   7. Prints next steps (push cask to homebrew-tap repo)

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
CHECKER="Sources/ClipboardManager/UpdateChecker.swift"
sed -i '' "s/static let currentVersion = \"[^\"]*\"/static let currentVersion = \"$VERSION\"/" "$CHECKER"
ok "UpdateChecker.swift → $VERSION"

# ── 2. Build DMG (also builds .app bundle at .build/bundle/ClipboardManager.app)
step "Building release"
RELEASE_VERSION="$VERSION" bash Scripts/make_dmg.sh
DMG_PATH="$ROOT_DIR/ClipboardManager-${VERSION}.dmg"
[[ -f "$DMG_PATH" ]] || { echo "DMG not found: $DMG_PATH" >&2; exit 1; }
ok "DMG: $(du -sh "$DMG_PATH" | cut -f1)"

# ── 3. Zip the .app for Homebrew ──────────────────────────────────────────────
step "Creating ClipboardManager.zip"
ZIP_PATH="$ROOT_DIR/ClipboardManager.zip"
rm -f "$ZIP_PATH"
cd .build/bundle
zip -r "$ZIP_PATH" ClipboardManager.app --quiet
cd "$ROOT_DIR"
ok "ZIP: $(du -sh "$ZIP_PATH" | cut -f1)"

# ── 4. Compute SHA256 ─────────────────────────────────────────────────────────
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
ok "SHA256: $SHA256"

# ── 5. Update cask formula ────────────────────────────────────────────────────
step "Updating Casks/clipboard-manager.rb"
CASK="$ROOT_DIR/Casks/clipboard-manager.rb"
sed -i '' "s/version \"[^\"]*\"/version \"$VERSION\"/" "$CASK"
sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$SHA256\"/" "$CASK"
ok "Cask updated (version + sha256)"

# ── 6. Commit version bump + cask update ─────────────────────────────────────
step "Committing release files"
git add "$CHECKER" "$CASK"
git commit -m "chore: release v$VERSION" || ok "(nothing new to commit)"

# ── 7. Tag ────────────────────────────────────────────────────────────────────
git tag -f "v$VERSION"
ok "Tagged v$VERSION"

# ── 8. GitHub draft release ───────────────────────────────────────────────────
step "Creating GitHub draft release v$VERSION"
gh release create "v$VERSION" \
    "$ZIP_PATH" \
    "$DMG_PATH" \
    --title "v$VERSION" \
    --draft \
    --generate-notes
ok "Draft release created — review and publish at github.com/FernandoHaeser/macos-clipboard-manager/releases"

# ── Next steps ────────────────────────────────────────────────────────────────
echo
echo "${BOLD}Next steps:${RESET}"
echo "  1. Push this repo:            git push && git push --tags"
echo "  2. Publish the draft release: github.com/FernandoHaeser/macos-clipboard-manager/releases"
echo "  3. Copy Casks/clipboard-manager.rb to your homebrew-tap repo and push it"
echo
echo "  Users install with:"
echo "    brew tap FernandoHaeser/tap"
echo "    brew install --cask clipboard-manager"
echo
