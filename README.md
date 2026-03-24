# Whispree

A macOS menu bar speech-to-text app with swappable STT and LLM providers. Near-zero latency, high accuracy, and practically free with just an OpenAI account.

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

### Choose Your Providers

Pick your own STT and LLM providers — like [OpenCode](https://github.com/nicepkg/opencode), but for voice.

| Provider | STT Options | LLM Options |
|----------|-------------|-------------|
| Cloud (Recommended) | [Groq API](https://groq.com/) — free, fast, accurate | [OpenAI via Codex CLI](https://github.com/openai/codex) — use your existing account |
| Local | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — on-device, CoreML + ANE | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — Qwen3-4B on Apple Silicon |
| Local | [MLX Audio](https://github.com/ml-explore/mlx-audio) — Qwen3-ASR via Python worker | — |

### Built for Korean Developers Who Mix English

Whispree is optimized for **code-switching** — speaking Korean with English technical terms. The LLM correction layer handles things like:

- "밸리데이션" → "validation"
- "리액트 컴포넌트" → "React 컴포넌트"
- Spoken prompts restructured into clean written text

### Smart Dictation

- **Record & transcribe** — Press `Ctrl+Shift+R` to start, press again to stop and transcribe
- **Quick Fix** — Misheard a word? Press `Ctrl+Shift+D` to save corrections to your personal dictionary
- **Multiple correction modes** — STT correction, code-switch correction, prompt engineering mode

## The Name

> I originally called it **FreeWhisper** — just a personal tool I hacked together in Swift. Nobody else was going to use it, so the name didn't matter.
>
> When I decided to open-source it, I needed a proper name. Something "Oh My ..." felt dated. **OpenWhisper** was already taken.
>
> Then I thought about how I was borrowing API keys like a cat borrowing someone's sunny spot — so **Not My Whisper** had a nice ring to it. But after using it every day, I got attached. *"Wait, this IS my whisper."*
>
> So: **Whispree**. Free whisper. My whisper. Your whisper.

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

1. **First Launch** — Grant microphone and accessibility permissions when prompted.
2. **Download Models** — Go to Settings > Models and download the STT/LLM models you want to use.
3. **Record** — Press `Ctrl+Shift+R` to start recording. Press again to stop and transcribe.
4. **Insert** — Corrected text is automatically inserted at your cursor position.
5. **Quick Fix** — If a word was misheard, select it and press `Ctrl+Shift+D` to save the correction.

### Settings

Access settings from the menu bar icon:

- **General** — Hotkey customization, recording mode, launch at login
- **STT** — Choose STT provider (WhisperKit, Groq, MLX Audio)
- **LLM** — Choose LLM provider (None, Local, OpenAI via Codex), correction mode
- **Models** — Model download and management

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Microphone permission
- Accessibility permission (for text insertion)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
