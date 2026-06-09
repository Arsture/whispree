# Contributing to Whispree docs

This is the **internal** contributor guide for the docs site. It is intentionally
*not* a published page — the public site (`src/content/docs/`) is user-facing only
(what Whispree does and how to use it). Dev/release process lives here and in the
repo's root `CLAUDE.md` / `AGENTS.md`.

## Structure

- Bilingual (Astro Starlight i18n): Korean is the root locale, English under `/en/`.
  - Korean source: `src/content/docs/**`
  - English source: `src/content/docs/en/**` (mirror the Korean path)
- Information architecture (sidebar groups, in `astro.config.mjs`):
  - **시작하기 / Start** — `index` (splash overview), `getting-started`
  - **기능 / Features** — `features/dictation`, `features/stt`, `features/correction`,
    `features/dictionary`, `features/context`, `features/models`
  - **참고 / Reference** — `reference/permissions`, `reference/shortcuts`, `reference/architecture`
- Design SSoT: `DESIGN.md` (token spec). Page voice: terse, operational, feature-first.

## The main-merge docs-update gate

Before any `dev → main` merge / production deploy / release push, if the change is
user-facing (a feature, provider, permission, shortcut, or workflow that a user can
see or configure), do ONE of:

1. Update the affected page(s) under `src/content/docs/**` **and** the English mirror
   under `src/content/docs/en/**`.
2. Add a new feature page using the template below (both languages).
3. If the change is internal-only, record a `No docs needed:` rationale in the commit
   or handoff.

A README-only update does not satisfy the gate. See the root `CLAUDE.md` /
`AGENTS.md` "docs-update gate" sections.

## Adding a feature page

1. Pick the right Features sub-page (or add a new `features/<name>.md`).
2. Lead with the user outcome. Answer, for each feature: **what it does · when it runs ·
   how to configure/trigger it · what can fail**. Prefer tables for option matrices.
3. Add the matching English page under `en/`, with internal links prefixed `/en/`.
4. If you added a new page, register it in the `sidebar` of `astro.config.mjs`
   (with a `translations: { en: '…' }` label).
5. Verify: `pnpm --dir docs-site build`.

### Feature page skeleton

```md
---
title: <기능 이름>
description: <한 줄 요약>
---

<이 기능으로 사용자가 무엇을 할 수 있는지 한두 문장.>

## 동작 / 옵션
| 옵션 | 하는 일 | 기본값 |
| --- | --- | --- |
| … | … | … |

## 언제 동작하나
<트리거 / 전제 조건.>

## 실패 / 주의
:::caution
<무엇이 실패할 수 있고, 사용자에게 어떻게 보이는지.>
:::
```

## Verify & deploy

```bash
pnpm --dir docs-site build      # build (astro check + astro build)
cd docs-site && vercel deploy --yes        # preview
cd docs-site && vercel deploy --prod --yes # production (intentional docs release only)
```

Ground every feature claim in the actual app code (`Whispree/**`, `AppSettings.swift`,
the Settings views, provider implementations). Do not document features that don't exist.
