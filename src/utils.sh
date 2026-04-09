#!/usr/bin/env bash
set -eo pipefail

# Print helpers
log_action() {
  echo -e "  - $1"
}

log_dry() {
  printf "  ${BLUE}[%5s]${NC} %s\n" "$1" "$2"
}

# Core sweep executor (Paths)
execute_sweep_path() {
  local target_path="$1"
  local description="$2"

  if [ -d "$target_path" ] || [ -f "$target_path" ]; then
    if [ "$DRY_RUN" = true ]; then
      local size=$(du -sh "$target_path" 2>/dev/null | awk '{print $1}')
      [ -n "$size" ] && log_dry "$size" "$description" || log_dry "N/A" "$description"
    else
      if [ "$RESCUE_MODE" = "true" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
          mkdir -p ~/.Trash
          mv "$target_path" ~/.Trash/ 2>/dev/null || true
        else
          mkdir -p ~/.local/share/Trash/files
          mv "$target_path" ~/.local/share/Trash/files/ 2>/dev/null || true
        fi
        log_action "[RESCUED TO TRASH] $description"
      else
        rm -rf "$target_path" 2>/dev/null || true
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
      # Safely execute the array instead of using eval
      "${cmd_args[@]}" >/dev/null 2>&1 || true
      log_action "$description"
    fi
  fi
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
