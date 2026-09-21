#!/usr/bin/env bash
set -eo pipefail
# DESC: Rust/Python/Go

sweep_lang() {
  echo -e "${YELLOW}[Languages] Sweeping Rust/Python compiled bloat...${NC}"
  execute_sweep_cmd "pip3" "Purged Python pip cache" pip3 cache purge
  execute_sweep_path "$HOME/.cargo/registry/cache" "Cleared Rust Cargo registry cache"
  execute_sweep_path "$HOME/.rustup/tmp" "Cleared Rustup temp downloads"
  execute_sweep_cmd "go" "Cleared Go build cache" go clean -cache
  execute_sweep_cmd "go" "Cleared Go module cache" go clean -modcache
}
