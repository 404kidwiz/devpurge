#!/usr/bin/env bash
set -eo pipefail

# Print helpers
log_action() {
  echo -e "  - $1"
}

log_dry() {
  printf '  %b[%9s]%b %s\n' "$BLUE" "$1" "$NC" "$2"
}

# Core sweep executor (Paths)
execute_sweep_path() {
  local target_path="$1"
  local description="$2"

  if [ -d "$target_path" ] || [ -f "$target_path" ]; then
    local protected
    if ! protected=$(python3 "$DIR/safety.py" "$target_path"); then
      log_action "[REFUSED] $description: protected path (${protected:-check failed})" >&2
      return 1
    fi
    if [ "$DRY_RUN" = true ]; then
      local kb size
      # du -k reports allocated 1024-byte blocks; units.py prints decimal GB like Finder.
      kb=$(du -sk "$target_path" | awk '{print $1}') || return 1
      size=$(python3 "$DIR/units.py" "$((kb * 1024))") || return 1
      log_dry "$size" "$description (directory size, not guaranteed savings)"
    else
      if [ "$RESCUE_MODE" = "true" ]; then
        local trash_root rescue_dir
        # Same rescue location on every OS (matches report.py); override with DEVPURGE_TRASH_DIR.
        trash_root="${DEVPURGE_TRASH_DIR:-$HOME/.Trash}"
        mkdir -p "$trash_root" || return 1
        rescue_dir=$(mktemp -d "$trash_root/devpurge.XXXXXX") || return 1
        mv "$target_path" "$rescue_dir/" || return 1
        log_action "[RESCUED TO TRASH] $description"
      else
        if ! rm -rf -- "$target_path"; then
          log_action "[FAILED] $description" >&2
          return 1
        fi
        log_action "$description"
      fi
    fi
  fi
}

execute_sweep_cmd() {
  local cmd_check="$1"
  local description="$2"
  shift 2
  local cmd_args=("$@")

  if command -v "$cmd_check" >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "CMD" "$description (Command pending)"
    else
      if [ "$RESCUE_MODE" = true ]; then
        log_action "[SKIPPED] $description: command cannot be rescued to Trash"
        return 0
      fi
      if ! "${cmd_args[@]}"; then
        log_action "[FAILED] $description" >&2
        return 1
      fi
      log_action "$description"
    fi
  else
    log_action "[SKIPPED] $description: $cmd_check is not installed"
  fi
}

# Activity-aware manual cleanup groups
run_targeted_cleanup() {
  local report_args=(--category "$1")
  if [ "$DRY_RUN" = false ]; then report_args+=(--execute); fi
  if [ "$RESCUE_MODE" = true ]; then report_args+=(--rescue); fi
  python3 "$DIR/report.py" "${report_args[@]}"
}

# Background Notification Engine
notify_desktop() {
  local message="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e "display notification \"$message\" with title \"DevPurge\"" 2>/dev/null || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "DevPurge" "$message" 2>/dev/null || true
  fi
}
