# Releasing DevPurge for Mac

1. Enroll in the Apple Developer Program and create a **Developer ID Application**
   certificate (Xcode → Settings → Accounts → Manage Certificates).
2. Store notarization credentials once (use an app-specific password):
   `xcrun notarytool store-credentials devpurge-notary --apple-id YOU@example.com --team-id TEAMID`
3. Set the public Lemon Squeezy IDs and checkout URL in
   `mac/Sources/DevPurge/Services/LicenseConfig.swift` (no API key is ever needed).
4. Run:
   ```bash
   DEVELOPER_ID_APP="Developer ID Application: Jamal Morris (TEAMID)" \
   NOTARY_PROFILE=devpurge-notary scripts/release_mac.sh
   ```
5. Test `dist/DevPurge-<version>.dmg` on another account or Mac: open it, scan,
   activate a Lemon Squeezy test-mode key, clean, deactivate.
6. Upload the DMG to the Lemon Squeezy product and attach it plus the `.sha256`
   file to the GitHub Release.
7. Publish the same DMG and `SHA256SUMS.txt` to the public downloads repo, then
   update the three download links in `site/index.html`:
   ```bash
   gh release create v<version> --repo 404kidwiz/devpurge-releases \
     --title "DevPurge <version>" dist/DevPurge-<version>.dmg SHA256SUMS.txt
   ```
