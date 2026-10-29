# DevPurge Launch & Release Checklist

This checklist covers everything required to take **DevPurge** (`DevPurge.app` native macOS utility, open-source Python CLI/local Web GUI, and the `site/` landing page) from local release candidate to production launch.

---

## 1. Pre-Flight Code & Test Verification

- [x] **Native Swift Engine & UI Snapshot Suite (`mac/`)**
  - Run `cd mac && swift test` — verify all engine tests, WCAG AA contrast checks across all 4 palettes (`Zine`, `Citrus`, `Blacklight`, `Ember`), and 20 AppKit snapshot renders pass.
  - Verify `TargetScanner.measure(path:)` uses native `FileManager.enumerator` (`totalFileAllocatedSizeKey`) without spawning concurrent `du` processes.
  - Verify `ProcessInspector` uses `NSLock` + `FD_CLOEXEC` and scoped `lsof -w -nP -d ^cwd -F cn` open-file detection (ignoring passive macOS `NotificationCenter`/`usernoted` `.strings` mappings while attributing active open files to their holding process).
- [x] **Python CLI & Local Web GUI (`devpurge/`)**
  - Run `python3 -m unittest discover -s tests` and `python3 -m devpurge --dry-run`.
  - Verify `python3 -m devpurge --gui` launches on `127.0.0.1` with host-header, Origin, and CSRF token validation.
- [x] **Landing Page (`site/`)**
  - Verify zero console errors, zero horizontal scroll (`scrollWidth === innerWidth`) at `1440×900`, `768×1024`, and `390×844`.
  - Verify interactive 4-palette theme switcher (`Zine`, `Citrus`, `Blacklight`, `Ember`), interactive sticky-note review board (`Select all safe` / `Clear`), and the interactive **CLI Command Builder** (`Copy` + `COPIED!` stamp).

---

## 2. Lemon Squeezy Store & Licensing Setup

Currently, `LicenseService.Config` in [`mac/Sources/DevPurge/Services/LicenseService.swift`](file:///Users/you/Desktop/404%20Projects/devpurge/mac/Sources/DevPurge/Services/LicenseService.swift) has `expectedStoreId: nil` and `expectedProductId: nil` (with a debug assertion reminder). Before shipping the production DMG:

- [ ] **Create Product in Lemon Squeezy**
  - Create product **"DevPurge for Mac"** ($19 one-time, license keys enabled, activation limit = `2` instances per key, 14-day refund window).
  - Copy the numeric **Store ID** and **Product ID** from the Lemon Squeezy dashboard.
- [ ] **Lock Store & Product IDs in `LicenseService.swift`**
  - Set `expectedStoreId = <YOUR_STORE_ID>` and `expectedProductId = <YOUR_PRODUCT_ID>` in `LicenseService.Config` so keys from other Lemon Squeezy stores cannot activate `DevPurge.app`.
  - Set `checkoutURL` in `LicenseService.Config` to your live Lemon Squeezy checkout URL (e.g., `https://store.lemonsqueezy.com/checkout/buy/...`).
- [ ] **End-to-End License QA**
  - Test activating a real test license key (`activate`), verifying Keychain persistence (`com.404kidwiz.devpurge.license`), testing offline grace period (14 days), and deactivating (`deactivate`).
  - Confirm the 3-free-cleanups counter (`freeCleanupsRemaining`) decrements only on completed cleanups (`deletedCount > 0`) and unlocks unlimited cleanups immediately upon activation.

---

## 3. Apple Developer ID Signing, Hardened Runtime & Notarization

Currently, `scripts/build_mac_app.sh` uses ad-hoc code signing (`codesign --force --deep --sign -`). Gatekeeper on macOS 14+ (Sonoma / Sequoia) requires a Developer ID Application signature and Apple notarization for downloaded apps.

- [ ] **Configure Entitlements & Hardened Runtime**
  - Sign with `--options runtime` (Hardened Runtime) using your `Developer ID Application: <Name> (<TEAM_ID>)` certificate:
    ```bash
    codesign --force --options runtime --timestamp \
      --sign "Developer ID Application: <YOUR_NAME> (<TEAM_ID>)" \
      DevPurge.app
    ```
  - Verify signature:
    ```bash
    codesign --verify --deep --strict --verbose=2 DevPurge.app
    ```
- [ ] **Package & Notarize DMG / ZIP**
  - Create a compressed DMG or ZIP for notarization:
    ```bash
    ditto -c -k --keepParent DevPurge.app DevPurge-1.0.0.zip
    xcrun notarytool submit DevPurge-1.0.0.zip \
      --keychain-profile "AC_PASSWORD" \
      --wait
    xcrun stapler staple DevPurge.app
    ```
  - Create the distributable `DevPurge-1.0.0.dmg` containing the stapled `DevPurge.app` and an `/Applications` symlink, then sign and notarize/staple the `.dmg` itself.
  - Verify Gatekeeper acceptance on a clean Mac:
    ```bash
    spctl -a -t exec -vv DevPurge.app
    ```

---

## 4. Distribution Channels (GitHub Releases, Homebrew & PyPI)

- [ ] **GitHub Release (`v1.0.0`)**
  - Tag `v1.0.0` and upload `DevPurge-1.0.0.dmg` + `SHA256SUMS.txt`.
  - Update the **"Get for Mac"** CTA link in `site/index.html` to point directly to the Lemon Squeezy checkout or direct DMG trial download.
- [ ] **PyPI Package (`pipx install devpurge` / `uvx devpurge`)**
  - Build and verify wheel + sdist:
    ```bash
    python3 -m build
    twine check dist/*
    ```
  - Publish to PyPI so users can run `uvx devpurge --dry-run` or `pipx run devpurge` with zero manual cloning.
- [ ] **Homebrew Cask & Formula (Optional, High Conversion)**
  - Publish a Homebrew tap (`brew install 404kidwiz/tap/devpurge` for CLI and `brew install --cask 404kidwiz/tap/devpurge-app` for the macOS app).

---

## 5. Landing Page Deployment & SEO / Social Verification

- [ ] **Deploy `site/` Static Assets**
  - Deploy `site/` to Cloudflare Pages, Vercel, or GitHub Pages with immutable cache headers on `site/fonts/*.woff2` and `site/assets/*.webp`.
- [ ] **Verify OpenGraph & Metadata**
  - Set `<link rel="canonical" href="https://devpurge.dev/">` and verify `og:image` (`assets/og.jpg`) uses an absolute production URL so X/Twitter, iMessage, Slack, and Discord unfurl the Zine preview card cleanly.

---

## 6. Post-Launch Monitoring

- [ ] **Zero-Telemetry Crash & Support Triage**
  - Provide a GitHub Issue template for "False Positive / Missed Cache Path" so users can submit new developer cache locations alongside the output of **Copy report** (`⇧⌘C`) in `DevPurge.app`.
