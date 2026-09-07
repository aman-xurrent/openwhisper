# OpenWhisper

On-device push-to-talk dictation for macOS. Press a hotkey, talk, press it again.
OpenWhisper listens for the pauses between your sentences, transcribes each one on the
device with [whisper.cpp](https://github.com/ggml-org/whisper.cpp), cleans it up
with a small local language model through
[llama.cpp](https://github.com/ggml-org/llama.cpp), and pastes it into the focused
text field. If nothing can take text, the transcript goes to the clipboard. No
audio and no text leave the machine.

## Install with one command

```sh
curl -fsSL https://raw.githubusercontent.com/aman-xurrent/openwhisper/main/install.sh | bash
```

This installs Homebrew and XcodeGen if you do not have them, downloads the
source, builds the app, downloads the models, installs OpenWhisper into
`~/Applications`, and launches it. It needs two things it cannot install for you:

- **Xcode**, from the App Store. Open it once after installing.
- **An Apple ID in Xcode** for signing (Xcode > Settings > Accounts). A free
  Apple ID works.

On first launch OpenWhisper asks for **Microphone** and **Accessibility**.
Approve both. macOS requires you to approve them yourself; the app only shows
the prompts.

## Manual quick start

Prefer to run the steps yourself:

```sh
brew install xcodegen        # one-time, if you do not have it
git clone git@github.com:aman-xurrent/openwhisper.git
cd openwhisper
make setup                   # fetch frameworks, write signing config, generate the project
make run                     # build and launch OpenWhisper.app
```

The rest of this file explains each step.

## Setup guide

Follow these steps on a clean Mac.

### 1. Install the tools

- **macOS 14 or newer.** Apple silicon is recommended. Intel works but is slower.
- **Xcode 16 or newer**, from the App Store. Open it once so it finishes
  installing its components.
- **XcodeGen**, which turns `project.yml` into the Xcode project:

  ```sh
  brew install xcodegen
  ```

- **An Apple developer team for signing.** A free Apple ID works. A stable
  signature is what keeps the Microphone and Accessibility permissions across
  rebuilds, so use the same team every time.

### 2. Get the code

```sh
git clone git@github.com:aman-xurrent/openwhisper.git
cd openwhisper
```

### 3. Run setup

```sh
make setup
```

This does three things:

1. **Fetches the prebuilt frameworks** into `Vendor/` with
   `scripts/fetch-frameworks.sh`: `whisper.xcframework` and `llama.xcframework`.
   They are not in the repo because they are large and belong to the upstream
   projects. The versions are pinned in the script.
2. **Writes `Config/Local.xcconfig`** with `scripts/write-local-xcconfig.sh`. It
   picks the first "Apple Development" team it finds in your keychain. If that is
   the wrong one, open the file and set `DEVELOPMENT_TEAM` to your ten-character
   team id. This file is git-ignored, so your signing id never gets committed.
3. **Generates `OpenWhisper.xcodeproj`** from `project.yml`.

To sign with a specific team without editing anything by hand:

```sh
echo "DEVELOPMENT_TEAM = ABCDE12345" > Config/Local.xcconfig
make setup
```

### 4. Build and launch

```sh
make run           # release build, then opens the app
```

Or `make install` to copy the app into `/Applications`, or open
`OpenWhisper.xcodeproj` in Xcode and press Run. OpenWhisper has no window. It lives in the
menu bar as a microphone icon.

### 5. Grant permissions

1. **Microphone.** macOS asks the first time OpenWhisper listens. Allow it.
2. **Accessibility.** System Settings > Privacy & Security > Accessibility, and
   turn on OpenWhisper. This lets it find the focused text field and paste for you.
   Without it, OpenWhisper still works but only copies to the clipboard.

### 6. Wait for the models

On first launch OpenWhisper downloads three models into
`~/Library/Application Support/OpenWhisper/models/` and opens Settings so you can
watch the progress:

| Model | Size | Job |
|---|---|---|
| `large-v3` (whisper) | 3.1 GB | Speech to text |
| Silero VAD | 1 MB | Finds the pauses between sentences |
| `qwen2.5-3b-instruct-q4_k_m` | 2.1 GB | Fixes casing, punctuation, and misheard words |

The default whisper model is `large-v3`, the most accurate one, so the first download is large. Pick a smaller model in Settings > Model if you want a quick start. You can dictate as soon as the whisper and VAD models are down. Correction starts
working once the Qwen model finishes.

## Using it

1. `⌃⌥Space` (changeable) starts listening. A small panel shows the mic level.
2. Talk. A pause of about 0.8 seconds ends a sentence, which is transcribed,
   corrected, and pasted while you keep going.
3. `⌃⌥Space` again finishes. `⎋` while listening cancels.

Turn off "Paste each sentence as soon as you pause" in Settings to transcribe the
whole recording once, after you stop.

## Settings

Everything is configurable in the menu bar item's Settings window.

- **General.** The hotkey, the pause length that ends a sentence, turn mode on or
  off, the language for multilingual models, noise suppression, and launch at
  login.
- **Model.** The whisper model. All 33 files from the whisper.cpp Hugging Face
  repo are listed, grouped by family, with a download button each. `large-v3` is
  the default and the most accurate. `small.en` is a fast, light alternative, and
  `large-v3-turbo-q5_0` is the best multilingual choice.
- **Correction.** Turn correction on or off, pick the correction model
  (Qwen2.5 in 1.5B, 3B, or 7B), and edit two lists:
  - **Vocabulary**: names and jargon. Whisper and the correction model both see
    it and lean toward these spellings.
  - **Always replace**: exact `wrong = right` fixes for a word that is always
    misheard, applied to every transcript.
- **Permissions.** Shows whether Microphone and Accessibility are granted, with
  buttons to request them or open System Settings.

## Command reference

| Command | What it does |
|---|---|
| `make setup` | Fetch frameworks, write signing config, generate the project. Run once after cloning. |
| `make run` | Release build, then launch the app. |
| `make install` | Release build, synced into `/Applications`. |
| `make generate` | Regenerate `OpenWhisper.xcodeproj` from `project.yml`. |
| `make model` | Download the models the tests need (tiny.en, Silero, Qwen 3B). |
| `make test` | Run the unit tests. |
| `make clean` | Remove the build output and the generated project. |

The model download scripts can be run directly too:

```sh
scripts/fetch-model.sh small.en     # any whisper model name
scripts/fetch-model.sh vad          # the Silero voice activity model
scripts/fetch-model.sh qwen-3b      # the correction model
```

## Tests

```sh
make model      # one-time, downloads the models the model-backed tests use
make test
```

Tests that need a model skip cleanly if it is missing, so `make test` passes even
without `make model`, it just runs fewer tests.

## Troubleshooting

- **"No microphone signal".** The mic returned silence. Check System Settings >
  Privacy & Security > Microphone and confirm OpenWhisper is on. If you rebuilt with a
  different signing team, macOS may treat it as a new app, so grant it again.
- **Text lands on the clipboard instead of the field.** Accessibility is not
  granted, or the focused field is a password field, or secure input is active.
  Grant Accessibility in System Settings.
- **`make install` fails with "Permission denied" on `/Applications`.** Recent
  macOS blocks the terminal from creating or deleting apps in `/Applications`
  (App Management). Either grant your terminal App Management in System Settings >
  Privacy & Security > App Management, or install into your user folder instead:
  `mkdir -p ~/Applications && rsync -a --delete build/DerivedData/Build/Products/Release/OpenWhisper.app/ ~/Applications/OpenWhisper.app/`.
- **The menu bar icon never appears.** Another copy may be running. Quit it from
  the menu bar, or `pkill -x OpenWhisper`, then launch again.
- **A word is always misheard.** Add it to the Vocabulary list, or add an exact
  `wrong = right` line to "Always replace" in Settings > Correction.

## How the pieces fit

- `Hotkey/` registers the global shortcut with Carbon `RegisterEventHotKey`,
  which needs no Input Monitoring permission.
- `Audio/` captures the microphone with `AVAudioEngine`, resamples to 16 kHz,
  runs Silero VAD, and cuts sentences with a small state machine (`TurnDetector`).
- `Whisper/` wraps `whisper.xcframework` and manages every model download.
- `Correction/` wraps `llama.xcframework` behind a C shim (`LlamaShim/`), because
  the two frameworks ship different ggml headers and Swift cannot import both.
  `CorrectionValidator` keeps the raw text when the model strays too far.
- `Output/` runs the per-sentence pipeline (`DictationSession`), reads the focused
  element through the Accessibility API, and pastes with a synthetic `⌘V`.
- `UI/` holds the menu bar item, the floating panel, and the Settings window.

## Privacy

Everything runs on the device. The models are downloaded once from Hugging Face.
After that, no audio and no text ever leave your Mac.
