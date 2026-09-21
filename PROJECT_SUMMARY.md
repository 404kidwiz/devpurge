# DevPurge project summary

Updated: 2026-09-20

## Current behavior

Bash CLI v3.1.0 with eight modules. Startup resolves installed symlinks and reads
module descriptions correctly. `--all` is cache-only (uv, Node, languages, macOS,
system); AI history, Docker and Git require explicit selection. Xcode Archives
are excluded. Interactive mode starts with dry-run enabled. Invalid options and
JSON configuration fail before cleanup. Cleanup errors propagate; rescue mode
skips commands and uses collision-safe Trash directories for path targets.

Installation defaults to CLI only. Scheduling is explicit (`install.sh --schedule`),
requires `automated_sweep: true`, honors `interval_days`, and does not run immediately.
The old standalone-script updater was removed; reinstall from a reviewed checkout.

## Verification

- 12 isolated Python unittest cases passed on this Mac, including installed symlink,
  fake scheduler, dry-run, config, rescue, exclusions, and command failure behavior.
- ShellCheck passed for the executable, installer, helpers, and all modules.
- Bash syntax checks and `git diff --check` passed.
- Installed CLI help worked at `~/.local/bin/devpurge`.
- CI now includes the regression suite; remote CI has not been run for these changes.
- Graft refreshed; it currently indexes the Python tests, not the Bash implementation.
- Linux scheduler has not been tested on a Linux host. No real scheduler enabled here.

## Local cleanup evidence

Node and Homebrew modules executed successfully. Xcode DerivedData was removed
separately through the path helper after checking that Xcode/xcodebuild were absent;
browser caches were not swept.

- npm `_cacache`, node-gyp cache, and DerivedData: confirmed absent afterward.
- pnpm active v11 store: 1,704,256 KiB before, 6,976 KiB after.
- Homebrew reported approximately 77.9 MB reclaimed.
- Data-volume available space: 175,045,840 KiB before, 183,083,316 KiB after;
  observed net gain 8,037,476 KiB (7.67 GiB), subject to concurrent host activity.
- Execution log: `~/.devpurge/logs/manual-cache-cleanup-2026-09-20.log`.

uv pruning initially waited for a cache lock held by six pre-existing uv processes.
Following explicit user authorization, ten current Blender/Penpot MCP uv launchers
(including four additional instances started since the first inspection) were
terminated with SIGTERM. No Blender/Penpot MCP processes remained in the follow-up
process check. Their configuration was not disabled; a future app session may
launch them again.

`devpurge --uv` then completed without a force override, reporting 479,427 files
(9.9 GiB) removed. The remaining uv cache measured 9,237,252 KiB (8.81 GiB).
Available disk space increased from 183,717,908 to 186,284,204 KiB during this
second pass: an observed net gain of 2.45 GiB, with 177.65 GiB available afterward.
Reported deleted-file sizes are not equivalent to physical disk space recovered
(shared storage, snapshots, and concurrent activity can affect the difference).
No cache-lock holders remained at the final check.

Older pnpm stores, Docker storage, Claude history, Git repositories, Xcode Archives,
Playwright browsers, and app/browser caches were not cleaned in this pass.

## Additional cleanup pass

On the user's request to continue, the language module cleared pip, Cargo
registry downloads, rustup temporary downloads, and Go build/module caches.
No active Go/Rust/pip jobs were found before execution.

The installed pnpm 10.33.0 was used to prune its own v10 store, reporting
150,621 files and 2,827 packages removed. The store decreased from 4,880,316 KiB
to 4 KiB. The v3 store (2,801,892 KiB) was retained: an existing OrderFlow
project's node_modules metadata still points to it.

Docker Desktop was temporarily started for inspection. Its restart policies
brought 19 existing containers online. Images, containers, and volumes were
preserved. Builder cache older than 168 hours was pruned, reporting only
10.12 MB reclaimed. Docker Desktop was then stopped and its engine confirmed
unreachable, restoring its original stopped state. Docker still reports about
12.6 GB of reclaimable images, but these include local project images and were
not removed.

Available disk space for this pass rose from 186,372,000 to 189,248,496 KiB
(2.74 GiB net); current availability is
180.48 GiB. Host activity and shared files affect net disk changes.
Execution output remains in the same manual cleanup log.

## Stale installers and inactive browser cache

Another user-authorized cleanup pass removed inactive Comet HTTP/code caches,
three old ChatGPT installer staging directories (versions 26.903.61454,
26.908.40834, and 26.915.31029; installed version 26.915.31945), a BrowserOS neo
0.50.5 installer matching the installed version, and ZCode 3.11.2 updater downloads
matching the installed version. No open files, running updater, or mounted cache
installer image was found for the deleted targets. Targeted apps were confirmed
present after cleanup; no browser profiles were removed.

BrowserClaw's cache was retained because BrowserOS neo actively uses it. OpenCode's
pending 1.18.31 update was retained because the installed app is 1.18.23.
Granola's running-app updater cache, models, installed runtimes, and Playwright
browsers were also retained.

Available disk space increased from 189,014,724 to 194,938,412 KiB, an observed
net gain of 5.65 GiB, reaching 185.91 GiB.
Evidence: ~/.devpurge/logs/installer-cleanup-result.json and the shared cleanup log.

## Final download-cache review

All installed Playwright browser revisions were referenced by existing package
registrations and were retained. Browser/MCP profiles, model files, and installed
runtimes were retained. The final cache pass removed these targets after checking
for active Swift/Xcode processes and open files:

- /Users/you/Library/Caches/electron
- /Users/you/Library/Caches/org.swift.swiftpm/artifacts
- /Users/you/Library/Caches/org.swift.swiftpm/repositories

Available disk space rose from 195,012,980 to 195,202,724 KiB
(185.3 MiB observed gain); available space was 186.16 GiB.
Further large reductions require selecting installed tooling, models, Docker
images, or project artifacts for removal, rather than repeating routine pruning.
