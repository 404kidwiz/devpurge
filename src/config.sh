#!/usr/bin/env bash
set -eo pipefail
CONFIG_FILE="$HOME/.devpurge.json"

parse_config() {
  local key=$1
  if [ -f "$CONFIG_FILE" ]; then
    python3 - "$CONFIG_FILE" "$key" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as config:
        data = json.load(config)
    if not isinstance(data, dict):
        raise ValueError('configuration must be an object')
    for key in ('automated_sweep', 'rescue_mode'):
        if key in data and not isinstance(data[key], bool):
            raise ValueError(key + ' must be a boolean')
    if 'ignore' in data and (not isinstance(data['ignore'], list) or
                            not all(isinstance(item, str) for item in data['ignore'])):
        raise ValueError('ignore must be a list of module names')
    days = data.get('interval_days', 7)
    if type(days) is not int or not 1 <= days <= 365:
        raise ValueError('interval_days must be an integer between 1 and 365')
    result = data.get(sys.argv[2], '')
    print(' '.join(result) if isinstance(result, list) else str(result).lower())
except (OSError, ValueError) as error:
    print('Invalid DevPurge config: ' + str(error), file=sys.stderr)
    sys.exit(1)
PY
  fi
}

# Defaults
AUTO_SWEEP=$(parse_config "automated_sweep")
if [ -z "$AUTO_SWEEP" ]; then AUTO_SWEEP="false"; fi

RESCUE_MODE=$(parse_config "rescue_mode")
if [ -z "$RESCUE_MODE" ]; then RESCUE_MODE="false"; fi

IGNORE_TARGETS=$(parse_config "ignore")
export IGNORE_TARGETS
INTERVAL_DAYS=$(parse_config "interval_days")
if [ -z "$INTERVAL_DAYS" ]; then INTERVAL_DAYS=7; fi
