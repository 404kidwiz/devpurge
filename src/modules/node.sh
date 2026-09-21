#!/usr/bin/env bash
set -eo pipefail
# DESC: Node Ecosystem

sweep_node() {
  echo -e "${YELLOW}[Node Ecosystem] Sweeping caches...${NC}"
  execute_sweep_cmd "npm" "Purged npm cache" npm cache clean --force
  execute_sweep_cmd "pnpm" "Pruned pnpm store" pnpm store prune
  execute_sweep_path "$HOME/Library/Caches/node-gyp" "Cleared node-gyp caches"
}
