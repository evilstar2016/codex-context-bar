#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PWD/build/Codex Context Bar.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/CodexContextBar" "$APP_DIR/Contents/MacOS/CodexContextBar"
cp -R "$BIN_DIR/CodexContextBar_CodexContextBar.bundle" "$APP_DIR/Contents/Resources/"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime "$APP_DIR"
printf '%s\n' "$APP_DIR"
