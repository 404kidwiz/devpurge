#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="DevPurge"
BUNDLE="${APP_BUNDLE_PATH:-$ROOT_DIR/$APP_NAME.app}"
# Isolated release builds must still target a DevPurge app bundle, never a parent folder.
case "$BUNDLE" in
  /*/DevPurge.app) ;;
  *) echo "APP_BUNDLE_PATH must be an absolute path ending in /DevPurge.app" >&2; exit 1 ;;
esac
CONTENTS="$BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Building native macOS application in release mode..."
cd "$ROOT_DIR/mac"
swift build -c release

RELEASE_BIN="$ROOT_DIR/mac/.build/release/$APP_NAME"
if [ ! -f "$RELEASE_BIN" ]; then
  echo "Error: Release binary not found at $RELEASE_BIN"
  exit 1
fi

echo "==> Constructing $APP_NAME.app bundle structure..."
rm -rf "$BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$RELEASE_BIN" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy AppIcon if present, or generate it
if [ ! -f "$ROOT_DIR/AppIcon.icns" ]; then
  python3 "$ROOT_DIR/scripts/generate_app_icon.py"
fi
cp "$ROOT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Bundled OFL fonts (Lilita One, Courier Prime) and their licences
mkdir -p "$RESOURCES_DIR/Fonts"
cp "$ROOT_DIR/mac/Resources/Fonts/"* "$RESOURCES_DIR/Fonts/"

# Write Info.plist
cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DevPurge</string>
    <key>CFBundleIdentifier</key>
    <string>com.devpurge.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DevPurge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.3.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Write PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Ad-hoc sign for local execution
echo "==> Applying local code signature..."
codesign --force --deep -s - "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"

# Refresh LaunchServices and touch bundle for Finder / Dock icon recognition
LSREGISTER=$(find /System/Library/Frameworks/CoreServices.framework -name lsregister 2>/dev/null | head -n 1)
if [ -n "$LSREGISTER" ] && [ "$BUNDLE" = "$ROOT_DIR/$APP_NAME.app" ]; then
  "$LSREGISTER" -f "$BUNDLE" 2>/dev/null || true
fi
touch "$BUNDLE"

echo "==> Successfully created $BUNDLE"
echo "You can launch the app by double-clicking DevPurge.app, drag it to your Dock, or run:"
echo "  open \"$BUNDLE\""
