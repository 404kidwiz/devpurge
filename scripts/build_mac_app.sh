#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="DevPurge"
BUNDLE="$ROOT_DIR/$APP_NAME.app"
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
    <string>3.3.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
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
codesign --force --deep -s - "$BUNDLE" 2>/dev/null || true

# Refresh LaunchServices and touch bundle for Finder / Dock icon recognition
LSREGISTER=$(find /System/Library/Frameworks/CoreServices.framework -name lsregister 2>/dev/null | head -n 1)
if [ -n "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$BUNDLE" 2>/dev/null || true
fi
touch "$BUNDLE"

echo "==> Successfully created $BUNDLE"
echo "You can launch the app by double-clicking DevPurge.app, drag it to your Dock, or run:"
echo "  open \"$BUNDLE\""
