# Whispree

> High-quality speech-to-text with LLM correction on macOS — practically free if you already have an OpenAI account.

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

### Near-Zero Cost

Groq offers free STT. OpenAI's GPT handles LLM correction for fractions of a cent per request. If you already use [Codex CLI](https://github.com/openai/codex), Whispree borrows your auth tokens — no extra setup, no extra billing.

That's it. That's the pricing model.

### Choose Your Providers

Like [OpenCode](https://github.com/nicepkg/opencode), but for voice. Mix and match STT and LLM providers to fit your workflow:

| | Cloud | Local |
|---|---|---|
| **STT** | [Groq](https://groq.com/) — free, fast | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — CoreML + ANE, fully offline |
| | | [MLX Audio](https://github.com/ml-explore/mlx-audio) — Qwen3-ASR via Python |
| **LLM** | [OpenAI](https://openai.com/) — GPT via Codex CLI auth | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — Qwen3-4B on-device |
| | | None — raw transcription, no correction |

### Supported Models

| Provider | Model |
|----------|-------|
| **WhisperKit** | `openai_whisper-large-v3_turbo` (CoreML + ANE optimized) |
| **MLX Audio** | `Qwen3-ASR-1.7B-8bit` (Python worker default, swappable with other mlx-audio models) |
| **Local LLM** | `Qwen3-4B-Instruct-2507-4bit` (mlx-swift-lm) |

### Built for Korean Developers Who Mix English

Whispree is optimized for **code-switching** — the way Korean developers actually talk. The LLM correction layer handles things like:

- `밸리데이션` -> `validation`
- `리엑트 컴포넌트에서 유즈 스테이트를 써야 돼` -> `React 컴포넌트에서 useState를 써야 돼`
- `깃허브에 PR 올려놨으니까 리뷰 좀 해줘` -> `GitHub에 PR 올려놨으니까 review 좀 해줘`

English-only mode works too. But let's be honest — this was built because no other STT app handles 한국어+English well.

### Smart Dictation

**Hotkeys:**
- `Ctrl+Shift+R` — Record (push-to-talk or toggle mode)
- `Ctrl+Shift+D` — Quick Fix: misheard a word? Save the correction to your personal dictionary
- `ESC` — Cancel anytime

**Correction Modes:**
| Mode | What it does |
|------|-------------|
| Standard | Fix STT errors — spacing, punctuation, misheard words |
| Filler Removal | Standard + strip fillers (음, 어, 그러니까, 뭐랄까) |
| Structured | Filler removal + organize into bullet points |
| Custom | Your own system prompt |

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
2. **Download Models** — Go to Settings > Models and download the STT/LLM models you want. Cloud providers (Groq, OpenAI) need no download.
3. **Record** — Press `Ctrl+Shift+R` to start recording. Press again (or release, in push-to-talk mode) to transcribe.
4. **Insert** — Corrected text is automatically pasted at your cursor in the previously active app.
5. **Quick Fix** — If a word keeps getting misheard, select it and press `Ctrl+Shift+D` to teach Whispree the right word.

### Settings

Access from the menu bar icon:

- **General** — Hotkey customization, recording mode (push-to-talk / toggle), launch at login
- **STT** — Choose provider: WhisperKit, Groq, MLX Audio
- **LLM** — Choose provider: None, Local (Qwen3), OpenAI (GPT). Pick a correction mode
- **Models** — Download and manage local models

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Microphone permission
- Accessibility permission (for automatic text insertion)

## The Name

I originally called it **FreeWhisper** — just a personal tool I hacked together in Swift. Nobody else was going to use it, so the name didn't matter.

When I decided to open-source it, I needed a proper name. Something "Oh My ..." felt dated. **OpenWhisper** was already taken.

Then I thought about how I was borrowing API keys like a cat borrowing someone's sunny spot — so **Not My Whisper** had a nice ring to it. But after using it every day, I got attached. *"Wait, this IS my whisper."*

So: **Whispree**. Free whisper. My whisper. Your whisper.

## Tips & Tricks

**The AirPods Gambit** — Wear AirPods and look mildly annoyed while speaking. Congratulations, you're now "on a call" and nobody will question you dictating your entire PR description out loud.

**The Zoom Maneuver** — Mute yourself on Zoom. Whisper into Whispree. Paste perfectly structured meeting notes before anyone finishes saying "can everyone see my screen?"

**The Subway Stare** — Public transport dictation requires commitment. Maintain the "important business call" face. The key is looking slightly stressed. Nobody bothers someone who looks stressed on a train.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
