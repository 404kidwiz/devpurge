# DevPurge ☢️

The cinematic, zero-bs cache sweeper for modern developers.

Commercial Mac cleaners (like CleanMyMac) are built for grandmas. They delete Safari history but completely ignore the hidden 40GBs of `pnpm` archives, `node-gyp` builds, and AI agent memory bloat dragging your system down.

**DevPurge** is built purely in Bash. No node runtimes required. Just raw, unadulterated cleanup.

## Features
- **Node Ecosystem:** Sweeps `npm`, `pnpm`, and node build temps.
- **AI Tooling:** Truncates runaway CLI agent logs (`claude`, `ollama`).
- **OS Targeting:** Natively targets `Homebrew` and Xcode DerivedData.
- **Set & Forget:** Installs as a native macOS `launchd` daemon to prune bloat every 7 days silently.

## Installation

Run the automated installer:
```bash
git clone https://github.com/404kidwiz/devpurge.git
cd devpurge
bash install.sh
```

## Usage

```bash
devpurge --all     # Sweep everything
devpurge --node    # Only sweep node/pnpm caches
devpurge --ai      # Only truncate AI logs
devpurge --install # Re-install background daemon
```

## Logs
When running in the background, DevPurge logs its purges to:
`~/.devpurge/logs/sweeper.log`

---
*Built for the 404kidwiz ecosystem.*
