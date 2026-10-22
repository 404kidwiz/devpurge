#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="DevPurge"
VERSION="3.3.1"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$ROOT_DIR/$DMG_NAME"
STAGING_DIR="$ROOT_DIR/dist_staging"

# 1. Ensure latest app is built
"$SCRIPT_DIR/build_mac_app.sh"

echo "==> Preparing DMG staging environment..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy .app bundle
cp -R "$ROOT_DIR/$APP_NAME.app" "$STAGING_DIR/"

# Create /Applications symlink for easy drag-and-drop installation
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating compressed disk image: $DMG_NAME..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "==> Successfully packaged: $DMG_PATH"
echo "File size: $(du -sh "$DMG_PATH" | cut -f1)"
