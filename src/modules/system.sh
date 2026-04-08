#!/usr/bin/env bash

sweep_system() {
  echo -e "${YELLOW}[System Manager] Sweeping caches...${NC}"
  
  if command -v brew >/dev/null 2>&1; then
    brew cleanup --prune=all >/dev/null 2>&1
    echo "  - Pruned Homebrew cache"
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get clean >/dev/null 2>&1
    echo "  - Cleared APT cache"
  fi
}
