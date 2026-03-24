# Whispree

A free, fully local macOS menu bar app for speech-to-text with LLM post-processing. An open-source alternative to SuperWhisper, running entirely on Apple Silicon with no cloud dependencies.

[한국어](README.ko.md) | English

![License](https://img.shields.io/github/license/Arsture/whispree)
![Version](https://img.shields.io/github/v/release/Arsture/whispree)
![Build](https://img.shields.io/github/actions/workflow/status/Arsture/whispree/release.yml)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)

<!-- Demo video -->
<p align="center">
  <em>Demo video coming soon</em>
</p>

## Features

- **Local STT** — WhisperKit (large-v3-turbo) for high-accuracy speech recognition in 99+ languages
- **LLM Correction** — mlx-swift-lm (Qwen3-4B) for automatic text correction (spacing, punctuation, homophones)
- **Global Hotkey** — Push-to-talk and toggle recording modes with customizable shortcuts
- **Text Insertion** — Automatically inserts transcribed text at cursor position via Accessibility API (clipboard fallback)
- **Streaming** — Real-time partial transcription results displayed in a floating overlay
- **Privacy First** — All processing happens on-device. Zero network calls after initial model download.
- **Auto-Updates** — Background update checks via Sparkle. Get notified when a new version is ready.

## The Name

> Started as **FreeWhisper** — just a personal tool, nothing fancy.
>
> Then I thought about going open-source, so **OpenWhisper** felt right.
> Turns out that name was taken.
>
> Settled on **not-my-whisper** for a while.
> But it was too long, and honestly — it felt too much like *my* whisper
> to keep calling it "not mine."
>
> So here we are: **Whispree**. Free whisper. My whisper. Your whisper.

## Tips & Tricks

> **Pro tip**: Wear AirPods and pretend you're on a call. Nobody will know you're dictating your grocery list in the office.

> **Meeting hack**: Mute yourself on Zoom, whisper into Whispree, and paste perfectly formatted notes before anyone notices.

> **Public transport**: The "I'm on a very important call" face works wonders. Just look slightly annoyed while speaking.

## Installation

### Homebrew Cask (Recommended)

```bash
brew install --cask whispree
```

### From Releases

Download the latest `.dmg` or `.zip` from [GitHub Releases](https://github.com/Arsture/whispree/releases).

### Build from Source

```bash
git clone https://github.com/Arsture/whispree.git
cd whispree
brew install xcodegen
xcodegen generate
open Whispree.xcodeproj
# Build and run (Cmd+R)
```

SPM dependencies resolve automatically on first build.

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

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- ~4GB disk space for models (WhisperKit ~1.5GB + LLM ~2GB)
- Microphone permission
- Accessibility permission (for text insertion)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
