#!/usr/bin/env bash
set -eo pipefail
# DESC: System (Brew/Apt)

sweep_system() {
  echo -e "${YELLOW}[System Manager] Sweeping caches...${NC}"
  if [ "$DRY_RUN" = true ]; then
    if command -v brew >/dev/null 2>&1; then
      local size=$(brew cleanup -n 2>/dev/null | grep 'would free' | awk '{print $7$8}' | head -n 1 || true)
      [ -n "$size" ] && log_dry "$size" "Prunable Homebrew cache" || log_dry "0B" "Homebrew clean"
    fi
  else
    execute_sweep_cmd "brew" "Pruned Homebrew cache" brew cleanup --prune=all
    execute_sweep_cmd "apt-get" "Cleared APT cache" sudo apt-get clean
  fi
}
