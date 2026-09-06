#!/usr/bin/env bash
# Writes Config/Local.xcconfig with the first personal "Apple Development"
# team id found in the login keychain. Does nothing if the file exists.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT_DIR/Config/Local.xcconfig"

if [ -f "$TARGET" ]; then
  echo "Config/Local.xcconfig already present."
  exit 0
fi

TEAM_ID="$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
  | awk '/BEGIN CERT/{buf=""} {buf=buf"\n"$0} /END CERT/{print buf | "openssl x509 -noout -subject 2>/dev/null"; close("openssl x509 -noout -subject 2>/dev/null")}' \
  | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' \
  | head -n 1)"

if [ -z "$TEAM_ID" ]; then
  cp "$ROOT_DIR/Config/Local.xcconfig.example" "$TARGET"
  echo "No Apple Development certificate found. Edit $TARGET and set DEVELOPMENT_TEAM."
  exit 0
fi

echo "DEVELOPMENT_TEAM = $TEAM_ID" > "$TARGET"
echo "Wrote $TARGET with team $TEAM_ID"
