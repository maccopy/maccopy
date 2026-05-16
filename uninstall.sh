#!/usr/bin/env bash
# Maccopy uninstaller

set -euo pipefail

APP_NAME="Maccopy"
BUNDLE_ID="com.maccopy.maccopy"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
DATA_DIR="$HOME/Library/Application Support/Maccopy"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}==> ${NC}$*"; }
warn() { echo -e "${YELLOW}==> ${NC}$*"; }

info "Stopping ${APP_NAME}..."
pkill -x "$APP_NAME" 2>/dev/null && echo "  Stopped." || echo "  Not running."

if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
  info "Removing LaunchAgent…"
  launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
  rm -f "$LAUNCH_AGENT_PLIST"
fi

if [[ -d "$APP_BUNDLE" ]]; then
  info "Removing app bundle…"
  rm -rf "$APP_BUNDLE"
fi

read -r -p "Remove clipboard history data? [y/N] " remove_data
if [[ "$remove_data" =~ ^[Yy] ]]; then
  rm -rf "$DATA_DIR"
  info "History data removed."
else
  warn "History kept at: $DATA_DIR"
fi

rm -f "$HOME/Library/Logs/$APP_NAME.log"

info "Uninstall complete."
echo ""
echo "  Remove from System Settings manually:"
echo "  Privacy & Security → Accessibility → remove $APP_NAME"
echo "  Privacy & Security → Input Monitoring → remove $APP_NAME"
echo ""
