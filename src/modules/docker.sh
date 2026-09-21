#!/usr/bin/env bash
set -eo pipefail
# DESC: Docker Volumes

sweep_docker() {
  echo -e "${YELLOW}[Docker] Sweeping container bloat...${NC}"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      docker system df
    else
      execute_sweep_cmd docker "Pruned Docker resources including unused anonymous volumes" docker system prune -af --volumes
    fi
  else
    if [ "$DRY_RUN" = true ]; then
      log_dry "N/A" "Docker not running; reclaimable space unknown"
    else
      echo "Docker is unavailable; cleanup was not performed." >&2
      return 1
    fi
  fi
}
