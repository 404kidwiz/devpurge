#!/usr/bin/env bash

sweep_ai() {
  echo -e "${YELLOW}[AI Tools] Sweeping historical bloat...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    execute_sweep_path "$HOME/.claude/history.jsonl" "Claude Code History"
    execute_sweep_path "$HOME/.ollama/tmp" "Ollama Temp Files"
  else
    if [ -f ~/.claude/history.jsonl ]; then
      tail -n 1000 ~/.claude/history.jsonl > ~/.claude/history_tmp.jsonl
      mv ~/.claude/history_tmp.jsonl ~/.claude/history.jsonl
      log_action "Truncated Claude Code history to last 1K lines"
    fi
    execute_sweep_path "$HOME/.ollama/tmp" "Cleared Ollama temp files"
  fi
}
