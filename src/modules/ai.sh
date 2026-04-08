#!/usr/bin/env bash

sweep_ai() {
  echo -e "${YELLOW}[AI Tools] Sweeping historical bloat...${NC}"
  
  if [ -f ~/.claude/history.jsonl ]; then
    tail -n 1000 ~/.claude/history.jsonl > ~/.claude/history_tmp.jsonl
    mv ~/.claude/history_tmp.jsonl ~/.claude/history.jsonl
    echo "  - Truncated Claude Code history to last 1K lines"
  fi

  rm -rf ~/.ollama/tmp/* 2>/dev/null
  echo "  - Cleared Ollama temp files"
}
