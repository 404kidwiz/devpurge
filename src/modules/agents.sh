#!/usr/bin/env bash
set -eo pipefail
# DESC: Agent Leftovers [Pro] (stale worktrees, duplicate clones, OpenCode caches)

# Report-first. Removes only clean, fully pushed, stale agent worktrees via
# `git worktree remove` (no --force). Duplicate clones need a typed name each.
sweep_agents() {
  echo -e "${YELLOW}[Agents] Worktrees, clones and caches from parallel agent runs...${NC}"
  local agent_args=()
  if [ "$DRY_RUN" = false ]; then agent_args+=(--execute); fi
  python3 "$DIR/agents.py" "${agent_args[@]}"
}
