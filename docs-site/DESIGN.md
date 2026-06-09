# Whispree Docs Design

## Source of truth
- Status: Active draft for the public docs website
- Last refreshed: 2026-06-09
- Primary product surfaces: public docs landing page, getting-started docs, concept/guides/reference pages, feature SSoT pages.
- Evidence reviewed:
  - `/Users/arsture/Downloads/DESIGN-vercel.md` — Vercel-inspired tokens, typography, surfaces, gradients, and developer-docs interaction language.
  - `DESIGN.md` — Whispree app design contract: calm, fast, invisible-until-needed, developer-native, macOS-native.
  - `AGENTS.md` and `CLAUDE.md` — branch/deploy discipline and architecture constraints future docs must preserve.
  - Vercel docs reference provided by user — desired docs feel: product-grade, sidebar-first, searchable, fast, developer-native.

## Brand
- Personality: fast, precise, quiet, local-first, developer-native.
- Trust signals: transparent provider choices, explicit permission requirements, no hidden cloud dependency, clear fallback behavior.
- Avoid: marketing fluff, oversized screenshots without explanation, noisy gradients, README-like dumping grounds.

## Product goals
- Goals:
  - Make Whispree understandable as a voice-to-prompt system in under two minutes.
  - Keep feature explanations close to implementation decisions so future updates have an SSoT beyond README.
  - Support Vercel preview deployments for docs changes before `main` release.
- Non-goals:
  - Replacing root `README.md` entirely.
  - Hosting private roadmap/spec material that should remain internal.
  - Adding dynamic docs runtime before there is a concrete need.
- Success signals:
  - A new user can install, grant permissions, choose providers, and understand insertion behavior from the docs.
  - Every user-facing feature has a canonical page or SSoT template entry.
  - Vercel preview deploys make docs review fast before main merge/deploy.

## Personas and jobs
- Primary personas: Korean/English code-switching developers using Whispree with Cursor, Claude, ChatGPT, terminals, browsers, and other prompt surfaces.
- User jobs:
  - Install and run Whispree safely on Apple Silicon.
  - Understand which local/cloud providers are active and why.
  - Debug permissions or insertion failures without reading Swift code.
  - Review what changed in a feature before deploying main.
- Key contexts of use: docs during setup, feature review before release, troubleshooting while the app is open.

## Information architecture
- Primary navigation: left sidebar grouped as Start, Concepts, Guides, Reference.
- Core routes/screens:
  - `/` Overview
  - `/getting-started/`
  - `/concepts/architecture/`
  - `/guides/providers/`
  - `/guides/permissions/`
  - `/reference/release-process/`
  - `/reference/feature-doc-template/`
- Content hierarchy:
  1. Outcome: what this page helps the user do.
  2. Facts: current behavior and constraints.
  3. Steps/decisions: what to choose or execute.
  4. Verification: how to know it worked.
  5. Related SSoT: what must be updated next time.

## Design principles
- Principle 1: Docs are operational. Every page should help install, decide, debug, verify, or release.
- Principle 2: Static-first. Prefer Markdown and build-time content; add client JavaScript only when it clarifies a task.
- Principle 3: Vercel-inspired, not Vercel-copied. Use ink/white, hairlines, mono labels, and restrained mesh accents while preserving Whispree's calm app personality.
- Principle 4: SSoT over README sprawl. New features should update a specific docs page or feature doc entry, not only the README.
- Tradeoffs: Starlight constrains custom layout, but that constraint keeps docs fast and maintainable.

## Visual language
- Color: near-white canvas `#fafafa`, white cards, ink `#171717`, body gray `#4d4d4d`, hairline `#ebebeb`, link blue `#0070f3`, restrained cyan/violet/pink/amber mesh accents at hero scale only.
- Typography: system/Inter-like sans for prose; mono only for commands, filenames, provider labels, and technical captions.
- Spacing/layout rhythm: generous section breathing room; tight card interiors; 4px-based rhythm inherited from the Vercel reference.
- Shape/radius/elevation: subtle rounded cards, hairline borders, very soft shadows; avoid heavy floating cards.
- Motion: minimal; no animation required for docs comprehension.
- Imagery/iconography: waveform/mic/context metaphors are acceptable; avoid decorative screenshots unless annotated.

## Components
- Existing components to reuse: Astro Starlight sidebar, search, cards, steps, asides, table of contents, code blocks.
- New/changed components: only add custom components when repeated Whispree-specific patterns emerge, such as provider matrices or permission checklists.
- Variants and states: info/warning/danger asides for permission and fallback behavior; success asides for verification.
- Token/component ownership: `docs-site/src/styles/custom.css` owns site-level style overrides. Root app SwiftUI tokens remain in the Whispree app, not this docs site.

## Accessibility
- Target standard: semantic, keyboard-navigable docs with readable contrast.
- Keyboard/focus behavior: preserve Starlight defaults for sidebar/search/focus.
- Contrast/readability: do not rely on gradient text for meaning; all critical content must be plain text.
- Screen-reader semantics: use headings in order and avoid fake list/card structures.
- Reduced motion and sensory considerations: no required motion.

## Responsive behavior
- Supported breakpoints/devices: desktop docs first, readable mobile docs second.
- Layout adaptations: Starlight sidebar collapses on small screens; content must still read linearly.
- Touch/hover differences: hover cannot be the only way to discover critical guidance.

## Interaction states
- Loading: static pages should load without app-specific skeletons.
- Empty: future sections can say “not documented yet” only in drafts, not production-ready pages.
- Error: build errors are caught in CI/local build; public docs should avoid broken internal links.
- Success: verification blocks should end setup/release pages.
- Disabled: unavailable future features must be labelled planned, experimental, or not supported.
- Offline/slow network: generated static pages should remain usable after initial load where browser cache allows.

## Content voice
- Tone: terse, operational, technically precise, no hype.
- Terminology: use “Recording”, “Processing”, “Queued”, “Inserted”, “Copied”, “Provider”, “Permission”, “Target context”.
- Microcopy rules: every feature page should answer “what it does”, “when it runs”, “what can fail”, and “how to verify”.

## Implementation constraints
- Framework/styling system: Astro Starlight in `docs-site/`, Markdown/MDX content, static `dist` output.
- Design-token constraints: use `src/styles/custom.css`; do not fork Starlight theme unless repeated constraints prove necessary.
- Performance constraints: no server rendering; no client-heavy widgets in the baseline docs.
- Compatibility constraints: Vercel project root must be `docs-site`; root Whispree app build remains independent.
- Test/screenshot expectations:
  - `pnpm --dir docs-site build`
  - route smoke against `astro preview`
  - Vercel preview URL check when CLI/project auth is available

## Open questions
- [ ] Final production docs domain. Owner: maintainer. Impact: set `site` in `astro.config.mjs` and Vercel domain aliases.
- [ ] Whether docs should be bilingual Korean/English. Owner: maintainer. Impact: Starlight i18n structure and content maintenance cost.
