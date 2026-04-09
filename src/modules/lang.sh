#!/usr/bin/env bash
# DESC: Rust/Python/Go

sweep_lang() {
  echo -e "${YELLOW}[Languages] Sweeping Rust/Python compiled bloat...${NC}"
  execute_sweep_cmd "pip" "pip cache purge" "Purged Python pip cache"
  execute_sweep_path "$HOME/.cargo/registry/cache" "Cleared Rust Cargo registry cache"
  execute_sweep_path "$HOME/.rustup/tmp" "Cleared Rustup temp downloads"
  execute_sweep_cmd "go" "go clean -cache" "Cleared Go build cache"
  execute_sweep_cmd "go" "go clean -modcache" "Cleared Go module cache"
}
