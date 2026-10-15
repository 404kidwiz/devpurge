#!/usr/bin/env bash
set -eo pipefail
# DESC: AI Agent Bloat

sweep_ai() {
  echo -e "${YELLOW}[AI Tools] Sweeping historical bloat...${NC}"
  if [ "$DRY_RUN" = true ]; then
    execute_sweep_path "$HOME/.claude/history.jsonl" "Claude Code History"
    execute_sweep_path "$HOME/.ollama/tmp" "Ollama Temp Files"
  else
    if [ -f ~/.claude/history.jsonl ]; then
      local history_tmp
      history_tmp=$(mktemp "$HOME/.claude/history.XXXXXX")
      if ! tail -n 1000 "$HOME/.claude/history.jsonl" > "$history_tmp"; then
        rm -f "$history_tmp"
        return 1
      fi
      mv "$history_tmp" "$HOME/.claude/history.jsonl"
      log_action "Truncated Claude Code history to last 1K lines"
    fi
    execute_sweep_path "$HOME/.ollama/tmp" "Cleared Ollama temp files"
  fi
}
