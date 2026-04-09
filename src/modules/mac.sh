#!/usr/bin/env bash
# DESC: macOS Apps

sweep_mac() {
  echo -e "${YELLOW}[macOS Apps] Sweeping platform caches...${NC}"
  execute_sweep_path "$HOME/Library/Developer/Xcode/DerivedData" "Cleared Xcode Derived Data"
  execute_sweep_path "$HOME/Library/Developer/Xcode/Archives" "Cleared Xcode Archives"
  execute_sweep_path "$HOME/Library/Developer/CoreSimulator/Caches" "Cleared iOS Simulator Caches"
  execute_sweep_path "$HOME/Library/Caches/com.apple.Safari" "Cleared Safari Cache"
  execute_sweep_path "$HOME/Library/Caches/Google/Chrome/Default/Cache" "Cleared Chrome Cache"
}
