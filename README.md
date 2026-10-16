# DevPurge

**Reclaim gigabytes of developer caches without deleting anything you'll miss.**

Scan first, review every path, and DevPurge skips anything that's running or open.
It covers uv, npm/pnpm, pip, Cargo, Go, Xcode, Homebrew and stale app-updater
downloads, and it never touches your home folders, `.git` directories, Keychains
or Xcode Archives. No network, no telemetry.

- **DevPurge CLI + local GUI:** free and open source (MIT).
- **DevPurge for Mac:** native menu-bar app. Scanning is free and includes 3 free
  cleanups; then **$19 one-time** for 2 Macs ([details](#devpurge-for-mac)).

```bash
git clone https://github.com/404kidwiz/devpurge && cd devpurge
bash bin/devpurge --scan          # read-only inventory
bash bin/devpurge --dry-run --all # preview
bash bin/devpurge --all           # clean caches
```

A Bash CLI for targeted developer-cache cleanup on macOS and Linux.
Python 3 is required for scanning, targeted cleanup, JSON configuration, and installation.

## Graphical interface

```bash
devpurge --gui
# Or from this checkout:
bash bin/devpurge --gui
```

The dashboard opens in your default browser. Keep the terminal open; press Ctrl+C
there to stop the server. If `devpurge` is not on PATH, use
`~/.local/bin/devpurge --gui`. You can also double-click `DevPurge.command` in this
checkout from Finder.

1. Click **Scan storage**. Scanning changes no files.
2. Filter by **Eligible**, inspect the paths and reasons, and select individual locations.
3. Optionally choose **Move files to Trash**. This does not free space until you
   empty Trash yourself; native pnpm pruning cannot use this mode.
4. Click **Review selection**, check the exact paths and mode, then confirm.
5. Read the per-item results and scan again for current sizes.

The GUI cleans only eligible browser caches, identified old installers, and supported
older pnpm stores. Other developer caches are visible for review but remain CLI-only.
It honors ignored groups and enforced rescue mode, rechecks activity before each
cleanup, and requires a new scan after execution. Previews expire after five minutes.

The server binds only to `127.0.0.1` on a random port, requires a session token and
same-origin requests for API operations, and serves no external assets. It creates
no scheduled jobs. Closing the browser tab alone does not stop the server.
Python 3.9 or newer is required for the GUI; no additional Python packages are needed.

## Run from this checkout

```bash
bash bin/devpurge --dry-run --uv --node --system
bash bin/devpurge --uv --node --system
```

No arguments opens the interactive menu **in dry-run mode**. Toggle dry-run off
only when ready to execute. `--dry-run` previews paths and commands; displayed
path sizes are not guaranteed reclaimed space (hard links, APFS snapshots, and
partially pruned stores affect actual savings). Command targets report pending
operations; Homebrew and Docker use their own read-only reports.

## Scan first

```bash
devpurge --scan
devpurge --scan --json
devpurge --dry-run --installers --browsers --oldstores
```

Scanning reports supported cache locations, stored size, activity, and eligibility;
it never cleans anything and cannot be combined with cleanup flags. It is a targeted
inventory, not a full-disk duplicate or large-file scanner. Unknown sizes stay unknown;
reported sizes are not guaranteed savings.

The three manual groups below recheck eligibility immediately before each action.
Process/open-file inspection requires `ps` and `lsof`; macOS also uses `hdiutil`.
Failed activity checks retain targets. Browser and installer detection supports
known macOS app/cache layouts. Pending newer updates, unidentified versions/apps,
symlinks, running owners, open files, and mounted images are retained. Close relevant
apps before cleanup; an app starting during cleanup is still a possible race.

After reviewing the preview, omit `--dry-run` to execute the selected groups.
Rescue mode moves supported files to Trash, but skips native pnpm pruning.
These groups are excluded from `--all` and scheduled sweeps.

## Modules

| Flag | Targets |
| --- | --- |
| `--uv` | Unreachable uv cache entries via `uv cache prune` |
| `--node` | npm cache, active pnpm store pruning, node-gyp cache |
| `--lang` | pip3, Cargo registry download cache, rustup temporary files, Go build/module caches |
| `--mac` | Xcode DerivedData, simulator caches, configured Safari/Chrome cache paths; **never Xcode Archives** |
| `--system` | Homebrew cleanup; noninteractive APT cache cleanup on Linux |
| `--browsers` | Inactive Comet, BrowserClaw, BrowserOS, and Chrome HTTP/code cache paths; preserves profiles |
| `--installers` | Identified Sparkle staging directories and individual Electron updater ZIPs at least one day old, with versions no newer than the installed app |
| `--oldstores` | Older pnpm stores, using an already-installed matching pnpm version for native pruning; unmatched stores retained |
| `--all` | Only `uv`, `node`, `lang`, `mac`, and `system` |
| `--ai` | **Explicit only:** truncates Claude history to 1,000 lines and deletes Ollama temporary files |
| `--docker` | **Explicit only:** `docker system prune -af --volumes`; can delete container data. Asks you to type `prune docker` (or pass `--yes`) |
| `--git` | **Explicit only:** Git GC with default retention in repositories discovered under Desktop, Documents, Projects, Developer |
| `--agents` | **Pro, explicit only:** agent leftovers. Reports stale worktrees, duplicate clones and OpenCode caches from parallel Claude Code, Codex, OpenCode, Kilo and Clawdbot runs. See below |

Close relevant builds/apps before clearing their caches. Future builds and installs
may need downloads. `--node` prunes only the active pnpm store; `--oldstores` handles supported older stores.
uv pruning respects its cache lock and can wait when other uv processes are active;
do not force it while those processes use the cache. AI history truncation also
requires closing Claude sessions first.

Cleanup stops and exits nonzero on command failures. Missing tools and rescue-mode
skips are explicitly reported. Earlier successful cleanup is not rolled back.

## Agent leftovers (Pro)

`devpurge --agents --dry-run` (or `python3 src/agents.py`) reports, and never changes:

- worktrees under `.claude/worktrees`, `.codex/worktrees`, `.kilo/worktrees`, `.clawdbot/worktrees`
  and OpenCode folders, for every repository directly under `~/Desktop/404 Projects`, `~/Projects`,
  `~/Developer`, `~/code`, `~/src`, `~/dev` and `~/repos` (override with `DEVPURGE_AGENT_ROOTS`,
  colon separated, relative to home);
- `~/.codex/worktrees` folders no repository still lists;
- clones of the same `origin` remote;
- OpenCode logs, tool output, snapshots and repo copies.

Without `--dry-run`, after typing `remove agent leftovers` (or `--yes`) it only:

- runs `git worktree remove` (never `--force`) and then `git worktree prune` on agent-made worktrees
  idle for 7+ days that have no uncommitted or untracked files, no stash and no unpushed commits
  (or, without an upstream, a HEAD that is on a remote branch), and no gitignored secrets or local
  config (`.env*`, `*.pem`, `*.key`, `*.p12`, `credentials*`, `secrets*`, `*.sqlite`, `*.db`, `*.local`).
  plus `.npmrc`, `.pypirc`, `.netrc`, SSH keys, `*.tfstate*` and `service-account*.json`, found anywhere in
  ignored folders, including `node_modules`, `build` and `dist`; other ignored files don't block;
- prunes records of worktrees whose folder is already gone;
- deletes OpenCode `log/` and `tool-output/`. `opencode.db`, `auth.json` and snapshots are never touched.

Worktrees not made by a known agent, locked worktrees and unregistered folders are report only.
A clone with any linked worktree is report only. A duplicate clone is deletable only when it is clean, fully pushed, has no stash and has the same
HEAD as a clean clone that is kept; each one needs its folder name typed at an interactive prompt,
and `--yes` never deletes clones.

This is a Pro feature. The CLI does not check a license yet. In the Mac app the plan is the same
split as cleanup today: the agent scan is free, and the remove actions call `LicenseManager`
and are unlocked by a license or count against the trial.

## Secret-leak guard (Pro)

The leak guard matches file names and paths only. It never opens, reads or deletes a file.
It uses the same secret pattern list as agent leftovers (`.env*`, keys, `.npmrc`, `.netrc`,
SSH keys, Terraform state, service account JSON, local databases and more). `.env.example`,
`.env.sample` and `.env.template` are allowed.

- `devpurge --leak-check [PATH]` reports secret-looking files inside `dist/`, `build/`, `out/`,
  `.vercel/`, `.netlify/`, `.next/`, `public/`, `.output/`, `.wrangler/` and `functions/` anywhere
  under PATH (skipping `.git` and `node_modules`), and exits 1 if it finds any.
- `devpurge --leak-guard install-git-hook [REPO]` writes `.git/hooks/pre-commit`, which blocks a
  commit that stages a secret-looking file anywhere. It refuses to overwrite a hook it didn't write.
  `git commit --no-verify` skips it once.
- `devpurge --leak-guard print-config claude|codex|cursor` prints a pre-deploy hook config and writes
  nothing. Paste it in yourself. The hook runs `leak_guard.py pre-deploy`, which reads the hook's JSON
  on stdin and, for `wrangler deploy`, `wrangler pages deploy`, `vercel`, `netlify deploy` or
  `firebase deploy`, exits 2 (block) if the output folders hold secret-looking files.
  - Claude Code: `PreToolUse` on `Bash` in `.claude/settings.json`
    ([hooks reference](https://code.claude.com/docs/en/hooks)).
  - Codex: `PreToolUse` with matcher `^Bash$` in `~/.codex/hooks.json` or the repo's `.codex/hooks.json`
    ([Codex hooks](https://developers.openai.com/codex/hooks)).
  - Cursor: `beforeShellExecution` in `.cursor/hooks.json`, with `failClosed: true` so a crashed
    hook blocks ([Cursor hooks](https://cursor.com/docs/hooks)).

This is a Pro feature. The CLI does not check a license yet; in the Mac app the plan is that the
report is free and the hook installers are licensed.

## Install the CLI

```bash
bash install.sh
# If ~/.local/bin is on PATH:
devpurge --help
```

Installation **does not create or enable a background job**. It preserves existing
configuration and backs up an existing installation. An already-enabled scheduler
is not disabled by reinstalling. The installed symlink points to
`~/.local/lib/devpurge/bin/devpurge`.

The old `--update` downloader has been removed: update your reviewed checkout and
rerun `bash install.sh` instead.

## Configuration and optional scheduling

`~/.devpurge.json` defaults to:

```json
{
  "automated_sweep": false,
  "interval_days": 7,
  "rescue_mode": false,
  "ignore": []
}
```

Invalid config stops execution. `ignore` lists module names such as `node` or `mac`.
In rescue mode, path targets are moved to unique folders in Trash; commands and
AI/Docker/Git cleanup are skipped because they cannot be rescued. Moving files to
Trash does not free disk space until Trash is emptied.

To opt into scheduling, set `automated_sweep` to `true`, choose `interval_days`
(1–365), then run:

```bash
bash install.sh --schedule
```

The macOS LaunchAgent or Linux user timer runs only `--background --all`, with no
immediate sweep. Every run checks `automated_sweep`; setting it to false disables
cleanup without removing the job. Rerun `--schedule` after changing the interval.
`devpurge --uninstall` removes the background job, not the CLI or configuration.

On macOS, scheduled output is in `~/.devpurge/logs/sweeper.log` and
`sweeper-error.log`; Linux uses the systemd user journal. Logs are not rotated.

## Verification

```bash
python3 -m unittest discover -s tests -v
shellcheck bin/devpurge install.sh src/config.sh src/utils.sh src/modules/*.sh
```

Tests use temporary home directories and fake package managers: no real caches
or scheduler jobs are touched. Linux scheduling still requires platform testing.

## Safety guarantees

Every deletion, whether from the CLI, GUI or Mac app, is checked against a hard denylist:
`/`, your home folder and its parents, `~/Desktop`, `~/Documents`, `~/Downloads`,
`~/Projects`, `~/Developer`, `~/Library`, anything inside a `.git` directory,
Keychains and Xcode Archives. Symlinks are resolved first. Refused paths are
reported and stop the run. See `src/safety.py` and `tests/test_safety.py`.

## DevPurge for Mac

The native SwiftUI app (`mac/`) adds a menu-bar companion, streaming scans,
Quick Look, Trash with Finder "Put Back", and a storage breakdown.

- **Free:** unlimited scans and reports, plus 3 cleanups.
- **$19 one-time** (launch week $12): unlimited cleanup on up to 2 Macs.
  Sold through Lemon Squeezy, which is the merchant of record, with a 14-day refund window.
- Licensing contacts Lemon Squeezy only to activate, validate (at most daily) or
  deactivate. It works offline for 14 days, and network errors never revoke a license.

## License

The CLI, GUI, tests and scripts are under the [MIT License](LICENSE). The Mac app
in `mac/` is proprietary; see [mac/LICENSE-EULA.md](mac/LICENSE-EULA.md).
Release steps are in [docs/RELEASING.md](docs/RELEASING.md).
