# DevPurge project summary

Updated: 2026-09-21

## Current behavior

Bash CLI v3.3.0 with eleven modules. Startup resolves installed symlinks and reads
module descriptions correctly. `--all` is cache-only (uv, Node, languages, macOS,
system); AI history, Docker and Git require explicit selection. Xcode Archives
are excluded. Interactive mode starts with dry-run enabled. Invalid options and
JSON configuration fail before cleanup. Cleanup errors propagate; rescue mode
skips commands and uses collision-safe Trash directories for path targets.

Installation defaults to CLI only. Scheduling is explicit (`install.sh --schedule`),
requires `automated_sweep: true`, honors `interval_days`, and does not run immediately.
The old standalone-script updater was removed; reinstall from a reviewed checkout.

## Verification

- 37 isolated Python unittest cases passed on this Mac, including installed symlink,
  fake scheduler, dry-run, config, rescue, exclusions, and command failure behavior.
- ShellCheck passed for the executable, installer, helpers, and all modules.
- Bash syntax checks and `git diff --check` passed.
- Installed CLI help worked at `~/.local/bin/devpurge`.
- CI now includes the regression suite; remote CI has not been run for these changes.
- Graft refreshed; it indexes the Python GUI/report/tests and frontend JavaScript, not Bash.
- Linux scheduler has not been tested on a Linux host. No real scheduler enabled here.

## Graphical interface

`devpurge --gui` opens a local browser dashboard. `DevPurge.command` launches it
from Finder in this checkout. The GUI offers a disk summary, live scan, filtering,
search, selection, a review dialog, optional Trash mode, and per-item results.
It only cleans the three guarded manual groups; other locations are informational.
UI direction and scope are in DESIGN.md and PRODUCT.md.

The Python standard-library server binds to loopback on a random port. API calls
require an exact Host, same Origin, and a per-process session token. Assets are
local and routes fixed. Requests are serialized. Cleanup uses opaque scan-derived
IDs and a single-use preview expiring after five minutes. Ignored groups, rescue
configuration, and activity are rechecked before actions. Closing the terminal
stops the server; closing the tab alone does not.

Verification: 12 GUI controller/HTTP tests plus the 25 existing tests pass. Tests
cover temporary-fixture cleanup, unselected-file preservation, partial failures,
stale/expired plans, config changes, CSRF rejection and operation serialization.
Installed `devpurge --gui` launch and live browser scanning, filtering, selection,
preview and cancellation worked;
keyboard focus and 320/768/1024/1440px layouts were checked, with no browser errors observed.
Light/dark views were inspected; desktop browser emulation is not a physical-device
or screen-reader certification. No live cleanup was executed during GUI validation.
Independent read-only review found no actionable issues. Remote CI was not run.

## Scan and targeted cleanup

`--scan` and `--scan --json` inventory supported locations without cleanup. Each
entry reports size (or unknown), activity, eligibility, and the reason. Scans
cannot be combined with cleanup flags. Sizes are not promised reclaimable bytes.

Manual `--browsers`, `--installers`, and `--oldstores` groups are excluded from
`--all` and background jobs. The Python helper rechecks eligibility before each
action, retaining active/unknown owners, newer updates, symlinks, and mounted or
open targets. Electron cleanup removes only verified individual ZIPs. Older pnpm
stores use a matching already-installed native manager; unmatched stores remain.
An app starting between the final check and deletion remains a possible race.
Interactive selections now require Return to support double-digit module numbers.

Installed CLI scan completed successfully on this Mac. It retained BrowserClaw
and Granola activity, newer OpenCode updates, and the unmatched pnpm v3 store.
JSON report: `~/.devpurge/logs/latest-scan.json`. Automatic sweeping remains false;
no LaunchAgent is installed. No live cleanup was executed during feature verification.
Tests cover scan isolation, installed scanning, activity rechecks, native-store
matching, version checks, preservation of unrelated updater payloads, and rescue.

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

- ~/Library/Caches/electron
- ~/Library/Caches/org.swift.swiftpm/artifacts
- ~/Library/Caches/org.swift.swiftpm/repositories

Available disk space rose from 195,012,980 to 195,202,724 KiB
(185.3 MiB observed gain); available space was 186.16 GiB.
Further large reductions require selecting installed tooling, models, Docker
images, or project artifacts for removal, rather than repeating routine pruning.

## Native macOS Application & Commercial Distribution

Updated: 2026-09-21

### 1. Pure Native Swift Engine and App Bundle
A standalone native macOS application was built in `mac/Sources/DevPurge` using Swift 6
and SwiftUI. It produces a self-contained `DevPurge.app` (~1.3 MB) with zero Python or
third-party runtime dependencies:
- Direct Foundation and AppKit integration: volume capacity inspection via `statvfs`
  and `URLResourceKey`, process and open-file inventory via `NSWorkspace`, `ps`, and `lsof`.
- Native macOS Trash integration: `FileManager.default.trashItem` moves files to
  macOS Trash with Finder "Put Back" capability and sound.
- Design fidelity: Implements the limestone (`#f5f3ed`) and pine-green (`#275941`)
  palette in light mode, charcoal (`#202622`) in dark mode, matching DESIGN.md.
- Responsive layout: Adapts smoothly from 620px minimum width up to 4K displays.
  The storage metrics header automatically adapts from a 3-column divided desk into
  a compact stacked flow on narrow viewports.

