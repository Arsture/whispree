---
title: Dictionary & Quick Fix
description: Boost recognition accuracy with domain word sets, fix misrecognitions on the spot with Quick Fix and register them, and sync via iCloud.
---

Registering the technical terms and proper nouns you use often improves dictation accuracy. And when a word is dictated incorrectly, you can fix it right where it is and add it to the dictionary immediately with **Quick Fix**.

## Domain word sets

Manage topic-based word groups under Settings → Dictionary. Each set has:

- **words** — injected as STT recognition hints, and at the same time used as the glossary for AI correction.
- **correction mappings** — `original → corrected` rules. Applied only during the AI correction step (not applied to STT).
- A per-set on/off toggle and word/mapping counts.

You can also add **default sets** in one shot: "IT/Dev" (~40 dev terms), "Statistics" (~24 statistics terms), and an empty "Custom".

:::note
Which STT engine accepts word hints depends on the engine — WhisperKit and MLX Audio use domain words for recognition. Mappings work when AI correction is enabled.
:::

## Quick Fix — instant correction + registration

When you spot a misrecognized word, fix it right away without having to dictate again.

1. Select the text to fix in any app.
2. Press **`Ctrl+Shift+D`**. (default shortcut)
3. Whispree grabs the selected text and opens a panel. Enter the correct word/mapping.
4. Press **Enter** to save: the text in the target app is replaced and registered in the dictionary at the same time. (Esc to cancel.)

Two modes:

- **Add mapping** *(default selection)* — saves `original → corrected` as an AI correction mapping (not applied to STT).
- **Add word** — adds the word to both the STT and AI correction dictionaries.

Registered items collect in an auto-created "Quick Fix" word set.

## Dictionary sync

Turning on **Dictionary sync** *(off by default)* under Settings → General syncs your word sets and Quick Fix words to **iCloud Drive** (or a JSON path you specify directly — Dropbox/Syncthing, etc.). Manual sync is also available via the "Import now / Export now" buttons. Useful for sharing the same dictionary across multiple Macs.
