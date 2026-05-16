#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building Maccopy…"
swift build -c release 2>&1

BINARY=".build/release/Maccopy"

if [ ! -f "$BINARY" ]; then
  echo "Build failed — binary not found at $BINARY"
  exit 1
fi

echo "Launching…"
"$BINARY"
