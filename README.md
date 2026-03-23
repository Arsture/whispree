# Whispree

A free, fully local macOS menu bar app for speech-to-text with LLM post-processing. An open-source alternative to SuperWhisper, running entirely on Apple Silicon with no cloud dependencies.

## Features

- **Local STT** — WhisperKit (large-v3-turbo) for high-accuracy speech recognition in 99+ languages
- **LLM Correction** — mlx-swift-lm (Qwen2.5-3B-Instruct-4bit) for automatic text correction (spacing, punctuation, homophones)
- **Global Hotkey** — Push-to-talk and toggle recording modes with customizable shortcuts
- **Text Insertion** — Automatically inserts transcribed text at cursor position via Accessibility API (clipboard fallback)
- **Streaming** — Real-time partial transcription results displayed in a floating overlay
- **Privacy First** — All processing happens on-device. Zero network calls after initial model download.

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- ~4GB disk space for models (WhisperKit ~1.5GB + LLM ~2GB)
- Microphone permission
- Accessibility permission (for text insertion)

## Build

### Prerequisites

- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Steps

```bash
# Clone
git clone https://github.com/Arsture/Whispree.git
cd Whispree

# Generate Xcode project
xcodegen generate

# Open in Xcode
open Whispree.xcodeproj

# Build and run (⌘R)
```

SPM dependencies (WhisperKit, mlx-swift-lm, KeyboardShortcuts, LaunchAtLogin) resolve automatically on first build.

## Usage

1. **First Launch** — Grant microphone and accessibility permissions when prompted. Models download automatically (~3.5GB).
2. **Record** — Press the global hotkey (default: `Option+Space`) to start recording.
3. **Transcribe** — Release the key (push-to-talk) or press again (toggle mode) to transcribe.
4. **Insert** — Corrected text is automatically inserted at your cursor position.

### Settings

Access settings from the menu bar icon:

- **General** — Hotkey customization, recording mode, launch at login
- **Models** — Model selection, download management, disk usage
- **LLM** — Enable/disable LLM correction, custom prompts

## Architecture

```
Whispree/
├── App/                    # App entry point, delegate, state
├── Models/                 # Data models (settings, state, model info)
├── Services/
│   ├── Audio/              # AVAudioEngine microphone capture
│   ├── STT/                # WhisperKit integration
│   ├── LLM/                # mlx-swift-lm integration
│   ├── TextInsertion/      # AX API + clipboard fallback
│   ├── ModelManagement/    # Model download & cache
│   └── Hotkey/             # KeyboardShortcuts integration
├── Coordinators/           # Pipeline orchestration
├── Views/                  # SwiftUI views
└── Resources/              # Assets, entitlements, Info.plist
```

**Pattern**: MVVM + Services with `AppState` as the central `@MainActor ObservableObject`.

**Pipeline**: Hotkey → Record → Transcribe (WhisperKit) → [Correct (LLM)] → Insert Text

## Tech Stack

| Component | Library | Purpose |
|-----------|---------|---------|
| STT | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | On-device speech recognition via CoreML + ANE |
| LLM | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | On-device text correction via MLX GPU |
| Hotkey | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey registration |
| Login | [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin-Modern) | Login item support |

## License

MIT
