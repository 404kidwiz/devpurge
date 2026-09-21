#!/usr/bin/env bash
set -eo pipefail
# DESC: System (Brew/Apt)

sweep_system() {
  echo -e "${YELLOW}[System Manager] Sweeping caches...${NC}"
  if [ "$DRY_RUN" = true ]; then
    if command -v brew >/dev/null 2>&1; then
      HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -n
    fi
  else
    execute_sweep_cmd "brew" "Pruned Homebrew cache" env HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      execute_sweep_cmd "apt-get" "Cleared APT cache" sudo -n apt-get clean
    fi
  fi
}
