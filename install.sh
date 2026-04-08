#!/usr/bin/env bash

# DevPurge One-Liner Installer
set -e

echo "Installing DevPurge V2 OS Daemon..."

TARGET_DIR=~/.local/lib/devpurge
BIN_DIR=~/.local/bin

mkdir -p "$TARGET_DIR"
mkdir -p "$BIN_DIR"
mkdir -p ~/.devpurge/logs

cp -R "$(dirname "$0")/src" "$TARGET_DIR/"
cp "$(dirname "$0")/bin/devpurge" "$TARGET_DIR/devpurge"
chmod +x "$TARGET_DIR/devpurge"
ln -sf "$TARGET_DIR/devpurge" "$BIN_DIR/devpurge"

# Setup default config if none exists
if [ ! -f ~/.devpurge.json ]; then
cat > ~/.devpurge.json <<EOF
{
  "automated_sweep": true,
  "interval_days": 7,
  "ignore": ["docker"]
}
EOF
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_PATH=~/Library/LaunchAgents/com.devpurge.sweeper.plist
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
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
  echo "✅ macOS LaunchDaemon activated. DevPurge will run every 7 days."

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  mkdir -p ~/.config/systemd/user
  SERVICE_PATH=~/.config/systemd/user/devpurge.service
  TIMER_PATH=~/.config/systemd/user/devpurge.timer

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=DevPurge Cache Sweeper

[Service]
Type=oneshot
ExecStart=/bin/bash $BIN_DIR/devpurge --all
StandardOutput=append:%h/.devpurge/logs/sweeper.log
StandardError=append:%h/.devpurge/logs/sweeper-error.log
EOF

cat > "$TIMER_PATH" <<EOF
[Unit]
Description=Run DevPurge weekly

[Timer]
OnUnitActiveSec=7d
OnBootSec=5m

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now devpurge.timer 2>/dev/null || echo "SystemD not found or user services disabled."
  echo "✅ Linux SystemD Timer activated. DevPurge will run every 7 days."
fi

echo "✅ DevPurge V2 installed globally. Run 'devpurge' natively to open the TUI."
