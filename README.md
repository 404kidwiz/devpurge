# DevPurge

A Bash CLI for targeted developer-cache cleanup on macOS and Linux.
Python 3 is required when reading the optional JSON configuration and by the installer.

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

## Modules

| Flag | Targets |
| --- | --- |
| `--uv` | Unreachable uv cache entries via `uv cache prune` |
| `--node` | npm cache, active pnpm store pruning, node-gyp cache |
| `--lang` | pip3, Cargo registry download cache, rustup temporary files, Go build/module caches |
| `--mac` | Xcode DerivedData, simulator caches, configured Safari/Chrome cache paths; **never Xcode Archives** |
| `--system` | Homebrew cleanup; noninteractive APT cache cleanup on Linux |
| `--all` | Only `uv`, `node`, `lang`, `mac`, and `system` |
| `--ai` | **Explicit only:** truncates Claude history to 1,000 lines and deletes Ollama temporary files |
| `--docker` | **Explicit only:** `docker system prune -af --volumes`; can delete container data |
| `--git` | **Explicit only:** Git GC with default retention in repositories discovered under Desktop, Documents, Projects, Developer |

Close relevant builds/apps before clearing their caches. Future builds and installs
may need downloads. pnpm pruning only targets the active store, not older versions.
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
