#!/usr/bin/env bash
# Downloads a model file into the SayType models directory.
# Usage: scripts/fetch-model.sh [name]   (default: tiny.en)
# Whisper names match https://huggingface.co/ggerganov/whisper.cpp (tiny.en, base.en, small.en, ...).
# "vad" fetches the Silero voice activity model.
# "qwen-3b" fetches the default correction model.
set -euo pipefail

NAME="${1:-tiny.en}"
MODELS_DIR="$HOME/Library/Application Support/SayType/models"

case "$NAME" in
  vad)
    FILE_NAME="ggml-silero-v5.1.2.bin"
    URL="https://huggingface.co/ggml-org/whisper-vad/resolve/main/$FILE_NAME" ;;
  qwen-1.5b)
    FILE_NAME="qwen2.5-1.5b-instruct-q4_k_m.gguf"
    URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/$FILE_NAME" ;;
  qwen-3b)
    FILE_NAME="qwen2.5-3b-instruct-q4_k_m.gguf"
    URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/$FILE_NAME" ;;
  *)
    FILE_NAME="ggml-$NAME.bin"
    URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$FILE_NAME" ;;
esac

mkdir -p "$MODELS_DIR"
if [ -f "$MODELS_DIR/$FILE_NAME" ]; then
  echo "$MODELS_DIR/$FILE_NAME already present."
  exit 0
fi

echo "Downloading $URL"
curl -fL --progress-bar -o "$MODELS_DIR/$FILE_NAME.part" "$URL"
mv "$MODELS_DIR/$FILE_NAME.part" "$MODELS_DIR/$FILE_NAME"
echo "Saved $MODELS_DIR/$FILE_NAME"
