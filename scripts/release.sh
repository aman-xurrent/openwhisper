#!/usr/bin/env bash
# Build, sign (Developer ID), notarize, staple, and zip OpenWhisper for
# distribution to Macs that have no Xcode and no Apple account.
#
# One-time prerequisites on the maintainer's Mac:
#   1. A "Developer ID Application" certificate in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   2. Notarization credentials stored as a keychain profile:
#        xcrun notarytool store-credentials openwhisper-notary \
#          --apple-id you@example.com --team-id GXUQ2Q6Z8Y \
#          --password <app-specific-password>
set -euo pipefail

TEAM_ID="${TEAM_ID:-GXUQ2Q6Z8Y}"
NOTARY_PROFILE="${NOTARY_PROFILE:-openwhisper-notary}"
SCHEME="OpenWhisper"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
ARCHIVE="$BUILD/OpenWhisper.xcarchive"
EXPORT="$BUILD/export"
APP="$EXPORT/OpenWhisper.app"
DIST="$ROOT/dist"
ZIP="$DIST/OpenWhisper.zip"

die() { printf "\nError: %s\n" "$1" >&2; exit 1; }
log() { printf "\n==> %s\n" "$1"; }

security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || die "No 'Developer ID Application' certificate found. Create one in Xcode > Settings > Accounts > Manage Certificates."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || die "Notary profile '$NOTARY_PROFILE' not found. Run:
  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <email> --team-id $TEAM_ID --password <app-specific-password>"

log "Fetching frameworks and generating the project"
"$ROOT/scripts/fetch-frameworks.sh"
( cd "$ROOT" && xcodegen generate >/dev/null )

rm -rf "$BUILD" "$DIST"; mkdir -p "$BUILD" "$DIST"

cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

log "Archiving"
xcodebuild -project "$ROOT/OpenWhisper.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" archive DEVELOPMENT_TEAM="$TEAM_ID" | tail -n 3

log "Exporting a Developer ID signed app"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" | tail -n 3
[ -d "$APP" ] || die "Export did not produce $APP"

log "Notarizing (submits to Apple and waits)"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

log "Stapling the notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl -a -vvv --type exec "$APP" || true

log "Zipping the stapled app for distribution"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
printf "\nDone: %s\n" "$ZIP"
