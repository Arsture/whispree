---
title: Training data collection
description: Keep a record of your dictations on your Mac and export it as a zip when you need it.
---

For every dictation, Whispree can save the recording, the transcription, the AI correction, and what you changed after pasting — on your Mac only. It's meant for later fine-tuning STT or correction models to the way you speak. Nothing is sent anywhere.

## Turning it on

Settings → General → **학습 데이터** (Training data) → turn on **학습 데이터 모으기**. It's off by default.

## What is saved

| Item | Contents |
| --- | --- |
| Recording | Original audio (FLAC) |
| Transcription | STT engine and model, raw text, latency |
| AI correction | Provider and model, prompt used, output or failure reason |
| Paste | Pasted text, target app |
| Edits after paste | How the input field changed over 60 seconds, when Enter/Esc/Cmd+Z were pressed, final content |
| Screen | Screenshots taken while recording (when visual context is on) |
| Quick Fix | Text before and after the fix |

Password fields are never read. Keystrokes are not logged; only the moments Enter, Esc, and Cmd+Z were pressed are recorded.

## Where it's stored

`~/.whispree/dataset/` by default. It lives outside the app, so it survives updates and reinstalls. You can choose another folder in Settings.

## Export

**데이터 내보내기** (Export data) packs everything into one zip. By default it contains the recordings and text records only. Turn on **스크린샷과 입력창 기록 포함** (Include screenshots and input-field history) to include those too. The data on your Mac is left untouched.

:::caution
Some apps (Electron apps, some web pages) don't expose their input fields, so edits after pasting aren't recorded there. In terminals the whole screen is readable, so only the area around the cursor is saved.
:::
