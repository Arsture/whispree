---
title: STT engines
description: The three dictation engines — WhisperKit · Groq · MLX Audio, language selection, and silence auto-skip.
---

STT (Speech-to-Text) is the engine that turns speech into text. Whispree offers three of them, and you can **switch anytime** from Settings → STT or the home dashboard.

## Engine comparison

| Engine | Location | Model | Requirements | Notes |
| --- | --- | --- | --- | --- |
| **WhisperKit** *(default)* | Local (CoreML + Neural Engine) | `whisper-large-v3-turbo` (~1.5 GB) | Model download on first use | 99 languages, injects domain words as recognition hints. Works without internet. |
| **Groq Cloud** | Cloud | `whisper-large-v3-turbo` (server) | Groq API key | Very fast (~200ms). Converts audio to WAV and uploads. |
| **MLX Audio** | Local (Python worker) | `Qwen3-ASR-1.7B-8bit` (~1.0 GB) | `uv` installed | Strong in Korean/Chinese/Japanese/English. First load (cold start) ~1 min. Swappable to any mlx-audio model. |

:::tip
For the simplest start, leave it on **WhisperKit** (local, no setup needed). If you want a faster cloud option, get a key from [console.groq.com](https://console.groq.com) and use **Groq**. The Groq key is shared across both STT and correction.
:::

## Language

Pick the recognition language in Settings: **auto-detect** or ko · en · ja · zh · es · fr · de · pt.

- **Auto-detect** is convenient but can be less accurate, so a warning is shown. If you mostly speak one language, pinning that language is more accurate.
- WhisperKit has a correction step in auto-detect: if it mistakenly detects a language other than Korean/English/Japanese/Chinese, it retries once in Korean.

The selected language is also used to pick the AI correction prompt (Korean↔English code-switching, etc.). See [AI correction](/en/features/correction/).

## Silence auto-skip (VAD)

**Silence auto-skip** *(on by default)* in Settings → STT uses voice activity detection (VAD) to remove speechless segments before transcription. It applies to every STT engine, making transcription faster and cleaner, and shows a "skipping silence" indicator during recording.

## Domain word recognition

WhisperKit and MLX Audio take the domain words you register in the [dictionary](/en/features/dictionary/) as recognition hints, improving dictation accuracy for technical terms and proper nouns.
