#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/StudyFlow.app"
ARCH="${ARCH:-$(uname -m)}"
MODULE_CACHE="$ROOT/.build/clang-module-cache"
BUILD_HOME="${SWIFT_HOME:-$ROOT/.home}"
BUILD_TMPDIR="${SWIFT_TMPDIR:-$ROOT/.tmp}"

mkdir -p "$DIST" "$MODULE_CACHE" "$BUILD_HOME" "$BUILD_TMPDIR"
export HOME="$BUILD_HOME"
export TMPDIR="$BUILD_TMPDIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"

python3 - "$APP" <<'PY_CLEAN'
import pathlib
import shutil
import sys

app = pathlib.Path(sys.argv[1])
if app.exists():
    shutil.rmtree(app)
app.parent.mkdir(parents=True, exist_ok=True)
(app / "Contents" / "MacOS").mkdir(parents=True)
(app / "Contents" / "Resources").mkdir(parents=True)
PY_CLEAN

swift build \
    --disable-sandbox \
    -c release \
    --product StudyFlow \
    --arch "$ARCH"

BINARY="$ROOT/.build/out/Products/Release/StudyFlow"
if [[ ! -f "$BINARY" ]]; then
    BINARY="$(find "$ROOT/.build/out/Products" -type f -name StudyFlow -path '*/Release/*' -print -quit)"
fi
if [[ -z "$BINARY" || ! -f "$BINARY" ]]; then
    echo "Unable to locate release binary for StudyFlow" >&2
    exit 1
fi

cp "$BINARY" "$APP/Contents/MacOS/StudyFlow"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
codesign \
    --force \
    --deep \
    --sign "$CODE_SIGN_IDENTITY" \
    --entitlements "$ROOT/Resources/StudyFlow.entitlements" \
    --options runtime \
    "$APP"

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
