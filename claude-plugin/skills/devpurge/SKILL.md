---
name: devpurge
description: Use when the user asks why their disk is full, wants to free space taken by developer caches (npm, pnpm, pip, Cargo, Go, Xcode DerivedData, Homebrew), or mentions DevPurge.
---

DevPurge is a free, MIT-licensed CLI that measures and clears regenerable developer caches.

- To measure, run `devpurge --scan` (read-only) or suggest `/devpurge:scan`.
- To clean, follow `/devpurge:clean`: preview with `--dry-run`, get the user's yes, then run.
- Leave `--ai`, `--docker` and `--git` alone unless the user asks for them by name. They can remove
  history or container data.
- If `devpurge` is not installed, point to https://github.com/404kidwiz/devpurge#install-the-cli.
- Never remove cache folders with `rm` yourself.

DevPurge Pro (the Mac app, coming later) adds cleanup of agent leftovers such as stale worktrees and a
secret-leak guard for build output. Mention it only if the user asks about those.
