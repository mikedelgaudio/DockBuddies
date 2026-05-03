#!/usr/bin/env bash
#
# Build a release DockBuddies.app into ./dist
#
# Usage:
#   scripts/build-app.sh                 # universal binary (arm64 + x86_64)
#   VERSION=1.2.3 scripts/build-app.sh   # also stamp Info.plist with that version
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DockBuddies"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INFO_PLIST_SRC="Resources/Info.plist"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift toolchain not found in PATH" >&2
  exit 1
fi

echo "==> Cleaning previous bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"

# Universal (arm64 + x86_64) builds require full Xcode because SwiftPM's
# --arch flag goes through xcbuild. On dev machines that only have the
# Command Line Tools, fall back to a host-arch build with a warning.
HAS_XCODE=0
if xcode-select -p 2>/dev/null | grep -qv "CommandLineTools"; then
  HAS_XCODE=1
fi
# Allow callers to force single-arch (faster) or universal explicitly.
UNIVERSAL="${UNIVERSAL:-auto}"
if [ "$UNIVERSAL" = "auto" ]; then
  if [ "$HAS_XCODE" = "1" ]; then
    UNIVERSAL=1
  else
    UNIVERSAL=0
  fi
fi

if [ "$UNIVERSAL" = "1" ]; then
  echo "==> Building release binary (universal: arm64 + x86_64)"
  swift build -c release --arch arm64 --arch x86_64
  BIN_PATH=".build/apple/Products/Release/$APP_NAME"
else
  echo "==> Building release binary (host arch only — full Xcode required for universal)"
  swift build -c release
  BIN_PATH=".build/release/$APP_NAME"
fi

if [ ! -f "$BIN_PATH" ]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "==> Assembling $APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_SRC" "$APP_BUNDLE/Contents/Info.plist"

# Stamp the version if VERSION is set (CI passes the git tag, e.g. "1.2.3").
if [ -n "${VERSION:-}" ]; then
  echo "==> Stamping version $VERSION into Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
    "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" \
       "$APP_BUNDLE/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" \
    "$APP_BUNDLE/Contents/Info.plist"
fi

echo "==> Ad-hoc code signing"
# Ad-hoc signature (no Developer ID). Without notarization, users will get a
# Gatekeeper prompt on first launch and need to right-click -> Open.
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ Built $APP_BUNDLE"
echo "   Run with:  open $APP_BUNDLE"
echo "   Package:   scripts/build-dmg.sh"
