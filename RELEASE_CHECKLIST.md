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

- [x] **Create Store & Product in Lemon Squeezy**
  - Store: **404 Technologies** (`https://404technologies.lemonsqueezy.com`, `storeID = 510216`).
  - Product: **DevPurge for Mac** ($19.00 one-time, license keys enabled, activation limit = `2` instances per key, `productID = 1483717`).
  - Checkout URL: `https://404technologies.lemonsqueezy.com/checkout/buy/3c0d0268-398f-489a-854a-cb1ea34f136b`
- [x] **Lock Store & Product IDs in `LicenseConfig.swift`**
  - Set `storeID = 510216`, `productID = 1483717`, and `checkoutURL` in [`mac/Sources/DevPurge/Services/LicenseConfig.swift`](file:///Users/you/Desktop/404%20Projects/devpurge/mac/Sources/DevPurge/Services/LicenseConfig.swift) and [`site/index.html`](file:///Users/you/Desktop/404%20Projects/devpurge/site/index.html).
- [ ] **Activate Live Store Mode in Lemon Squeezy**
  - Complete the quick identity verification step at `https://app.lemonsqueezy.com/settings/general/identity` when ready to accept live customer payments (Test Mode works immediately).

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
  - Run `scripts/release_mac.sh` with `DEVELOPER_ID_APP` and `NOTARY_PROFILE` set, or manually notarize:
    ```bash
    ditto -c -k --keepParent DevPurge.app DevPurge-3.3.1.zip
    xcrun notarytool submit DevPurge-3.3.1.zip \
      --keychain-profile "AC_PASSWORD" \
      --wait
    xcrun stapler staple DevPurge.app
    ```
  - Verify Gatekeeper acceptance on a clean Mac:
    ```bash
    spctl -a -t exec -vv DevPurge.app
    ```

---

## 4. Distribution Channels (GitHub Releases, Homebrew & PyPI)

- [x] **GitHub Release (`v3.3.1`)**
  - Tagged `v3.3.1` and uploaded `DevPurge-3.3.1.dmg` + `SHA256SUMS.txt` at `https://github.com/404kidwiz/devpurge/releases/tag/v3.3.1`.
  - Updated the **"Get for Mac"** and **"Download for Mac"** CTA links in `site/index.html` to point directly to the Lemon Squeezy checkout and `v3.3.1` DMG download.
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

- [x] **Deploy `site/` Static Assets**
  - Deployed `site/` live to GitHub Pages at `https://404kidwiz.github.io/devpurge/` (`gh-pages` branch + `.github/workflows/pages.yml`) and set the GitHub repository homepage URL.
- [x] **Verify OpenGraph & Metadata**
  - Configured `<link rel="canonical" href="https://404kidwiz.github.io/devpurge/">` and absolute `og:image` / `twitter:image` (`https://404kidwiz.github.io/devpurge/assets/og.jpg`) in `site/index.html`.

---

## 6. Post-Launch Monitoring

- [ ] **Zero-Telemetry Crash & Support Triage**
  - Provide a GitHub Issue template for "False Positive / Missed Cache Path" so users can submit new developer cache locations alongside the output of **Copy report** (`⇧⌘C`) in `DevPurge.app`.
