---
title: Getting started
description: Install Whispree, grant permissions, and verify your first insertion.
---

Whispree is built for Apple Silicon Macs running macOS 14 or newer.

## 1. Build or install the app

For local development, generate the Xcode project after file-list changes and build the macOS target:

```bash
xcodegen generate
xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' build
```

When deploying a local debug build to `/Applications`, always choose the latest DerivedData output by modified time:

```bash
SRC=$(ls -td ~/Library/Developer/Xcode/DerivedData/Whispree-*/Build/Products/Debug/Whispree.app | head -1)
rm -rf /Applications/Whispree.app && cp -R "$SRC" /Applications/
open /Applications/Whispree.app
```

## 2. Grant permissions

Whispree needs macOS permissions for its core flows:

- Accessibility — paste text/images and send keyboard events.
- Screen Recording — capture context screenshots for vision correction.
- Automation — read/restore browser or terminal context through AppleScript when enabled.
- Microphone — record speech for STT.

See [Permissions](/guides/permissions/) for details.

## 3. Choose providers

Start with local defaults when possible:

- STT: WhisperKit for local CoreML transcription, or Groq/MLX Audio when selected.
- LLM: None for passthrough, Local Text/Vision for on-device correction, or OpenAI when authenticated.

See [Providers](/guides/providers/) for tradeoffs.

## 4. Verify insertion

1. Focus a text field in another app.
2. Trigger the recording hotkey.
3. Speak a short sentence.
4. Stop recording and wait for Whispree to insert or copy the result.

A successful run should preserve the target app and insert output in FIFO order when queued jobs exist.
