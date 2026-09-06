# SayType

Press a hotkey anywhere on your Mac, talk, press it again. SayType listens for the
pauses between your sentences, transcribes each one on the device with
[whisper.cpp](https://github.com/ggml-org/whisper.cpp), cleans it up with a small
local language model through [llama.cpp](https://github.com/ggml-org/llama.cpp),
and pastes it into the focused text field. If nothing can take text, the transcript
lands on the clipboard instead. No audio or text leaves the machine.

## What happens when you dictate

1. `⌃⌥Space` (changeable) starts listening. A small panel at the bottom of the
   screen shows the microphone level.
2. Apple's voice processing removes background noise and echo from the microphone.
3. The Silero voice activity model watches the audio. A pause of 0.8 seconds
   (changeable) ends a sentence.
4. Each finished sentence goes to whisper. The previous sentence and your
   vocabulary list are given to whisper as its prompt, which helps with names and
   continuity.
5. The Qwen2.5 correction model fixes punctuation, capitalization, filler words,
   and misheard words. A sanity check compares its output with the raw transcript
   and keeps the raw text if the model changed too much.
6. The sentence is pasted at the cursor while you keep talking. `⌃⌥Space` again
   finishes. `⎋` cancels.

Turn off "Paste each sentence as soon as you pause" in Settings to get the old
behavior: one transcription after you stop.

## Requirements

- macOS 14 or newer, Apple silicon recommended.
- Xcode 16 or newer.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- A free or paid Apple developer team for code signing. A stable signature keeps
  the Microphone and Accessibility permissions across rebuilds.

## Build

```sh
make setup      # fetches the whisper and llama xcframeworks, writes Config/Local.xcconfig, generates the project
make install    # release build synced into /Applications
open /Applications/SayType.app
```

`make setup` picks the first "Apple Development" team it finds in your keychain.
If that is the wrong one, edit `Config/Local.xcconfig`.

## First launch

1. Grant Microphone access when macOS asks.
2. Grant Accessibility access in System Settings > Privacy & Security >
   Accessibility. Without it, SayType still works but only copies to the clipboard.
3. SayType downloads three models and opens Settings so you can watch:
   `small.en` for whisper (488 MB), the Silero voice activity model (1 MB), and
   `qwen2.5-3b-instruct-q4_k_m` for correction (2.1 GB).

## Models

Everything lives in `~/Library/Application Support/SayType/models/`.

- **Whisper**: all 33 files from the whisper.cpp Hugging Face repo, grouped by
  family in Settings > Model. `small.en` is the default.
- **Correction**: Qwen2.5 Instruct in 1.5B, 3B (default), and 7B. The 7B is the
  most accurate and about twice as slow.
- **Vocabulary**: Settings > Correction. Names and terms, one per line. Both
  whisper and the correction model see the list.

## Tests

```sh
make model      # downloads tiny.en, the Silero model, and Qwen 3B for the model-backed tests
make test
```

## How the pieces fit

- `Hotkey/` registers the global shortcut with Carbon `RegisterEventHotKey`,
  which needs no Input Monitoring permission.
- `Audio/` captures the microphone with `AVAudioEngine`, resamples to 16 kHz,
  runs Silero VAD, and cuts turns with a small state machine (`TurnDetector`).
- `Whisper/` wraps `whisper.xcframework` and manages every model download.
- `Correction/` wraps `llama.xcframework` behind a C shim (`LlamaShim/`), because
  the two frameworks ship different ggml headers and Swift cannot import both.
  `CorrectionValidator` is the guard that rejects rewrites.
- `Output/` runs the per-turn pipeline (`DictationSession`), reads the focused
  element through the Accessibility API, and pastes with a synthetic `⌘V`.
- `UI/` holds the menu bar item, the floating panel, and the Settings window.
