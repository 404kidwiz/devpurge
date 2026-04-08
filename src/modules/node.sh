#!/usr/bin/env bash

sweep_node() {
  echo -e "${YELLOW}[Node Ecosystem] Sweeping caches...${NC}"
  
  if command -v npm >/dev/null 2>&1; then
    npm cache clean --force >/dev/null 2>&1
    echo "  - Purged npm cache"
  fi

  if command -v pnpm >/dev/null 2>&1; then
    pnpm store prune >/dev/null 2>&1
    echo "  - Pruned pnpm store"
  fi

  rm -rf ~/.npm/_cacache/* 2>/dev/null
  rm -rf ~/Library/Caches/node-gyp/* 2>/dev/null
  echo "  - Cleared internal npm/gyp bloat"
}
