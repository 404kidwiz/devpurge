#!/usr/bin/env bash

# DevPurge One-Liner Installer
set -e

echo "Installing DevPurge Daemon..."

# Determine paths
TARGET_DIR=~/.local/lib/devpurge
BIN_DIR=~/.local/bin
PLIST_PATH=~/Library/LaunchAgents/com.devpurge.sweeper.plist

mkdir -p "$TARGET_DIR"
mkdir -p "$BIN_DIR"
mkdir -p ~/.devpurge/logs

# Copy files
cp -R "$(dirname "$0")/src" "$TARGET_DIR/"
cp "$(dirname "$0")/bin/devpurge" "$TARGET_DIR/devpurge"
chmod +x "$TARGET_DIR/devpurge"

# Symlink to bin
ln -sf "$TARGET_DIR/devpurge" "$BIN_DIR/devpurge"

# Generate Plist
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devpurge.sweeper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$BIN_DIR/devpurge</string>
        <string>--all</string>
    </array>
    <key>StartInterval</key>
    <integer>604800</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.devpurge/logs/sweeper.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.devpurge/logs/sweeper-error.log</string>
</dict>
</plist>
EOF

# Load daemon (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
  echo "✅ LaunchDaemon activated. DevPurge will run every 7 days."
fi

echo "✅ DevPurge installed globally. Run 'devpurge --help' to use it."
