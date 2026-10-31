# DevPurge project summary

Updated: 2026-10-31

## Installer release 3.3.2 (2026-10-31)

- [Public installer and checksum](https://github.com/404kidwiz/devpurge-releases/releases/tag/v3.3.2): Apple Silicon, macOS 14+, build 3; 2,132,367 bytes.
- SHA-256: `34acdd0cb96aaf4f9dde5fc1fccf64ecf2badc7f430029363e093d6b12dcea0d`.
- Mounted DMG integrity, strict ad-hoc signature, embedded icon, version and Applications shortcut passed. No development-license bypass in the release binary.
- Native suite: 30 passed, one optional snapshot-export test skipped, no failures. Native launch was not re-certified; Apple notarization remains pending.
- All four website download paths now target v3.3.2, including the mobile copy-link fallback. Download/copy-link and keyboard regression checks pass, including real clipboard bytes. v3.3.1 remains available for rollback.

Full release notes: `docs/releases/3.3.2.md`.

## Mac app icon refresh (2026-10-31)

Replaced the limestone `d/` icon with a Zine paper-cut D using the app's licensed
Lilita One face and pink, lime, cobalt and paper colors. The deterministic source
is `scripts/generate_app_icon.py`; the 1024px master is
`mac/Resources/AppIcon.png`, and `AppIcon.icns` contains all ten standard
representations from 16px through 1024px. Existing builds consume this ICNS.

Applied to both local app copies (repository and Desktop) without replacing their
executables with a different version. Both were already ad-hoc signed and were
re-signed after the resource change; strict signature verification passed.
LaunchServices was refreshed, and macOS's resolved Desktop-app icon was inspected
and matches the new artwork. Light/dark size checks and deterministic ICNS
round-trip checks passed. Existing app copies were backed up before modification.
Published v3.3.2 (build 3) with this icon to the public download repository.
The uploaded installer and anonymous public download match the verified local
artifact and published checksum. This is an ad-hoc signed release; Apple
notarization remains pending. Details: `docs/mac-icon.md`.

## Current behavior

Bash CLI v3.3.2 with eleven modules. Startup resolves installed symlinks and reads
module descriptions correctly. `--all` is cache-only (uv, Node, languages, macOS,
system); AI tool bloat, Docker and Git require explicit selection. `--ai` reports
Codex, Claude Code and Cursor cache sizes and deletes only regenerable caches.
Xcode Archives are excluded. Interactive mode starts with dry-run enabled. Invalid options and
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

## 2026-10-21 — Launch fixes from first real-Mac test run (merged in #8, `6a24feb`)
A real cleanup on a 94%-full MacBook Pro freed 9.7 GB but exposed two bugs:
1. **Any running updater blocked every target.** Tailscale's Sparkle `Autoupdate`
   matched a global substring check, so `--scan` marked npm, pnpm, HuggingFace and
   Docker paths "in-use". Now only bundle-owned targets check for an updater, and
   only one whose command line names that bundle id or `.app` path
   (`src/report.py` `updater_running`, `ProcessInspector.updaterRunning`).
2. **One failed module aborted the whole sweep.** A uv cache-lock timeout stopped
   `--all` before node/lang/mac/system ran. Each module now runs in its own errexit
   subshell (`bin/devpurge` `run_if_allowed`): a failed step still stops that module,
   the rest run, and the CLI exits 1 with `[!] Failed: <modules>`.
Regression tests: `test_only_the_owning_apps_updater_blocks_cleanup`,
`test_failed_module_does_not_abort_remaining_modules`,
`test_refused_module_reports_failure_after_later_modules_run`,
`testOnlyOwningAppsUpdaterBlocksCleanup` (Swift). Python 55/55, Swift 22/22.

## 2026-10-21 — Units, 3.3.1 and site claims (merged in #9 and #10)
- **Decimal GB everywhere (#9, `f4ed7a8`).** The web GUI printed GiB and the Mac app GB
  for the same disk. `src/units.py`, `src/web/units.js` and `ByteFormat.swift` now share
  16 cases in `tests/units_cases.json`; a guard test rejects GiB/MiB/`du -sh`.
- **3.3.1, build 2 (#10, `2547d66`).** Version set in `bin/devpurge`, the app plist,
  `package_dmg.sh` and `release_mac.sh`; `tests/test_version.py` keeps them equal.
- **On-disk sizes for `--ai`/`--agents` (#10).** `ai_bloat.size_of` sums allocated blocks,
  counts hard links once and never follows symlinks (sparse VM disks reported up to 15x
  their real use). Matches `du -sk` on real Codex, Claude and Cursor folders.
- Tests on `main`: Python 105, Swift 24. Release build on the signing Mac reads 3.3.1 (2).
- **Release blockers (owner):** Developer ID Application certificate, `devpurge-notary`
  keychain profile, Lemon Squeezy IDs in `LicenseConfig.swift` (still 0), then
  `scripts/release_mac.sh`.
- **Landing site** (`devpurge-site`, now a local Git repo): failure-behavior and denylist
  copy updated for #8; Mac app vs CLI row says AI/Agents are "not in the Mac app yet";
  `github-cli` stays a launch placeholder while this repo is private.
- **Next:** UI refresh (4 tool tabs: Clean, AI tools, Agents, Analyze; grouped inventory)
  and Analyze v3.4 (disk treemap). Plans, mockups and the full session summary are in the
  git-ignored `launch-test-2026-10-21/` folder.

## Premium landing concept round

Three additional standalone five-section motion prototypes live in `design-directions/premium/`, with comparison gallery `index.html`, reference captures under `screens/`, brief and skill applications in `BRIEF.md`, and browser results in `verification.json`. These are illustrative marketing prototypes, not connected to cleanup or checkout. Earlier concepts remain under `design-directions/`.

### DevPurge studio art-direction pass

`design-directions/studio/index.html` presents three additional asset-led five-section concepts. Custom built-in generated imagery, self-contained HTML pages, desktop/mobile captures, interactive previews and reduced-motion verification included. Prior concepts preserved.

### Three further cinematic explorations

`design-directions/explorations/index.html`: After Hours, Field Atlas, and Launch Window. Each has five key sections, custom generated imagery, interactive sample review, desktop/mobile screenshots, pause and reduced-motion support. Prior rounds remain intact.

### Arcade design directions

`design-directions/arcade/index.html` presents Puzzle Grid (replacing racing), Mission Control, and Arcade Studio. Each has five sections, original generated art, interactive sample review and responsive captures. Prior rounds preserved.

### Zine landing page (site/)

Chosen direction: Zine (risograph collage), from the GPT-image mockups in `design-directions/gpt-image/` (Index, Fathom, Zine). `site/index.html` is a standalone static page with no build step: hero, how it works, interactive sample review, safety tags, receipt pricing. Fonts are self-hosted OFL (Rubik, Lilita One, Courier Prime, Anton, Caveat). Illustrations were generated with Codex `image_gen` and saved as WebP (originals in `design-directions/gpt-image/zine-assets-src/`). Motion includes scroll reveals, parallax, a hide-on-scroll nav, a receipt that prints in, a sticker count-up, and hover states throughout. Reduced motion is respected. The review board toggles and recalculates the total; "Move to Trash" is demo-only and says so. Verified in Chromium at 390/820/1280/1586/1920 by two QA-agent passes; screenshots are in `design-directions/zine-build-qa/`. Not yet tested in Safari, Firefox or on real devices. Not deployed. The purchase link points to the README section until a Lemon Squeezy URL is confirmed.

Round 2 of `site/` (Zine): added hero CTA, FAQ, refund/footer links, favicon and OG image, crumple/grunge/tape/collage textures (Codex image generation), no-JS fallback, hover-only-on-hover-devices, low-core mode, 0 GB state, phone nav. Verified: smoke test 68/69 across Chromium, WebKit and Firefox (the miss is Safari's default Tab behaviour); independent QA agent pass, with its P1/P2 defects then fixed and re-smoked. Open: GitHub repo is private so all page links 404 publicly; no checkout URL; `og:image` needs an absolute URL once the domain is known; no real app screenshot or social proof; not tested on real devices or with a screen reader.

### Mac app: Zine restyle with 4 palettes

The SwiftUI app (`mac/`) now matches the Zine site: sticky-note metrics, paper inventory rows with SAFE / IN USE stamps, a receipt-style review sheet, a "Space back." result card and a matching menu-bar popover. Fonts are Lilita One and Courier Prime (OFL, `mac/Resources/Fonts`, copied into the app bundle by `scripts/build_mac_app.sh`). Four palettes, picked from the Palette menu, Settings (Cmd-,) or the popover swatches, saved per Mac: Zine and Citrus (light), Blacklight and Ember (dark). `Theme.swift` holds semantic tokens; views never use raw colours. `PaletteSnapshotTests` checks WCAG contrast for every palette and, with `DEVPURGE_SNAPSHOT_DIR` set, writes screenshots of each screen per palette. The cleanup result now reports Trash moves ("in the Trash, empty to free") separately from measured freed space. Screenshots are in `design-directions/zine-app-build/`. Not yet checked by hand in the running app.

## Prioritized launch follow-ups (2026-10-30)

Status below distinguishes completed work from remaining acceptance. Lemon Squeezy
activation remains a separate dependency; keep license purchases disabled until
approval and live checkout/license verification. The advisory conversion-readiness
assessment was 76/100 (moderate), based on page review and existing verification,
not measured conversion data. Prioritize trust and download clarity over another
visual redesign.

1. [ ] **Developer ID signing and Apple notarization — first priority.** Confirm
   Apple Developer enrollment and availability of a Developer ID Application
   certificate, then use `scripts/release_mac.sh` to sign, notarize and staple the
   release. Verify a fresh browser download opens normally on another Mac with
   Gatekeeper enabled. Replace the current not-notarized FAQ guidance only after
   the distributed release passes this check. This is independent of store approval.
2. [x] **Clarify the download offer near the primary action.** Hero now says
   "Download for Mac", followed immediately by "macOS 14+ · Unlimited scans · 3 free
   cleanups". App bundle minimum is 14.0; production license configuration allows
   three free cleanups and scanning does not consume them. All four palettes and
   eight viewport sizes passed layout checks; laptop remains beside the headline.
3. [x] **Add a mobile-to-Mac handoff.** Narrow screens and coarse-pointer devices
   get "Copy download link" while the direct Mac download stays available. Copy
   succeeds through the Clipboard API or a checked legacy fallback; otherwise a
   selected, labelled URL field remains visible for manual copying. A polite live
   region reports the result. Real browser clipboard bytes, denied/throwing API
   cases, keyboard use and no-JS fallback passed. The link matches the uploaded
   v3.3.1 DMG in the public GitHub release.
4. [ ] **Physical-device and accessibility acceptance — partial.** Keyboard checks
   passed for the palette menu, walkthrough tabs, sample review, FAQ and download
   handoff. Reduced-motion and 32 emulated palette/viewport cases passed. Native
   BrowserOS accessibility inspection exposes the new offer, copy control and
   text guide. VoiceOver speech was not verified: native attachment timed out.
   An iPhone 14 Pro Max (iOS 26.6.1) is paired, but its developer disk image could
   not mount and Mirroring requires initial setup. Android hardware is unavailable
   through the current tools. Actual iPhone Safari, Android Chrome and VoiceOver
   acceptance remain open; see `docs/launch-followups-qa.md`.
5. [ ] **Product proof — text guide complete; real recording blocked.** Added an
   accessible, keyboard-operated Scan → Review → Trash → Put Back explanation
   below the existing screenshot walkthrough, including Trash storage/recovery
   limits. Native DevPurge attachment repeatedly returned `timeoutReached`,
   including after the user opened the dashboard; no files were cleaned and no
   recording was fabricated. Capture an actual safe-fixture run when control is
   restored. Genuine beta quotes remain pending supplied quotes and permission.

## Landing page critique fixes (2026-10-29)

- Mobile hero composition (2026-10-30): replaces the stacked artwork with a two-column headline/laptop composition through 860px. Supporting copy and actions remain full width; the sample sticker and decorations are scaled for phones, and dark palettes add a paper offcut behind the basket. Mobile hero elements use their final paper rotations immediately. Thirty-two palette/viewport cases passed layout checks (320–1440px), plus reduced-motion verification; physical devices remain untested. Evidence: `docs/mobile-hero-qa.md`.
- Mobile layout (2026-10-30): fixed three-row phone navigation, full-width hero actions and a clipped 320px pricing action; added 44px phone controls, safe-area spacing, touch feedback and palette-aware browser chrome. Short landscape viewports use a scrolling header. Local layout checks passed at nine viewport sizes from 320×568 to 1440×960, including two landscape sizes; the 375px hero was visually inspected. Physical iPhone/Android and a fresh full interaction regression were not performed. Evidence: `docs/mobile-layout-qa.md`.
- Official website link (2026-10-30): GitHub's About homepage now points to `https://devpurge.com/` instead of the old GitHub Pages URL; the README also links the official site immediately below the cover.
- Repository cover (2026-10-30): published the 2:1 Zine-style brand cover, PNG master (1774×887), lightweight JPEG (839,980 bytes), and generation prompt under `docs/assets/devpurge-repository-cover-v1.*` in commit `56d6237`. The README displays the JPEG with descriptive alt text. GitHub's social preview is also configured with the same JPEG; GraphQL reports `usesCustomOpenGraphImage: true`. Independent QA passed remote file hashes, public README rendering, artwork legibility/crop, and the served social image (HTTP 200, byte-identical to the JPEG). Evidence: `docs/repository-graphics-qa.md`.
- Nav: links no longer wrap ("try it"), centred on one line with logo/button; logo and nav button use Lilita One; pink dashes removed from the button.
- Palette swatches moved into a single 44px toggle with a "Pick a palette" popover (Esc / outside click closes).
- CTA labels unified: "Download free" (DMG) in nav + hero, "Buy license · $19" secondary button in hero, "Buy · $19" receipt sticker (checkout).
- Mobile nav: 200px → 104px, two rows max down to 320px; logo tape no longer clips the wordmark.
- Hero scribble moved off the buy button; CLI card text enlarged (chips 15px, command 15–18px); pink "Hands off" stamp darkened for contrast.
- Hero sized by viewport height on laptop screens (≤1000px tall): both CTAs above the fold at 1280×800, 1440×900, 1536×864, 1920×1080.
- Verified with Playwright at 1440/900/390/320: no console errors, no horizontal scroll, palette menu works.
- Hero mouse parallax: 9 hero layers follow the cursor at different depths via CSS `translate`, plus scroll drift; frame-time easing, retargets on scroll, compositor hint for ink-filtered layers. Off on <861px, touch, low-core (`lite`), hidden tab and reduced motion (live toggle). 1024×768 now shows both hero CTAs. QA agent review + Playwright smoke passed.
- Conversion pass (2026-10-29): "Never touches" trust line under hero CTAs; proof strip of verifiable facts (12 cache modules, 136 automated tests, 0 network calls to scan, Trash with Put Back, macOS 14+); "See the real app" section with real app renders (`site/assets/app/<palette>-{dashboard,review,done}.webp`, swapped per page palette) stepping Scan → Review → Done once, accessible tab pattern; price section leads with "Download free", Buy is secondary. CLI note corrected 9 → 12 modules. Renders come from `DEVPURGE_SNAPSHOT_HOME=/Users/you DEVPURGE_SNAPSHOT_DIR=… swift test --filter PaletteSnapshotTests` (no real username), then `cwebp -q 82`.
- Follow-up (2026-10-29): phones get readable close-up crops (`*-dashboard-m.webp`, `*-done-m.webp` via `<picture>`, ≤560px); all app renders now 2x (`DEVPURGE_SNAPSHOT_SCALE=2`); "Field test" section with the measured Oct 21 run (58.8 → 68.5 GB free, 9.7 GB gained, from `launch-test-2026-10-21/marketing`); hero sticker announces "34.6 GB freed, sample scan" to screen readers instead of the count-up value. Mac app: results "DONE" stamp uses `Palette.stampOnNoteA` (was invisible in Blacklight/Ember, weak in Zine); contrast test covers it — ships with next app release. Checked in Chromium, Playwright WebKit and real Mobile Safari (iOS 26 Simulator, iPhone 17 Pro); WebKit accessibility tree reviewed.
- Launch access (2026-10-29): `404kidwiz/devpurge` made public after a gitleaks scan (0 findings, 84 in-scope commits; vendored `.agent-tools/` skipped) and a check that `launch-test-2026-10-21/` and private project names never entered history. New public `404kidwiz/devpurge-releases` holds the DMG + `SHA256SUMS.txt`; site download links point there (see `docs/RELEASING.md` step 7). Anonymous download verified, checksum matches.
- Open: builds are ad-hoc signed only (no Developer ID, not notarized) — site FAQ and release notes give "Open Anyway" steps; real fix needs Apple Developer Program + `scripts/release_mac.sh`. Lemon Squeezy store not activated and checkout in test mode (dashboard identity verification needed; Lemon Squeezy blocks non-browser requests, so use a real browser to check). History rewritten 2026-10-29 with git-filter-repo: local username paths → `/Users/you`, all authors → Andy Morris <404kidwiz@gmail.com>; backup bundle at `~/Desktop/devpurge-history-backup-2026-10-29/`. Old SHAs may stay reachable on GitHub via PR refs until GitHub support purges them. 10 stale feature/release branches are public. No customer testimonials yet; live VoiceOver and Safari.app not run.

- License parked (2026-10-29): Lemon Squeezy store 404 Technologies (#510216) is awaiting their review (identity, payout and tax submitted; checkout still in test mode). Site "Buy license" buttons replaced by disabled "License · coming soon"; FAQ, receipt and README reworded. To go live: delete the `LICENSE-SOON-BEGIN…END` blocks in `site/index.html`, uncomment the `LICENSE-LIVE` lines, revert the README wording, turn off Test mode, re-check checkout logged-out. Note: the shipped app 3.3.1 still links "Get one ($19)" to the same checkout.

- Domain connection (2026-10-30): connected purchased devpurge.com in Hostinger to GitHub Pages with four GitHub apex A records and www CNAME to 404kidwiz.github.io (TTL 300). Changed Pages build_type from legacy gh-pages to workflow because the old branch still exposed test checkout. Commit 4dd428c added site/CNAME and updated canonical/share URLs; Pages run 41160313273 succeeded. Live HTTP serves the current page, www redirects to the apex, and both domains pass GitHub DNS checks. GitHub still reports https_certificate=null; HTTPS enforcement returns "The certificate does not exist yet." Certificate issuance remains pending, so secure launch is not complete.
- Lemon Squeezy recheck (2026-10-30, authenticated BrowserOS Neo): application still received/awaiting review; Test mode remains on. Product 1483717 is published in Test mode at $19, with license generation enabled and two activations. Added a product description and post-purchase DMG/website links, changed license length from one year to unlimited to match the one-time offer, saved and verified after reload. The existing tax category is "Software as a service (SaaS) - personal use"; classification for this downloadable Mac app needs owner/provider review before live sales. Identity/payout/tax setup shows no new mandatory action; optional 2FA remains available. Purchases remain disabled on the public site. After approval: confirm live product/variant identifiers, configure live checkout, verify logged-out purchase and license activation, then enable site purchase links. App signing/notarization remains a separate existing release blocker (not performed in this domain session).
- Vercel migration (2026-10-30): supersedes the GitHub Pages hosting above. Created the `devpurge` Vercel project in `404kidwizs-projects`, connected the GitHub repository with root `site`, and deployed commit 4dd428c to production (deployment dpl_BvTnqp1eZRxJGh9MwaTB7YGY4PkM, READY). Replaced Hostinger's GitHub DNS records with Vercel's recommended two apex A records and project-specific www CNAME. Issued an auto-renewing certificate covering both domains. Browser verification: HTTPS apex loads from Vercel, www redirects to apex, CSS/JS/fonts/share image return 200, no completed images are broken, and both license buttons remain disabled with no active checkout links. Disabled the GitHub Pages workflow and removed its custom-domain binding; GitHub refused full Pages deactivation via API (422), so the legacy site configuration remains without the purchased domain. See `docs/DEPLOYING.md` for deployment and DNS details. Store approval and Mac signing remain separate pending checks.
