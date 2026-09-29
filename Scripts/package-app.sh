#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/StudyFlow.app"

if [[ ! -d "$APP" ]]; then
    echo "Missing $APP. Run Scripts/build-app.sh first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$DIST/StudyFlow-${VERSION}-macOS.zip"
TMP_ZIP="${ZIP}.tmp"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/StudyFlow-package.XXXXXX")"

cleanup() {
    /bin/rm -f "$TMP_ZIP"
    /bin/rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"

# Use zip directly. ditto --sequesterRsrc creates a second, invalid
# __MACOSX/StudyFlow.app bundle in the archive; users can accidentally launch
# that metadata bundle and receive kLSNoExecutableErr.
/bin/rm -f "$TMP_ZIP"
(
    cd "$DIST"
    zip -qry "$TMP_ZIP" StudyFlow.app
)

if zipinfo -1 "$TMP_ZIP" | grep -Eq '^__MACOSX/|(^|/)\._'; then
    echo "Release archive contains AppleDouble metadata or a duplicate app bundle." >&2
    exit 1
fi

/bin/mv "$TMP_ZIP" "$ZIP"
unzip -q "$ZIP" -d "$VERIFY_DIR"

EXTRACTED="$VERIFY_DIR/StudyFlow.app"
test -x "$EXTRACTED/Contents/MacOS/StudyFlow"
plutil -lint "$EXTRACTED/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$EXTRACTED"

echo "Packaged: $ZIP"
echo "SHA256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
