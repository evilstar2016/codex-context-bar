#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ARCH="$(uname -m)"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac
if [[ -n "${RELEASE_TAG:-}" && "$RELEASE_TAG" != "v$VERSION" ]]; then
    echo "Release tag does not match Info.plist version" >&2
    exit 1
fi
./scripts/build-app.sh
APP_DIR="$PWD/build/Codex Context Bar.app"
OUTPUT="$PWD/build/release"
NAME="Codex-Context-Bar-$VERSION-macos-$ARCH"
mkdir -p "$OUTPUT"
codesign --verify --deep --strict "$APP_DIR"
[[ "$(lipo -archs "$APP_DIR/Contents/MacOS/CodexContextBar")" == "$ARCH" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")" == "$VERSION" ]]
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/context-bar-release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_DIR" "$STAGING/Codex Context Bar.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE THIRD_PARTY_NOTICES.md "$STAGING/"
hdiutil create -volname "Codex Context Bar $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT/$NAME.dmg"
hdiutil verify "$OUTPUT/$NAME.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$OUTPUT/$NAME.zip"
unzip -tq "$OUTPUT/$NAME.zip"
(cd "$OUTPUT" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > "$NAME.sha256")
printf '%s\n' "$OUTPUT/$NAME.dmg" "$OUTPUT/$NAME.zip" "$OUTPUT/$NAME.sha256"
