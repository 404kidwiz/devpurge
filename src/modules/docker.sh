#!/usr/bin/env bash
set -eo pipefail
# DESC: Docker Volumes

sweep_docker() {
  echo -e "${YELLOW}[Docker] Sweeping container bloat...${NC}"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      docker system df
    else
      if [ "${DEVPURGE_YES:-false}" != true ]; then
        if [ ! -t 0 ]; then
          echo "Docker prune deletes stopped containers, unused images and volumes. Re-run with --yes to confirm." >&2
          return 1
        fi
        echo -e "${YELLOW}This runs 'docker system prune -af --volumes' and can delete container data.${NC}"
        local reply
        read -r -p "Type 'prune docker' to continue: " reply
        if [ "$reply" != "prune docker" ]; then
          echo "Docker cleanup cancelled." >&2
          return 1
        fi
      fi
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
