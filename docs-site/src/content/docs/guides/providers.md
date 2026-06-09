---
title: Providers
description: STT and LLM provider choices in Whispree.
---

Whispree uses protocol-based providers so transcription and correction can be switched without changing the recording flow.

## STT providers

| Provider | Where it runs | Use when | Notes |
| --- | --- | --- | --- |
| WhisperKit | Local CoreML / Neural Engine | You want local, low-latency transcription on Apple Silicon | Supports domain words through prompt tokens. |
| Groq | Cloud API | You want cloud transcription speed or fallback behavior | Requires network/API configuration. |
| MLX Audio | Local Python worker | You want MLX audio models through the `mlx-worker` pipe | Communicates over stdin/stdout JSON. |

## LLM providers

| Provider | Where it runs | Use when | Notes |
| --- | --- | --- | --- |
| None | Local passthrough | You want raw STT output | Fastest and safest baseline. |
| Local Text | Local MLX text model | You want local text correction | Uses a word-edit-distance safety threshold. |
| Local Vision | Local MLX VLM | You want screenshots to guide correction | Encodes selected screenshots and keeps token limits bounded. |
| OpenAI | Cloud API | You want high-quality correction through authenticated OpenAI access | Uses Codex auth first, OAuth fallback when configured. |

## Correction safety

Local correction providers use word-edit-distance safeguards to avoid replacing the whole transcript with hallucinated text. If correction diverges too far from the original transcript, Whispree should fall back to safer output.
