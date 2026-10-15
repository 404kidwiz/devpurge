#!/usr/bin/env bash
set -eo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/lib/devpurge"
BIN_DIR="$HOME/.local/bin"
SCHEDULE=false
case "${1:-}" in
  "") ;;
  --schedule) SCHEDULE=true ;;
  *) echo "Usage: bash install.sh [--schedule]" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then echo "Too many arguments" >&2; exit 1; fi
# Validate configuration before changing an existing installation.
# shellcheck source=src/config.sh
source "$SOURCE_DIR/src/config.sh"
if [ "$SCHEDULE" = true ] && [ "$AUTO_SWEEP" != true ]; then
  echo 'Set automated_sweep to true in ~/.devpurge.json before opting into --schedule.' >&2
  exit 1
fi
command -v python3 >/dev/null || { echo "Python 3 is required for JSON configuration." >&2; exit 1; }

if [ "$SOURCE_DIR" != "$TARGET_DIR" ]; then
  if [ -e "$TARGET_DIR" ]; then
    BACKUP_DIR=$(mktemp -d "${TARGET_DIR}.backup.XXXXXX")
    cp -R "$TARGET_DIR/." "$BACKUP_DIR/"
    echo "Previous installation backed up to $BACKUP_DIR"
  fi
  mkdir -p "$TARGET_DIR/bin" "$BIN_DIR"
  cp -R "$SOURCE_DIR/src" "$TARGET_DIR/"
  cp "$SOURCE_DIR/bin/devpurge" "$TARGET_DIR/bin/devpurge"
  cp "$SOURCE_DIR/install.sh" "$TARGET_DIR/install.sh"
fi
mkdir -p "$BIN_DIR"
chmod +x "$TARGET_DIR/bin/devpurge"
ln -sf "$TARGET_DIR/bin/devpurge" "$BIN_DIR/devpurge"
if [ ! -f "$HOME/.devpurge.json" ]; then
  printf '%s\n' '{"automated_sweep": false, "interval_days": 7, "rescue_mode": false, "ignore": []}' > "$HOME/.devpurge.json"
fi

echo "DevPurge CLI installed: $BIN_DIR/devpurge"
if [ "$SCHEDULE" = false ]; then
  echo "No scheduler created or enabled. Existing scheduler settings are unchanged."
  exit 0
fi

mkdir -p "$HOME/.devpurge/logs"
INTERVAL_SECONDS=$((INTERVAL_DAYS * 86400))
JOB_PATH="$BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ "$OSTYPE" == darwin* ]]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  PLIST_PATH="$HOME/Library/LaunchAgents/com.devpurge.sweeper.plist"
  if [ -f "$PLIST_PATH" ]; then cp "$PLIST_PATH" "${PLIST_PATH}.backup.$(date +%s)"; fi
  python3 - "$PLIST_PATH" "$BIN_DIR/devpurge" "$INTERVAL_SECONDS" "$JOB_PATH" "$HOME/.devpurge/logs" <<'PLIST'
import plistlib, sys
path, binary, interval, job_path, logs = sys.argv[1:]
with open(path, 'wb') as output:
    plistlib.dump({
        'Label': 'com.devpurge.sweeper',
        'ProgramArguments': ['/bin/bash', binary, '--background', '--all'],
        'EnvironmentVariables': {'PATH': job_path},
        'StartInterval': int(interval), 'RunAtLoad': False,
        'StandardOutPath': logs + '/sweeper.log',
        'StandardErrorPath': logs + '/sweeper-error.log',
    }, output)
PLIST
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH"
elif [[ "$OSTYPE" == linux-gnu* ]]; then
  mkdir -p "$HOME/.config/systemd/user"
  SERVICE_PATH="$HOME/.config/systemd/user/devpurge.service"
  TIMER_PATH="$HOME/.config/systemd/user/devpurge.timer"
  for job_file in "$SERVICE_PATH" "$TIMER_PATH"; do
    if [ -f "$job_file" ]; then cp "$job_file" "${job_file}.backup.$(date +%s)"; fi
  done
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=DevPurge cache cleanup
[Service]
Type=oneshot
Environment="PATH=$JOB_PATH"
ExecStart=/bin/bash "%h/.local/bin/devpurge" --background --all
EOF
  cat > "$TIMER_PATH" <<EOF
[Unit]
Description=Scheduled DevPurge cache cleanup
[Timer]
OnActiveSec=${INTERVAL_SECONDS}s
OnUnitActiveSec=${INTERVAL_SECONDS}s
[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now devpurge.timer
else
  echo "Scheduling is not supported on $OSTYPE" >&2
  exit 1
fi
echo "Cache cleanup scheduled every $INTERVAL_DAYS days; no immediate sweep."