### 2. Advanced Feature Set Implemented
- **macOS Menu Bar Companion Mode** (`MenuBarPopoverView.swift` / `MenuBarExtra`):
  Lives in the macOS menu bar with real-time volume free capacity, meter bar, scanned/eligible
  counts, a 1-click "Scan Now" button, and an "Open Dashboard" button.
- **Visual Storage Breakdown Bar** (`StorageBreakdownBarView.swift`):
  A proportional, color-coded stacked bar across categories (Browsers, Installers,
  Package Stores, Tooling & Review) with an itemized gigabyte legend.
- **Real-Time Streaming Scan** (`AsyncStream<Target>` in `TargetScanner.swift`):
  Targets stream into the UI list progressively as each directory is discovered and measured,
  eliminating wait times during scans.
- **Quick Look & Finder Integration** (`TargetRowView.swift`):
  Hover action buttons for "Reveal in Finder" and "Preview", plus right-click context menu
  options for Reveal, Copy Path, and Whitelisting.
- **Interactive Whitelisting ("Always Ignore in Config")**:
  Right-clicking an item writes its category directly into `~/.devpurge.json` via
  `DevPurgeConfig.swift`, marks the targets as `.ignored`, and deselects them.
- **APFS Snapshot Detection** (`APFSSnapshotInspector.swift`):
  Detects local Time Machine APFS snapshots via `tmutil listlocalsnapshots /` and displays
  an explanatory notice clarifying that deleted blocks may be retained by macOS until flushed.
- **Lemon Squeezy License Manager** (`LicenseManager.swift` & `LicenseActivationView.swift`):
  Securely stores and retrieves license keys in the macOS Keychain (`Security.framework`).
  Validates online via Lemon Squeezy API (`POST /v1/licenses/activate`). Includes instant
  offline developer activation for test keys prefixed with `DEVPURGE-DEV-` or `TEST-`.
- **Closed Beta Protection & Time-Bomb** (`BetaExpiryGuard.swift`):
  Enforces a 45-day beta trial window with a header status pill; upon expiration, locks
  destructive operations to prevent obsolete test builds from circulating indefinitely.

### 3. Packaging and Installer
- Built-in squircle application icon (`AppIcon.icns`, 1024x1024) generated via
  `scripts/generate_app_icon.py`.
- Automated build pipeline: `scripts/build_mac_app.sh` compiles the release binary,
  constructs `DevPurge.app`, registers LaunchServices, and applies local code signing.
- Automated DMG generator: `scripts/package_dmg.sh` produces `DevPurge-3.3.0.dmg` (~808 KB)
  with a drag-and-drop link to `/Applications`.
- `DevPurge.command` launches `DevPurge.app` directly from Finder if built.

### 4. Verification
- **Swift Unit Tests**: 7 test cases passed (`swift test`, 0.056s):
  - `testAPFSSnapshotInspectorParsing`
  - `testLicenseManagerDeveloperKey`
  - `testConfigDefaultsAndIgnore`
  - `testBetaExpiryGuard`
  - `testAppVersionComparison`
  - `testDiskSpace`
  - `testTargetModel`
- **Python Regression Suite**: All 37 test cases passed (`python3 -m unittest discover -s tests`).
- Executable runtime and Menu Bar companion tested on host Mac without errors.

---

## Next Steps & Launch Playbook

### Path 1: Project Hygiene & Sanity Check
1. **Git Cleanup**:
   Update `.gitignore` to exclude `mac/.build/`, `*.dmg`, `DevPurge.app/`, and `.DS_Store`
   so local build artifacts are never accidentally committed.
2. **Local Validation**:
   - Run `open DevPurge.app`.
   - Inspect the Menu Bar icon (`d/`) in the top macOS status bar.
   - Click the header **License** pill and activate with `DEVPURGE-DEV-TEST`.
   - Perform a scan and verify the visual breakdown bar and Finder reveal actions.

### Path 2: Closed Beta & Commercial Sales Setup
1. **Lemon Squeezy / Gumroad Store Setup**:
   - Create a product: *DevPurge Lifetime License* ($19–$29).
   - Enable **License Keys** under product settings.
   - Point the buy link in `LicenseActivationView.swift` to the live store URL.
2. **Apple Developer ID & Notarization**:
   - Enroll in the Apple Developer Program ($99/year).
   - Obtain a `Developer ID Application` certificate.
   - Add `xcrun notarytool` submission into `scripts/package_dmg.sh` to allow
     Gatekeeper-free distribution of `DevPurge-3.3.0.dmg`.

### Path 3: Marketing & Distribution Assets
1. **Landing Page**:
   Create a single-page landing site matching DESIGN.md (warm limestone and pine green)
   featuring key value propositions, a demo GIF/video, and checkout integration.
2. **Release Channels**:
   - Distribute the DMG privately to initial beta testers.
   - Prepare a Homebrew Cask formula (`brew install --cask devpurge`) for easy developer installs.

### Path 4: Future Roadmap Enhancements
1. **System Threshold Notifications**:
   Add background storage monitoring that notifies the user if caches exceed 20 GB.
2. **Deep Module Expansion**:
   Add support for Gradle (`~/.gradle/caches`), Android SDK caches, and HuggingFace models.
