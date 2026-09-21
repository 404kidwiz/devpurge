#!/usr/bin/env bash
set -eo pipefail
# DESC: uv Python cache (unreachable entries only)

sweep_uv() {
  echo -e "${YELLOW}[uv] Pruning unreachable cache entries...${NC}"
  execute_sweep_cmd "uv" "Pruned uv cache" uv cache prune
}
