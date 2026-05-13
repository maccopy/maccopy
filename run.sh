#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building ClipboardManager…"
swift build -c release 2>&1

BINARY=".build/release/ClipboardManager"

if [ ! -f "$BINARY" ]; then
  echo "Build failed — binary not found at $BINARY"
  exit 1
fi

echo "Launching…"
"$BINARY"
