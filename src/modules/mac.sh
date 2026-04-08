#!/usr/bin/env bash

sweep_mac() {
  echo -e "${YELLOW}[macOS Apps] Sweeping platform caches...${NC}"
  
  if [ -d ~/Library/Caches/com.apple.dt.Xcode ]; then
    rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null
    echo "  - Cleared Xcode Derived Data / Caches"
  fi

  rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
  rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
  rm -rf ~/Library/Caches/com.apple.bird/* 2>/dev/null
  echo "  - Cleared Browser & iCloud temp caches"
}
