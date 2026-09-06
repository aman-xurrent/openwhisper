#!/usr/bin/env bash
# Downloads the prebuilt whisper.cpp and llama.cpp xcframeworks into Vendor/.
# Usage: scripts/fetch-frameworks.sh
set -euo pipefail

WHISPER_TAG="${WHISPER_TAG:-b4938}"
LLAMA_TAG="${LLAMA_TAG:-b10819}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fetch() {
  local project="$1" tag="$2"
  local target="$VENDOR_DIR/$project.xcframework"
  if [ -d "$target" ]; then
    echo "Vendor/$project.xcframework already present. Delete it to refetch."
    return
  fi
  local archive="$project-$tag-xcframework.zip"
  local url="https://github.com/ggml-org/$project.cpp/releases/download/$tag/$archive"
  echo "Downloading $url"
  curl -fL --progress-bar -o "$WORK_DIR/$archive" "$url"
  unzip -q "$WORK_DIR/$archive" -d "$WORK_DIR/$project"
  local found
  found="$(find "$WORK_DIR/$project" -type d -name "$project.xcframework" | head -n 1)"
  if [ -z "$found" ]; then
    echo "$project.xcframework not found inside $archive" >&2
    exit 1
  fi
  mkdir -p "$VENDOR_DIR"
  cp -R "$found" "$target"
  echo "Installed Vendor/$project.xcframework ($tag)"
}

fetch whisper "$WHISPER_TAG"
fetch llama "$LLAMA_TAG"
