#!/usr/bin/env bash
#
# Package dist/DockBuddies.app into dist/DockBuddies.dmg
#
# The DMG contains the .app and a symlink to /Applications, giving users the
# standard "drag the icon onto Applications" install experience.
#
# Usage:
#   scripts/build-dmg.sh                 # writes dist/DockBuddies.dmg
#   VERSION=1.2.3 scripts/build-dmg.sh   # writes dist/DockBuddies-1.2.3.dmg
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DockBuddies"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING="$DIST_DIR/.dmg-staging"

if [ -n "${VERSION:-}" ]; then
  DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
else
  DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
fi

if [ ! -d "$APP_BUNDLE" ]; then
  echo "error: $APP_BUNDLE not found — run scripts/build-app.sh first" >&2
  exit 1
fi

echo "==> Preparing DMG staging directory"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

echo ""
echo "✅ Created $DMG_PATH"
echo "   Mount:  open $DMG_PATH"
