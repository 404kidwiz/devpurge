# DevPurge

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
| `--docker` | **Explicit only:** `docker system prune -af --volumes`; can delete container data |
| `--git` | **Explicit only:** Git GC with default retention in repositories discovered under Desktop, Documents, Projects, Developer |

Close relevant builds/apps before clearing their caches. Future builds and installs
may need downloads. `--node` prunes only the active pnpm store; `--oldstores` handles supported older stores.
uv pruning respects its cache lock and can wait when other uv processes are active;
do not force it while those processes use the cache. AI history truncation also
requires closing Claude sessions first.

Cleanup stops and exits nonzero on command failures. Missing tools and rescue-mode
skips are explicitly reported. Earlier successful cleanup is not rolled back.

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
