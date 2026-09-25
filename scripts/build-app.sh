#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/Notch Codex.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$ROOT_DIR"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp ".build/release/NotchCodex" "$CONTENTS_DIR/MacOS/NotchCodex"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/NotchCodex.entitlements" "$CONTENTS_DIR/Resources/NotchCodex.entitlements"
cp ".build/checkouts/SwiftTerm/LICENSE" "$CONTENTS_DIR/Resources/SwiftTerm-LICENSE.txt"
cp "Resources/LibrariesDev-NOTICE.txt" "$CONTENTS_DIR/Resources/LibrariesDev-NOTICE.txt"
cp "Resources/codex.svg" "$CONTENTS_DIR/Resources/codex.svg"
codesign --force --deep --sign - --entitlements "Resources/NotchCodex.entitlements" "$APP_DIR"
echo "$APP_DIR"
