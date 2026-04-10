# Whispree Design Role & Hierarchy System

## Purpose
이 문서는 Whispree의 색/재질/강조 사용을 **"같은 색으로 통일"** 하기 위한 문서가 아니라,
각 UI 요소가 맡는 역할(role), 중요도(hierarchy), 정보 성격(semantic), 상호작용 상태(interaction)에 따라
어떻게 시각적 우선순위를 배정할지를 정의하는 기준 문서다.

목표는 다음 두 가지를 동시에 만족하는 것이다.
1. **macOS에 자연스럽게 어울리는 차분하고 모던한 제품 감성**
2. **정보 역할이 분명한 인터페이스** — 사용자가 색이 아니라 구조로 먼저 이해하고, 색은 의미를 보강해야 한다.

---

## Source grounding
This system is grounded in Apple HIG and modern design-system practice.

### Primary sources
- Apple HIG — Hierarchy: https://developer.apple.com/design/human-interface-guidelines/
- Apple HIG — Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- Apple HIG — Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility

### Working inference from 2026 product design direction
- Modern interfaces are trending toward **intentional simplicity**, stronger semantic token systems, quieter surfaces, and clearer hierarchy rather than decorative color proliferation.
- For Whispree, this means: **structure first, color second**.

---

## Core principle

### 1. Hierarchy is not primarily color
Visual priority must be created in this order:
1. **layout / grouping**
2. **spacing / containment**
3. **typography**
4. **material / contrast / border**
5. **color**

If a screen only works because many elements are brightly colored, the hierarchy is weak.

### 2. Accent is for action, not decoration
Accent color is reserved for:
- current selection
- primary CTA
- active focus / key interaction
- key product affordance that should feel alive

Accent color must **not** be used just to make a card “look nicer.”

### 3. Semantic colors are for meaning, not branding
Success / warning / danger / info colors exist to communicate state meaning.
They must not be reused for arbitrary stylistic decoration.

### 4. Surfaces should be calm
Most of the app should feel quiet.
The UI should not visually compete with transcribed content.
Backgrounds and cards should mostly communicate containment and elevation, not mood.

### 5. Sidebar is a controlled exception
The left sidebar may keep stronger color identity and icon-based accent energy.
That exception must not leak into content panels.

---

## Visual role model

### A. Structural surfaces
Purpose: define layers and grouping.
Examples:
- window background
- section background
- card background
- inset well / field container
- overlay shell

Rules:
- use neutral materials/colors only
- use subtle border or material shift before tint
- no semantic color unless the whole container truly represents a status state

### B. Interactive accent
Purpose: tell the user where to look or what to act on.
Examples:
- selected nav item
- active provider row
- important CTA button
- focus ring / highlighted selection
- currently active product affordance

Rules:
- one main accent family only
- accent should appear sparse enough that it still feels important
- if everything is accented, nothing is accented

### C. Semantic state
Purpose: communicate outcome / health / risk.
Examples:
- ready / connected / success
- warning / needs attention / download required
- error / failure / blocked
- informational but non-dangerous system note

Rules:
- always pair semantic color with text/icon/shape
- never rely on color alone for meaning
- use semantic color locally at the indicator/badge/message level before tinting entire containers

### D. Content emphasis
Purpose: help the user scan information.
Examples:
- section title vs body text
- helper text
- metadata
- disabled text

Rules:
- solve with typography + neutral foreground hierarchy first
- avoid colorful text for ordinary labels
- colored text should be rare and meaningful

---

## Role-to-style mapping for Whispree

### Window / major content areas
- neutral background
- subtle card separation
- low tint, low drama
- content must feel readable and stable

### Dashboard cards / settings panels
- use surface tokens
- only use accent in controls, selected states, and key affordances
- warnings/errors should appear as badges, labels, or compact notices — not random tinted cards unless severity genuinely defines the whole block

### Overlays / floating panels
- should feel focused but calm
- allow slightly stronger contrast/material than main content
- semantic states may appear in icons, labels, and progress indicators, not in rainbow shells

### Onboarding
- can be slightly more expressive than settings
- still must obey role logic
- step progress = accent role
- permission state = semantic role
- instructional containers = surface role

### Menu bar / utility surfaces
- lightweight and glanceable
- color use should be sparse and role-driven
- status indicators can be semantic; action links can be accent

### Quick Fix / selection UIs
- emphasize task clarity over decoration
- source text / target text / warning should be differentiated by role meaning, not arbitrary hue choice

---

## Modernity criteria for Whispree
A screen is “modern” for this app when it feels:
- calm, not noisy
- intentionally grouped
- contrast-aware
- sparse with accent
- semantically consistent
- fast to scan
- macOS-native enough to feel trustworthy

A screen is **not** modern if it is merely:
- colorful
- gradient-heavy
- badge-heavy
- tinted in many unrelated hues
- dependent on color to create hierarchy

---

## Anti-patterns
Do not do the following:
- use different bright colors for neighboring cards that have no semantic difference
- use blue/orange/purple/green simply to create variety
- tint large containers with semantic colors when only a small badge/message needs emphasis
- use accent color for static labels
- use red text for general emphasis when there is no danger/error meaning
- create one-off view-local colors because a screen looks “boring”

---

## Implementation policy
When changing UI:
1. identify the element's role first
2. choose from: **surface / accent / semantic / text hierarchy**
3. use the matching token family
4. if no token fits, extend the token system centrally
5. do not solve hierarchy problems with extra colors before checking spacing / typography / grouping

---

## Designer / AI execution prompt
Use this prompt when evaluating or redesigning Whispree screens:

> Design this screen as a calm, modern macOS utility interface. Preserve the sidebar's product personality, but make the content area visually quieter and more systematic. Assign visual treatment by role: neutral surfaces for structure, one accent family for interaction/selection, semantic colors only for real state meaning, and typography/spacing for hierarchy before color. Remove decorative color variation. The result should feel trustworthy, focused, and immediately scannable.

Additional constraints:
- prefer subtle materials and borders over tinted panels
- use accent sparingly so it remains meaningful
- keep success/warning/error local and explicit
- if a block has no semantic meaning, it should not get a semantic color
- the user should understand where to look before noticing the palette

---

## Refactor target for next pass
The next implementation pass must answer these questions screen by screen:
1. What is the primary information on this screen?
2. Which elements are structure only?
3. Which elements are interactive accent?
4. Which elements genuinely carry semantic status?
5. Which colorful elements can be removed without hurting comprehension?

If a color cannot answer one of those questions, it probably should not exist.
