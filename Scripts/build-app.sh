#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/StudyFlow.app"
PLUGIN_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

mkdir -p "$DIST"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ARCH="${ARCH:-$(uname -m)}"
MODULE_CACHE="$ROOT/.build/clang-module-cache"
mkdir -p "$MODULE_CACHE"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

APP_SOURCES=()
while IFS= read -r -d '' source_file; do
    APP_SOURCES+=("$source_file")
done < <(find "$ROOT/Sources/StudyFlow" -name '*.swift' -print0)


xcrun swiftc \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -swift-version 6 \
    -target "${ARCH}-apple-macosx14.0" \
    -sdk "$SDK" \
    -plugin-path "$PLUGIN_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    "${APP_SOURCES[@]}" \
    -o "$APP/Contents/MacOS/StudyFlow"


cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

codesign \
    --force \
    --sign "$CODE_SIGN_IDENTITY" \
    --entitlements "$ROOT/Resources/StudyFlow.entitlements" \
    --options runtime \
    "$APP"

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built: $APP"
