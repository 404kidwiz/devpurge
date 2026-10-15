#!/usr/bin/env bash
set -eo pipefail
# DESC: AI Tool Bloat (Codex, Claude Code, Cursor)

# Reports per-tool cache/log/crash-report sizes. Deletes only regenerable
# caches, logs and crash reports with --yes or a typed confirmation.
# Sessions, projects, settings, auth and history files are never touched.
sweep_ai() {
  echo -e "${YELLOW}[AI Tools] Codex, Claude Code and Cursor bloat...${NC}"
  local ai_args=()
  if [ "$DRY_RUN" = false ]; then ai_args+=(--execute); fi
  python3 "$DIR/ai_bloat.py" "${ai_args[@]}"
  execute_sweep_path "$HOME/.ollama/tmp" "Ollama temp files"
}
