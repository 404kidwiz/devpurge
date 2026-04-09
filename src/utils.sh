#!/usr/bin/env bash

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
          mv "$target_path" ~/.Trash/ 2>/dev/null
        else
          mkdir -p ~/.local/share/Trash/files
          mv "$target_path" ~/.local/share/Trash/files/ 2>/dev/null
        fi
        log_action "[RESCUED TO TRASH] $description"
      else
        rm -rf "$target_path" 2>/dev/null
        log_action "$description"
      fi
    fi
  fi
}

execute_sweep_cmd() {
  local cmd_check="$1"
  local cmd_run="$2"
  local description="$3"

  if command -v $cmd_check >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      log_dry "CMD" "$description (Command pending)"
    else
      eval "$cmd_run" >/dev/null 2>&1
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
