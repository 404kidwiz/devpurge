#!/usr/bin/env bash
set -eo pipefail
# DESC: Docker Volumes

sweep_docker() {
  echo -e "${YELLOW}[Docker] Sweeping container bloat...${NC}"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      local size=$(docker system df | grep 'Images\|Containers\|Local Volumes' | awk '{sum+=$4} END {print sum"B"}' || true)
      [ -n "$size" ] && log_dry "$size" "Prunable Docker Resources" || log_dry "0B" "Docker Clean"
    else
      docker system prune -af --volumes >/dev/null 2>&1 || true
      log_action "Pruned orphaned Docker volumes, images, and networks"
    fi
  else
    if [ "$DRY_RUN" = true ]; then log_dry "N/A" "Docker not running"; fi
  fi
}
