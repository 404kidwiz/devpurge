#!/usr/bin/env bash

sweep_system() {
  echo -e "${YELLOW}[System Manager] Sweeping caches...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    if command -v brew >/dev/null 2>&1; then
      local size=$(brew cleanup -n 2>/dev/null | grep 'would free' | awk '{print $7$8}' | head -n 1)
      [ -n "$size" ] && log_dry "$size" "Prunable Homebrew cache" || log_dry "0B" "Homebrew clean"
    fi
  else
    execute_sweep_cmd "brew" "brew cleanup --prune=all" "Pruned Homebrew cache"
    execute_sweep_cmd "apt-get" "sudo apt-get clean" "Cleared APT cache"
  fi
}
