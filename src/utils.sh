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
      rm -rf "$target_path" 2>/dev/null
      log_action "$description"
    fi
  fi
}

execute_sweep_cmd() {
  local cmd_check="$1"
  local cmd_run="$2"
  local description="$3"

  if command -v $cmd_check >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      # Usually can't calculate exact free space for arbitrary commands easily without running them. 
      log_dry "CMD" "$description (Command pending)"
    else
      eval "$cmd_run" >/dev/null 2>&1
      log_action "$description"
    fi
  fi
}
