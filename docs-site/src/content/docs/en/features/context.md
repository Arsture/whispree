---
title: Visual Context & Restore
description: Pass your screen to a vision model during recording, and remember browser tabs and terminal sessions to paste back into exactly the right spot.
---

Whispree cares about both "what you're looking at while you speak" and "where the result should go". Visual context feeds vision-model correction; context restore handles the precise insertion location.

## Visual context (vision)

When using a vision-capable correction model, capturing the screen during recording and passing it to the model lets you get more accurate corrections that reflect the terms, code, and names on screen.

Settings → LLM (shown when a vision model is selected):

| Setting | What it does | Default |
| --- | --- | --- |
| **Enable screenshot context** | Captures the screen during recording (app switch / scroll / click debounced, up to 20 shots) and passes it to the vision model. **Requires Screen Recording permission.** | Off |
| **Pass to agent** | After inserting text, also pastes the captured screenshots into the target app as images. | Off |

**Capture works with intelligent debounce** — switching apps or scrolling/clicking resets the timer, and a 1.5-second pause triggers a capture (up to 20 shots, to protect memory).

### Screenshot selection panel
When transcription finishes, a panel appears for choosing which screenshots to paste (in FIFO order if multiple recordings are queued):

- **↑ ↓** to move · **Space** to select · **Enter** to confirm · **⌘Enter** to preview (Quick Look style) · **Esc** to skip.

### Instant toggle during recording (⌥)
While recording, **hold the left Option key for ~0.5 seconds** to toggle "attach screenshots to the target app" on and off. `Img Attach ON/OFF` flashes briefly in the overlay (only when a vision model is active).

## Context restore

The spot you were in when you started dictating is restored at insertion time. Rather than simply pasting into "whatever app is frontmost now", it returns to **the Chrome tab/input field or terminal session captured when recording started**.

### Browser restore (Chrome)
**Browser restore** *(on by default)* under Settings → General. It remembers the **Chrome tab and focused input element** at the start of recording, then returns to that tab and input field before inserting. If you keep typing or move the caret in the same input while processing runs, then switch away, Whispree re-reads Chrome's latest caret position right before insertion and pastes there.

- Chrome only. Requires Automation permission.
- Element-level cursor restore requires Chrome's "Allow JavaScript from Apple Events". Even with it off, **tab restore still works** (only element restore is skipped).

### Terminal restore (iTerm2 / tmux)
**Terminal restore** *(on by default)* under Settings → General. It remembers the **iTerm2 session (split pane)** and, if tmux is attached inside it, the **tmux window/pane** as well, then restores to that spot.

- iTerm2 only. Requires Automation permission. tmux supports only the default socket.
- Terminal.app · Alacritty · Kitty · Ghostty · Warp do not support split/session restore (app focus restore only).

:::note
Context restore is best-effort. Even if restore fails, the dictation result is still inserted.
:::

For the required permission setup, see [Permissions](/en/reference/permissions/).
