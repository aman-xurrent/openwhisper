#!/usr/bin/env bash
#
# One-command installer for OpenWhisper.
#   curl -fsSL https://raw.githubusercontent.com/aman-xurrent/openwhisper/main/install.sh | bash
#
# It installs Homebrew and XcodeGen if missing, fetches the source, builds the
# app, downloads the models, installs the app into ~/Applications, and launches
# it. Two things it cannot do for you, because macOS does not allow it:
#   - install full Xcode (a large App Store download), and
#   - grant the Microphone and Accessibility permissions (you click those once).
set -euo pipefail

REPO_URL="https://github.com/aman-xurrent/openwhisper.git"
SRC_DIR="${OPENWHISPER_SRC:-$HOME/openwhisper}"
APP_DIR="$HOME/Applications"

log()  { printf "\n\033[1;34m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m    %s\033[0m\n" "$1"; }
die()  { printf "\n\033[1;31mError:\033[0m %s\n" "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "OpenWhisper runs on macOS only."

# 1. Xcode. A script cannot install it; it is a large App Store download.
if ! /usr/bin/xcrun --find xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  die "Full Xcode is required to build OpenWhisper, and a script cannot install it.
    1. Open the App Store, search for Xcode, install it.
    2. Open Xcode once so it finishes setup.
    3. Run this command again."
fi

# 2. A signing identity. Building a Mac app needs one.
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
  die "No code-signing identity found.
    Open Xcode > Settings > Accounts, add your Apple ID (a free one works),
    then run this command again."
fi

# 3. Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die "Homebrew installed but is not on PATH. Open a new terminal and run this again."

# 4. XcodeGen.
if ! command -v xcodegen >/dev/null 2>&1; then
  log "Installing XcodeGen"
  brew install xcodegen
fi

# 5. Source.
if [ -d "$SRC_DIR/.git" ]; then
  log "Updating the source in $SRC_DIR"
  git -C "$SRC_DIR" pull --ff-only
else
  log "Downloading the source into $SRC_DIR"
  git clone "$REPO_URL" "$SRC_DIR"
fi
cd "$SRC_DIR"

# 6. Fetch frameworks, write signing config, generate the project.
log "Setting up the project"
make setup

# 7. Build.
log "Building OpenWhisper (a few minutes the first time)"
make build

# 8. Install into ~/Applications, which needs no special permission.
log "Installing OpenWhisper.app into $APP_DIR"
mkdir -p "$APP_DIR"
rsync -a --delete "build/DerivedData/Build/Products/Release/OpenWhisper.app/" "$APP_DIR/OpenWhisper.app/"

# 9. Download the models so the first launch is ready to use.
log "Downloading models: large-v3 whisper (3.1 GB), Silero VAD (1 MB), Qwen 3B (2.1 GB)"
warn "This is about 5 GB and can take a while on a slow connection."
scripts/fetch-model.sh large-v3
scripts/fetch-model.sh vad
scripts/fetch-model.sh qwen-3b

# 10. Launch.
log "Launching OpenWhisper"
open "$APP_DIR/OpenWhisper.app"

printf "\n\033[1;32mDone.\033[0m OpenWhisper is running. Look for the microphone icon in the menu bar.\n\n"
cat <<'DONE'
Two one-time macOS permissions (macOS requires you to click these):
  1. Microphone     allow it when the prompt appears.
  2. Accessibility  System Settings > Privacy & Security > Accessibility,
                    then turn on OpenWhisper.

To dictate: press Control-Option-Space, talk, press it again.
DONE
