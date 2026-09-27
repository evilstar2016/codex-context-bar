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
cp LICENSE THIRD_PARTY_NOTICES.md "$APP_DIR/Contents/Resources/"
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    printf -v icon_name 'icon_%sx%s' "$size" "$size"
    sips -z "$size" "$size" Resources/Branding/AppLogo.png --out "$ICONSET/$icon_name.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" Resources/Branding/AppLogo.png --out "$ICONSET/$icon_name@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime "$APP_DIR"
printf '%s\n' "$APP_DIR"
