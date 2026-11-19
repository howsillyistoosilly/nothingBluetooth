#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Debug avoids SwiftPM's in-build dsymutil step, which is blocked in restricted shells.
CONFIGURATION="${1:-debug}"
mkdir -p "$ROOT_DIR/.build/swift-cache" "$ROOT_DIR/.build/clang-cache"
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swift-cache/modules"
export CLANG_MODULE_CACHE_PATH SWIFTPM_MODULECACHE_OVERRIDE
swift build --package-path "$ROOT_DIR" --disable-sandbox --cache-path "$ROOT_DIR/.build/swift-cache" -c "$CONFIGURATION"

APP_DIR="$ROOT_DIR/.build/NothingController.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$RESOURCES_DIR/CMFControl_CMFControl.bundle"
cp -R "$ROOT_DIR/.build/$CONFIGURATION/CMFControl_CMFControl.bundle" "$RESOURCES_DIR/CMFControl_CMFControl.bundle"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Icon/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/.build/$CONFIGURATION/CMFControl" "$MACOS_DIR/NothingController"
codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
