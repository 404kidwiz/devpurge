#!/usr/bin/env bash
# DESC: Node Ecosystem

sweep_node() {
  echo -e "${YELLOW}[Node Ecosystem] Sweeping caches...${NC}"
  execute_sweep_cmd "npm" "npm cache clean --force" "Purged npm cache"
  execute_sweep_cmd "pnpm" "pnpm store prune" "Pruned pnpm store"
  execute_sweep_path "$HOME/.npm/_cacache" "Cleared inner npm bloat"
  execute_sweep_path "$HOME/Library/Caches/node-gyp" "Cleared node-gyp caches"
}
