#!/usr/bin/env bash
CONFIG_FILE="$HOME/.devpurge.json"

parse_config() {
  local key=$1
  if [ -f "$CONFIG_FILE" ]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "import sys, json; data=json.load(open('$CONFIG_FILE')); res=data.get('$key', ''); print(' '.join(res) if isinstance(res, list) else str(res).lower())" 2>/dev/null
    fi
  fi
}

# Defaults
AUTO_SWEEP=$(parse_config "automated_sweep")
if [ -z "$AUTO_SWEEP" ]; then AUTO_SWEEP="true"; fi

RESCUE_MODE=$(parse_config "rescue_mode")
if [ -z "$RESCUE_MODE" ]; then RESCUE_MODE="false"; fi

IGNORE_TARGETS=$(parse_config "ignore")
