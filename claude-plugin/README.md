# DevPurge plugin for Claude Code

DevPurge finds the space that developer caches take up (npm, pnpm, pip, Cargo, Go, Xcode DerivedData,
Homebrew and more) and clears only caches that tools can rebuild. This plugin lets Claude run the free
DevPurge command-line tool for you, with a read-only scan first and your confirmation before anything
is deleted.

## Install

In Claude Code (2.1.275 or later):

    /plugin install devpurge --marketplace 404kidwiz/devpurge

## What it adds

- `/devpurge:scan`: read-only size report of developer caches and what is eligible for cleanup.
- `/devpurge:clean [module]`: preview with `--dry-run`, ask you, then clean. Defaults to the safe cache
  set (uv, node, lang, mac, system). AI history, Docker and Git cleanup run only if you name them.
- A `devpurge` skill so Claude suggests these when you ask why your disk is full.

The plugin has no hooks, no MCP server and no network calls of its own.

## Requirements

The DevPurge CLI 3.3.0 or later on your `PATH` (macOS or Linux). Install it from
https://github.com/404kidwiz/devpurge#install-the-cli.

## DevPurge Pro

A paid Mac app (planned) adds agent-leftover cleanup (stale worktrees and duplicate clones from parallel
coding agents) and a secret-leak guard for build output. The CLI and this plugin stay free.

## License

MIT. See LICENSE.
