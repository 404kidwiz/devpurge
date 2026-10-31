#!/usr/bin/env bash
# Build, sign (Developer ID), notarize, staple and checksum DevPurge for Mac.
#
# Requires, in your login keychain:
#   DEVELOPER_ID_APP  e.g. "Developer ID Application: Jamal Morris (TEAMID)"
#   NOTARY_PROFILE    created once with:
#     xcrun notarytool store-credentials devpurge-notary --apple-id YOU@example.com --team-id TEAMID
# Credentials are never read from or written to this repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${VERSION:-3.3.2}"
APP="${APP_BUNDLE_PATH:-$ROOT_DIR/DevPurge.app}"
DIST="$ROOT_DIR/dist"
DMG="$DIST/DevPurge-$VERSION.dmg"

: "${DEVELOPER_ID_APP:?Set DEVELOPER_ID_APP to your 'Developer ID Application: ...' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile (see header)}"

case "$DEVELOPER_ID_APP" in
  "Developer ID Application:"*) ;;
  *) echo "DEVELOPER_ID_APP must be a 'Developer ID Application' identity; Apple Development certificates cannot be notarized." >&2; exit 1 ;;
esac
if ! security find-identity -v -p codesigning | grep -F -- "$DEVELOPER_ID_APP" >/dev/null; then
  echo "Signing identity not found in keychain: $DEVELOPER_ID_APP" >&2
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Notary keychain profile '$NOTARY_PROFILE' is missing or invalid." >&2
  exit 1
fi

"$SCRIPT_DIR/build_mac_app.sh"

if strings "$APP/Contents/MacOS/DevPurge" | grep -q "DEVPURGE-DEV-"; then
  echo "Release binary still contains the debug license bypass; aborting." >&2
  exit 1
fi

echo "==> Signing app with hardened runtime..."
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Building DMG..."
mkdir -p "$DIST"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname DevPurge -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$DEVELOPER_ID_APP" "$DMG"

echo "==> Notarizing (this usually takes a few minutes)..."
NOTARY_LOG="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait)"
echo "$NOTARY_LOG"
if ! grep -q "status: Accepted" <<<"$NOTARY_LOG"; then
  echo "Notarization was not accepted. Inspect: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE" >&2
  exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"

(cd "$DIST" && shasum -a 256 "DevPurge-$VERSION.dmg" > "DevPurge-$VERSION.dmg.sha256")
echo "==> Ready: $DMG"
cat "$DMG.sha256"
