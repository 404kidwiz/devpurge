#!/usr/bin/env bash
# DESC: Git Repositories

sweep_git() {
  echo -e "${YELLOW}[Git] Deep compressing local repositories...${NC}"
  if [ "$DRY_RUN" = true ]; then
    log_dry "CMD" "Git GC --prune (Heavy op, sizes hidden)"
  else
    for search_dir in "$HOME/Desktop" "$HOME/Documents" "$HOME/Projects" "$HOME/Developer"; do
      if [ -d "$search_dir" ]; then
        find "$search_dir" -maxdepth 4 -name ".git" -type d 2>/dev/null | while read git_dir; do
          repo_path=$(dirname "$git_dir")
          cd "$repo_path" && git gc --prune=now >/dev/null 2>&1 || true
        done
      fi
    done
    log_action "Garbage collected all found .git histories"
  fi
}
