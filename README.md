# Whispree

> Get SuperWhisper-quality STT for practically free if you already have an OpenAI account.

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

### Nearly Free

STT uses Groq, LLM borrows Codex OAuth.  
Groq STT is free, and OpenAI LLM correction uses [Codex CLI](https://github.com/openai/codex) auth tokens directly.  
If you have an OpenAI account, you get high-quality STT + LLM correction with virtually no additional cost.

### Choose Your Providers

Wants to be [OpenCode](https://github.com/nicepkg/opencode). Still a long way to go, but you can pick and choose STT and LLM providers.

| | STT | LLM |
|---|---|---|
| **Cloud (Recommended)** | [Groq](https://groq.com/) — accurate, fast | [OpenAI via Codex CLI](https://github.com/openai/codex) — use your existing account |
| **Local** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — decent accuracy, a bit slow | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — slow and underwhelming |
| **Local** | [MLX Audio](https://github.com/ml-explore/mlx-audio) — less accurate, slightly faster | — |

### Supported Models

| Provider | Model |
|----------|-------|
| **Groq (Cloud STT)** | `whisper-large-v3-turbo` |
| **OpenAI (Cloud LLM)** | `gpt-5.4` (default), `gpt-5.4-mini`, `gpt-5.3-codex`, `gpt-5.3-codex-spark`, `gpt-5.2-codex` |
| **WhisperKit (Local STT)** | `openai_whisper-large-v3_turbo` (CoreML + ANE optimized) |
| **MLX Audio (Local STT)** | `Qwen3-ASR-1.7B-8bit` (Python worker default, swappable with other mlx-audio models) |
| **Local LLM** | `Qwen3-4B-Instruct-2507-4bit` (mlx-swift-lm) |

### Code-Switching Optimization

Built for Korean developers who mix English. LLM correction handles Korean + English tech terms:

```
"밸리데이션 해야 되거든"  →  "validation 해야 되거든"
"리엑트 컴포넌트"        →  "React 컴포넌트"
"깃허브에 PR 올려놨어"   →  "GitHub에 PR 올려놨어"
```

### Smart Dictation

- **Record** — `Ctrl+Shift+R`. Push to Talk (hold to record) or Toggle (press once to start, again to stop) modes
- **Quick Fix** — `Ctrl+Shift+D`. Add misheard words to correction dictionary & Replace
- **Cancel** — `ESC`. Cancel anytime during recording

### Correction Modes

| Mode | Description |
|------|-------------|
| Standard | Fix STT errors — spacing, spelling, misheard words |
| Filler Removal | STT correction + remove fillers (um, uh, like, you know) |
| Structured (for Prompt) | STT correction + filler removal + organize into bullet points |
| Custom | Your own custom system prompt |

## Installation

### Homebrew Cask (Recommended)

```bash
brew install --cask whispree
```

### GitHub Releases

Download the latest `.zip` from [GitHub Releases](https://github.com/Arsture/whispree/releases). The app is not notarized, so on first launch: right-click > Open to bypass Gatekeeper.

> **Note:** `.dmg` is also available but may be blocked by macOS Gatekeeper. Use the `.zip` instead.

### Build from Source

```bash
git clone https://github.com/Arsture/whispree.git
cd whispree
brew install xcodegen
xcodegen generate
open Whispree.xcodeproj
# Build and run with Cmd+R in Xcode
```

SPM dependencies are resolved automatically on first build.

## Usage

### Basic Flow

1. **First Launch** — Grant microphone and accessibility permissions.
2. **Download Models** — Go to Settings > Models and download the STT/LLM models you want. (Not needed for cloud providers)
3. **Record** — Press `Ctrl+Shift+R` to record. When done, transcription + correction happens automatically.
4. **Insert** — Corrected text is automatically pasted at the cursor position in your previously active app.

### Quick Fix

If a word keeps getting misheard, register it with `Ctrl+Shift+D`. Build domain word sets (programming, medical, etc.) to improve recognition for specific terminology.

### Settings

Access from the menu bar icon:

- **General** — Change hotkeys, recording mode (Push to Talk / Toggle), launch at login
- **STT** — Choose STT provider (WhisperKit, Groq, MLX Audio)
- **LLM** — Choose LLM provider (None, Local Qwen3, OpenAI via Codex), set correction mode
- **Models** — Download and manage local models

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Microphone permission
- Accessibility permission (required for automatic text insertion)

## The Name

> It started as **FreeWhisper**. Just a tool for me, so I built it in Swift for Mac.
>
> When I decided to open-source it, FreeWhisper felt cheap. "Oh My ..." series felt dated, and **OpenWhisper** seemed taken.
>
> I thought about borrowing API keys — borrowed cat? Borrowed Whisper? **Not My Whisper**!? (Not cute anymore) came to mind.
>
> But as I kept using it, I got attached. *"Wait, this IS my whisper."*
>
> So it became **Whispree**.

## Tips

> **Office Worker Tip**: Wear AirPods and pretend you're on a call. Nobody will think you're talking to objects.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
