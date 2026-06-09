---
version: alpha
name: Whispree-docs-design
description: The design language for the Whispree public documentation site — a developer-docs surface that borrows Vercel's stark ink-on-near-white discipline (hairline dividers, mono technical labels, stacked-shadow elevation, dual pill/square button scales) but swaps the decorative system for Whispree's own signature — a cyan-to-blue "neon waveform" gradient drawn from the app's audio visualizer. Calm, fast, local-first, developer-native. Inspired by `/Users/arsture/Downloads/DESIGN-vercel.md` and the Vercel docs reference, not copied.

colors:
  primary: "#171717"
  on-primary: "#ffffff"
  ink: "#171717"
  body: "#4d4d4d"
  mute: "#888888"
  hairline: "#ebebeb"
  hairline-strong: "#a1a1a1"
  canvas: "#ffffff"
  canvas-soft: "#fafafa"
  canvas-soft-2: "#f5f5f5"
  link: "#0070f3"
  link-deep: "#0761d1"
  link-bg-soft: "#d3e5ff"
  accent: "#29bc9b"
  accent-bright: "#50e3c2"
  accent-soft: "#aaffec"
  accent-deep: "#0f7a63"
  success: "#0070f3"
  info: "#0070f3"
  error: "#ee0000"
  error-soft: "#f7d4d6"
  error-deep: "#c50000"
  warning: "#f5a623"
  warning-soft: "#ffefcf"
  warning-deep: "#ab570a"
  violet: "#7928ca"
  waveform-start: "#50e3c2"
  waveform-mid: "#0070f3"
  waveform-end: "#7928ca"
  selection-bg: "#171717"
  selection-fg: "#f2f2f2"
  # Dark theme (data-theme='dark') — polarity-flipped ink canvas
  dark-canvas: "#171717"
  dark-canvas-soft: "#1c1c1c"
  dark-canvas-2: "#222222"
  dark-ink: "#f5f5f5"
  dark-body: "#c7c7c7"
  dark-hairline: "#2a2a2a"
  dark-accent: "#50e3c2"
  dark-link: "#52a8ff"

typography:
  display-xl:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 44px
    fontWeight: 600
    lineHeight: 48px
    letterSpacing: -2.2px
  display-lg:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 32px
    fontWeight: 600
    lineHeight: 40px
    letterSpacing: -1.28px
  display-md:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 24px
    fontWeight: 600
    lineHeight: 32px
    letterSpacing: -0.96px
  display-sm:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 20px
    fontWeight: 600
    lineHeight: 28px
    letterSpacing: -0.6px
  body-lg:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 18px
    fontWeight: 400
    lineHeight: 30px
    letterSpacing: 0px
  body-md:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 16px
    fontWeight: 400
    lineHeight: 26px
  body-md-strong:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 16px
    fontWeight: 500
    lineHeight: 26px
  body-sm:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px
    letterSpacing: -0.28px
  body-sm-strong:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 14px
    fontWeight: 500
    lineHeight: 20px
    letterSpacing: -0.28px
  caption:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
  caption-mono:
    fontFamily: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
    letterSpacing: 0.02em
  code:
    fontFamily: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace
    fontSize: 13.5px
    fontWeight: 400
    lineHeight: 22px
  button-md:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 14px
    fontWeight: 500
    lineHeight: 20px
  button-lg:
    fontFamily: Inter, system-ui, -apple-system, sans-serif
    fontSize: 16px
    fontWeight: 500
    lineHeight: 24px

rounded:
  none: 0px
  xs: 4px
  sm: 6px
  md: 8px
  lg: 12px
  xl: 16px
  pill-sm: 64px
  pill: 100px
  full: 9999px

spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 40px
  3xl: 48px
  4xl: 64px
  5xl: 96px
  6xl: 128px
  section: 160px

components:
  nav-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    typography: "{typography.body-sm}"
    height: 64px
    padding: "{spacing.sm} {spacing.lg}"
  sidebar:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.body}"
    typography: "{typography.body-sm}"
    width: 18rem
    padding: "{spacing.lg} {spacing.md}"
  sidebar-link-active:
    backgroundColor: "{colors.link-bg-soft}"
    textColor: "{colors.link-deep}"
    indicator: "{colors.link}"
    typography: "{typography.body-sm-strong}"
    rounded: "{rounded.sm}"
    padding: "{spacing.xxs} {spacing.sm}"
  sidebar-group-label:
    textColor: "{colors.mute}"
    typography: "{typography.caption-mono}"
    textTransform: uppercase
  toc:
    textColor: "{colors.body}"
    activeColor: "{colors.ink}"
    indicator: "{colors.accent}"
    typography: "{typography.body-sm}"
  nav-cta:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.body-sm-strong}"
    rounded: "{rounded.sm}"
    padding: "0px {spacing.sm}"
    height: 32px
  search-box:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.body}"
    borderColor: "{colors.hairline}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: "0px {spacing.sm}"
    height: 36px
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-lg}"
    rounded: "{rounded.pill}"
    padding: "0px {spacing.lg}"
    height: 48px
  button-secondary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline-strong}"
    typography: "{typography.button-lg}"
    rounded: "{rounded.pill}"
    padding: "0px {spacing.lg}"
    height: 48px
  card:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  card-soft:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  code-block:
    backgroundColor: "{colors.canvas-soft-2}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    typography: "{typography.code}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  code-block-dark:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.code}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  inline-code:
    backgroundColor: "{colors.canvas-soft-2}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    typography: "{typography.code}"
    rounded: "{rounded.xs}"
    padding: "1px {spacing.xxs}"
  aside-note:
    backgroundColor: "{colors.link-bg-soft}"
    accentColor: "{colors.link}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  aside-tip:
    backgroundColor: "{colors.accent-soft}"
    accentColor: "{colors.accent-deep}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  aside-caution:
    backgroundColor: "{colors.warning-soft}"
    accentColor: "{colors.warning-deep}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  aside-danger:
    backgroundColor: "{colors.error-soft}"
    accentColor: "{colors.error-deep}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  badge:
    backgroundColor: "{colors.canvas-soft}"
    textColor: "{colors.body}"
    borderColor: "{colors.hairline}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "0px {spacing.xs}"
  badge-accent:
    backgroundColor: "{colors.accent-soft}"
    textColor: "{colors.accent-deep}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "0px {spacing.xs}"
  table:
    headerBackground: "{colors.canvas-soft}"
    headerTypography: "{typography.caption-mono}"
    bodyTypography: "{typography.body-sm}"
    cellPadding: "{spacing.xs} {spacing.sm}"
    rowBorder: "{colors.hairline}"
  hero-band:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.display-xl}"
    padding: "{spacing.5xl} {spacing.lg}"
  footer:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.body}"
    borderColor: "{colors.hairline}"
    typography: "{typography.body-sm}"
    padding: "{spacing.2xl} {spacing.lg}"
  link-inline:
    textColor: "{colors.link}"
    typography: "{typography.body-md}"

---


## Overview

Whispree's docs site is a developer-documentation surface, not a marketing page. It is read by engineers mid-task — installing, choosing a provider, debugging a permission, or reviewing a feature before release. So the visual system is built for *fast reading and fast scanning*, and it inherits Vercel's core discipline: a near-white `{colors.canvas-soft}` body, ink-near-black `{colors.ink}` text, a deliberate gray ladder where every divider/border/disabled state has its own step, mono for the technical layer, and stacked hairline-and-soft-shadow elevation instead of heavy drop shadows.

Where Whispree diverges — deliberately, so the docs read as *Whispree* and not as a Vercel clone — is the decorative system. Vercel's brand decoration is a four-pair mesh gradient. Whispree's is a single **neon-waveform gradient**: cyan `{colors.waveform-start}` → link-blue `{colors.waveform-mid}` → violet `{colors.waveform-end}`, a left-to-right sweep that echoes the app's `NeonWaveformView` audio visualizer. That gradient is the *entire* decorative system — it appears as the hero glow, as the active-link accent edge, and as a thin top-of-page hairline. It is never miniaturised to an icon and never used behind body text.

Type is the second voice. The display/body/button/label layer is set in a geometric sans (Inter, standing in for the proprietary Geist) at weights 400/500/600 — never 700. Technical labels (code, filenames, provider names, sidebar group eyebrows) are set in a monospaced face (JetBrains Mono). Headlines are sentence-case with aggressive negative tracking (`-2.2px` at the 44px hero). The brand never letter-spaces positively and never goes uppercase outside of mono labels.

Surfaces use a four-step ladder: `{colors.canvas}` (pure white for cards and code-block chrome), `{colors.canvas-soft}` (the page + sidebar body), `{colors.canvas-soft-2}` (inset code surfaces), and `{colors.primary}` (the deep ink used for the dark code-mockup band and as the entire dark-theme canvas). Dark mode is a true polarity flip to an ink canvas with a brighter cyan accent — not a muddy gray.

**Key Characteristics:**
- One black-ink primary action `{colors.primary}` carries the hero CTA, in a 100px pill `{rounded.pill}`. In-chrome controls (nav CTA, search) use the tight 6px `{rounded.sm}` square scale. The two scales coexist deliberately and never mix on the same control.
- A single cyan→blue→violet **neon-waveform gradient** is the only decorative chrome. It is the brand. Used at hero scale and as a 2px accent edge only.
- Interactive blue `{colors.link}` carries links and the active sidebar state — cyan is decorative, blue is the thing you click. (Cyan-on-white fails text contrast; never set body links or small UI text in cyan.)
- Section eyebrows, sidebar group labels, code, and filename captions are mono. Everything narrative is the geometric sans.
- Elevation is stacked: a 1px inset hairline ring plus two small soft offsets — never a single heavy blur.
- Asides carry semantic color (note=blue, tip=cyan, caution=amber, danger=red); body cards do not tint by status.

## Colors

### Brand & Accent
- **Ink** (`{colors.primary}` — `#171717`): The single primary-action color and the default text color on light surfaces. Carries the hero CTA pill, the dark code band, and the entire dark-theme canvas.
- **Accent Bright / Cyan** (`{colors.accent-bright}` — `#50e3c2`): Whispree's signature mint-cyan, pulled straight from the app's neon-waveform visualizer and favicon. Used as the start of the waveform gradient, the TOC active indicator, and the cyan tip-aside. Decorative — not a text/link color on light surfaces.
- **Accent / Cyan Deep** (`{colors.accent}` — `#29bc9b` / `{colors.accent-deep}` — `#0f7a63`): The darkened cyan used wherever cyan must carry *text* (tip-aside body, accent badge) to clear contrast on white and on `{colors.accent-soft}`.
- **Link Blue** (`{colors.link}` — `#0070f3`): The primary interactive color — inline links, active sidebar item, focus rings. The brand's "you can click this" signal.
- **Violet** (`{colors.violet}` — `#7928ca`): The closing stop of the waveform gradient. Decorative only.

### Surface
- **Canvas** (`{colors.canvas}` — `#ffffff`): Pure-white cards, dialogs, and the main reading column.
- **Canvas Soft** (`{colors.canvas-soft}` — `#fafafa`): The page background and the sidebar — 98% white.
- **Canvas Soft 2** (`{colors.canvas-soft-2}` — `#f5f5f5`): Inset code-block and inline-code surfaces, dropdown menus.
- **Hairline** (`{colors.hairline}` — `#ebebeb`): 1px dividers — table rows, card borders, the nav underline, code-block borders.
- **Hairline Strong** (`{colors.hairline-strong}` — `#a1a1a1`): Stronger divider / secondary-button border / deemphasised label.

### Text
- **Ink** (`{colors.ink}` — `#171717`): Every heading and body paragraph on light surfaces.
- **Body** (`{colors.body}` — `#4d4d4d`): Secondary text — sidebar inactive links, captions, table body, footer.
- **Mute** (`{colors.mute}` — `#888888`): Lowest-priority text — placeholders, fine print, sidebar group eyebrows.
- **On Primary** (`{colors.on-primary}` — `#ffffff`): Text on ink/dark surfaces.

### Semantic
- **Note / Link / Success** (`{colors.link}` — `#0070f3`): Informational asides and links share the brand blue.
- **Tip** (`{colors.accent-deep}` — `#0f7a63` on `{colors.accent-soft}`): The cyan-family aside — the one place cyan carries meaning.
- **Caution** (`{colors.warning}` — `#f5a623`, deep `{colors.warning-deep}` — `#ab570a`): Permission/fallback warnings, "planned/experimental" labels.
- **Danger / Error** (`{colors.error}` — `#ee0000`, soft `{colors.error-soft}`, deep `{colors.error-deep}`): Destructive notes, hard failures, "do not do this."

### Brand Gradient — Neon Waveform
Whispree's signature decoration is a single three-stop gradient:

- **Waveform** (`{colors.waveform-start}` `#50e3c2` → `{colors.waveform-mid}` `#0070f3` → `{colors.waveform-end}` `#7928ca`) — cyan to blue to violet, a left-to-right sweep mirroring the audio bars in `NeonWaveformView`.

Treat the gradient as one unified object: do not crop to a single color, do not reorder the stops, do not miniaturise it to an icon, and do not place it behind running text. It lives at hero scale (a soft blurred glow behind the landing headline) and as a 2px top-of-page / active-edge accent line. That is the whole decorative budget.

## Typography

### Font Family
Two faces carry the system:

1. **Geometric sans** (Inter, standing in for the proprietary Geist) — every display, body, button, link, and narrative label. Working weights are 400 / 500 / 600; the face never appears at 700+. Display sizes track aggressively negative (`-2.2px` at 44px, `-1.28px` at 32px); body is neutral or slightly negative.
2. **Monospace** (JetBrains Mono, standing in for Geist Mono) — code blocks, inline code, filenames, provider/command names, sidebar group eyebrows, and table headers. Weight 400 at 12–13.5px. Light positive tracking on the small caption-mono only.

### Hierarchy

| Token | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|
| `{typography.display-xl}` | 44px | 600 | 48px | -2.2px | Landing hero headline. |
| `{typography.display-lg}` | 32px | 600 | 40px | -1.28px | Page `h1` / section headlines. |
| `{typography.display-md}` | 24px | 600 | 32px | -0.96px | `h2` section headers. |
| `{typography.display-sm}` | 20px | 600 | 28px | -0.6px | `h3` sub-headers, card titles. |
| `{typography.body-lg}` | 18px | 400 | 30px | 0 | Lead paragraph under a page headline. |
| `{typography.body-md}` | 16px | 400 | 26px | 0 | Default docs body paragraph. |
| `{typography.body-md-strong}` | 16px | 500 | 26px | 0 | Bolded inline body. |
| `{typography.body-sm}` | 14px | 400 | 20px | -0.28px | Sidebar links, TOC, table body, captions. |
| `{typography.body-sm-strong}` | 14px | 500 | 20px | -0.28px | Active sidebar item, nav CTA, table emphasis. |
| `{typography.caption}` | 12px | 400 | 16px | 0 | Badge labels, footer fine print. |
| `{typography.caption-mono}` | 12px | 400 | 16px | 0.02em | Sidebar group eyebrows, table headers, technical captions. |
| `{typography.code}` | 13.5px | 400 | 22px | 0 | Code blocks, inline code, terminal snippets. |
| `{typography.button-md}` | 14px | 500 | 20px | 0 | Nav-scale button labels. |
| `{typography.button-lg}` | 16px | 500 | 24px | 0 | Hero pill button labels. |

### Principles
- **Negative tracking is part of the voice.** Display sizes carry `-2.2` to `-0.6px` tracking. Default tracking on headlines breaks the look.
- **Sentence-case headlines.** Never all-caps outside of mono eyebrows.
- **Mono is the technical layer only.** Code, filenames, provider names, sidebar eyebrows, table headers. Body paragraphs never set in mono.
- **Weight 600 is the display ceiling.** The sans never goes 700+. The page reads calmer for it.
- **Reading measure capped.** The content column holds ~52rem so prose never runs wider than a comfortable line.

### Note on Font Substitutes
The Vercel reference uses the proprietary Geist / Geist Mono. Whispree docs use open substitutes so the site stays static and dependency-light:
- **Geometric sans** — *Inter* (400/500/600); `font-feature-settings: "cv01","ss01"` nudges it toward Geist's geometric alternates. Loaded via the platform font stack first, with the system sans as the zero-latency fallback.
- **Monospace** — *JetBrains Mono* (400) at 12–13.5px. *SFMono / Menlo* is the system fallback.

## Layout

### Spacing System
- **Base unit**: 4px. Every spacing token is a multiple of 4.
- **Tokens**: `{spacing.xxs}` 4 · `{spacing.xs}` 8 · `{spacing.sm}` 12 · `{spacing.md}` 16 · `{spacing.lg}` 24 · `{spacing.xl}` 32 · `{spacing.2xl}` 40 · `{spacing.3xl}` 48 · `{spacing.4xl}` 64 · `{spacing.5xl}` 96 · `{spacing.6xl}` 128 · `{spacing.section}` 160.
- **Page rhythm**: the docs reading column uses `{spacing.lg}` between paragraphs and `{spacing.xl}`–`{spacing.2xl}` above section headers. The landing hero band breathes at `{spacing.5xl}`.
- **Card interior**: `{spacing.lg}`. Code-block interior: `{spacing.md}`.

### Grid & Container
- **Three-pane docs shell**: left sidebar (18rem) · content column (~52rem max) · right TOC. Collapses to a single scrolling column with a hamburger sidebar on mobile.
- **Content measure**: `--sl-content-width: 52rem` keeps prose readable; code blocks may bleed slightly wider via Starlight defaults.
- **Landing page**: `splash` template — centered hero, then a `CardGrid` of 2×2 feature cards (1-up on mobile).

### Whitespace Philosophy
The page reads as engineered: generous gaps *between* sections, tight stacks *inside* a card or a heading/paragraph pair. The waveform gradient does the decorative lifting at the hero; everywhere else, whitespace and the hairline ladder separate content. Never decorate where spacing will do.

### Responsive Strategy

| Name | Width | Key Changes |
|---|---|---|
| Mobile | < 50rem | Sidebar collapses to a hamburger drawer; TOC moves inline/top; CardGrid drops to 1-up; hero tightens to `{spacing.4xl}`. |
| Tablet | 50–72rem | Sidebar shows; TOC may hide; content holds measure. |
| Desktop | ≥ 72rem | Full three-pane shell; content centered at 52rem with sidebar + TOC flanking. |

Touch targets: nav CTA and sidebar rows inflate to a ≥40px tap height on mobile; the hero pill is 48px.

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| Level 0 — Flat | No shadow, no border. | Page body, hero band, dark code band. |
| Level 1 — Inset Hairline | `0 0 0 1px {colors.hairline}` inset ring. | Default card / code-block / table chrome — the universal "this is a surface" cue. |
| Level 2 — Subtle Drop | `0px 1px 1px #00000005, 0px 2px 2px #0000000a` + inset hairline. | Slightly raised cards (feature CardGrid). |
| Level 3 — Soft Stack | `0px 1px 1px #00000005, 0px 8px 24px #00000008` + inset hairline. | Hovered cards, popovers. |
| Level 4 — Float | `0px 2px 2px #0000000a, 0px 8px 16px -4px #0000000a` + inset hairline. | Search modal, dropdown menus. |

Elevation is STACKED — small layered offsets faking natural light — never a single 8px blur. An inset hairline ring is always present so the card edge stays crisp on `{colors.canvas-soft}`.

### Decorative Depth
- **Waveform gradient as atmosphere**: the hero glow is a blurred 2-D gradient backdrop, never a 3-D illustration.
- **Polarity-flipped dark band as depth**: switching a code mockup or the whole dark theme to `{colors.primary}` is the chief depth cue.
- **Inset + soft-drop combo**: an inset 1px ring plus a small drop makes a card "sit on the page" without feeling material-heavy.

## Shapes

| Token | Value | Use |
|---|---|---|
| `{rounded.none}` | 0px | Full-bleed hero / footer / the gradient accent line. |
| `{rounded.xs}` | 4px | Inline code, the tightest pill. |
| `{rounded.sm}` | 6px | In-chrome controls — nav CTA, sidebar active item, search box, form inputs. |
| `{rounded.md}` | 8px | Code blocks, asides, soft cards, table wrappers. |
| `{rounded.lg}` | 12px | Feature cards, larger callout panels. |
| `{rounded.xl}` | 16px | Image-capped cards. |
| `{rounded.pill}` | 100px | The hero CTA pill and any marketing-scale button. |
| `{rounded.full}` | 9999px | Badges, circular icon buttons, avatar chrome. |

## Components

### Documentation shell (Starlight-owned, themed here)
- **`nav-bar`** — sticky top bar, `{colors.canvas}` on a `{colors.hairline}` underline, 64px. Logo + title left, search center/right, GitHub + theme toggle right. A 2px waveform-gradient line may sit flush along the bottom edge.
- **`sidebar`** — `{colors.canvas-soft}`, 18rem. Group labels in `{typography.caption-mono}` uppercase `{colors.mute}`; links in `{typography.body-sm}` `{colors.body}`.
- **`sidebar-link-active`** — `{colors.link-bg-soft}` fill, `{colors.link-deep}` text, a `{colors.link}` left-edge indicator bar, `{rounded.sm}`.
- **`toc`** (right rail) — `{colors.body}` inactive, `{colors.ink}` active with a `{colors.accent}` indicator dot/edge. This is the one structural place cyan appears as a wayfinding cue.
- **`search-box`** — `{colors.canvas-soft}` fill, `{colors.hairline}` border, `{rounded.md}`, mono-ish placeholder; opens a Level-4 modal.

### Content blocks
- **`card` / `CardGrid`** — `{colors.canvas}`, `{colors.hairline}` border, `{rounded.lg}`, `{spacing.lg}` padding, Level 2 shadow. Title in `{typography.display-sm}`, body in `{typography.body-md}`. Used on the landing splash, 2-up/1-up.
- **`code-block`** — light variant on `{colors.canvas-soft-2}` with a `{colors.hairline}` border and a mono filename caption; dark variant `code-block-dark` on `{colors.primary}` for "this is what the terminal shows." `{rounded.md}`.
- **`inline-code`** — `{colors.canvas-soft-2}` fill, `{colors.hairline}` 1px border, `{rounded.xs}`, mono.
- **`table`** — header row on `{colors.canvas-soft}` in `{typography.caption-mono}`; body in `{typography.body-sm}`; `{colors.hairline}` row borders. Provider/permission matrices live here.
- **Asides** — `aside-note` (blue), `aside-tip` (cyan), `aside-caution` (amber), `aside-danger` (red): a soft tinted fill, a 3px accent left edge, `{rounded.md}`. Semantic color lives here, not in body cards.
- **`badge` / `badge-accent`** — small `{rounded.full}` metadata pills ("Local", "Cloud", "Planned"). Neutral by default; cyan-family for the Whispree-native highlight.

### Signature surfaces
- **`hero-band`** — the landing `splash` hero on `{colors.canvas}`, `{spacing.5xl}` vertical. Headline in `{typography.display-xl}` (sentence-case), tagline in `{colors.body}` `{typography.body-lg}`, then a CTA row: ink `button-primary` pill + `button-secondary` outline pill. The neon-waveform gradient sits behind as a soft blurred glow occupying the upper band.
- **`footer`** — `{colors.canvas}` on a `{colors.hairline}` top border, `{typography.body-sm}` `{colors.body}`. "Edit this page" / "Last updated" / prev-next links.

## Do's and Don'ts

### Do
- Reserve ink `{colors.primary}` for the single primary action and for body text. Black ink is the hero CTA.
- Use blue `{colors.link}` for everything clickable — links, active sidebar, focus. Cyan is decoration.
- Keep the neon-waveform gradient as hero-scale atmosphere and a 2px accent edge — nothing smaller.
- Set every code block, filename, provider name, sidebar eyebrow, and table header in the mono face.
- Layer stacked shadows (inset hairline + small offsets); cards sit, they don't float.
- Set headlines in `{typography.display-*}` weight 600, sentence-case, aggressive negative tracking.
- Use asides — not tinted body cards — to carry note/tip/caution/danger meaning.
- Make dark mode a true ink polarity flip with a brighter cyan accent.

### Don't
- Don't set body links, small UI text, or table text in cyan — it fails contrast on white. Darken to `{colors.accent-deep}` if cyan must carry text.
- Don't introduce a fifth decorative color. The system is ink + gray + blue + the one cyan→blue→violet gradient.
- Don't render the waveform gradient at icon scale, reordered, single-color, or behind running text.
- Don't render headlines all-caps or promote the sans to weight 700.
- Don't drop a single heavy shadow on cards; use the stacked + inset-hairline recipe.
- Don't mix the 100px pill scale and the 6px square scale on the same control.
- Don't tint body cards by status; status color belongs in asides/badges only.
- Don't set body paragraphs in the mono face.

---

## Appendix A — Docs information architecture (SSoT)

This file is both the visual contract *and* the docs design SSoT. The structural decisions below govern what the site contains and how new feature docs slot in.

- **Audience**: the public site is strictly USER-facing — "what Whispree does and how to use it," feature-first. Dev/release/contributing material is NOT a published page; it lives in `docs-site/CONTRIBUTING.md` and the repo's `CLAUDE.md`/`AGENTS.md`.
- **Bilingual (i18n)**: Korean is the root locale (`src/content/docs/**`); English lives under `/en/` (`src/content/docs/en/**`). Every page exists in both languages.
- **Primary navigation**: left sidebar grouped `시작하기/Start · 기능/Features · 참고/Reference`.
- **Core routes** (Korean root; English mirrored under `/en/…`):
  - `/` 개요 / Overview (splash)
  - `/getting-started/`
  - `/features/dictation/` · `/features/stt/` · `/features/correction/` · `/features/dictionary/` · `/features/context/` · `/features/models/`
  - `/reference/permissions/` · `/reference/shortcuts/` · `/reference/architecture/` (architecture stays light)
- **Page content order** (every feature page): user outcome → what it does / options (prefer tables) → when it runs / how to configure → what can fail → related pages.

## Appendix B — Content voice

- **Tone**: terse, operational, technically precise, no hype.
- **Terminology**: `Recording`, `Processing`, `Queued`, `Inserted`, `Copied`, `Provider`, `Permission`, `Target context`, `FIFO delivery`.
- **Every feature page answers**: what it does · when it runs · what can fail · how to verify.
- **Bilingual stance**: English-first; Korean is an open question (see below) tracked against Starlight i18n cost.

## Appendix C — Docs-update gate

Before any `dev → main` merge, production deploy, or release push: update the affected page under `docs-site/src/content/docs/**` **and its `/en/` mirror**, or add a new feature page via the template in `docs-site/CONTRIBUTING.md`, or write an explicit `No docs needed:` rationale in the commit/handoff. README-only updates do not satisfy this gate for user-facing feature, provider, permission, shortcut, or workflow changes. Full workflow: `docs-site/CONTRIBUTING.md`.

## Appendix D — Open questions

- [ ] Final production docs domain → sets `site` in `astro.config.mjs` + Vercel alias.
- [x] Bilingual Korean/English docs → **decided: Starlight i18n, Korean root + English `/en/`.**
- [ ] Whether to ship a real Geist/Geist Mono webfont vs. the Inter/JetBrains Mono substitutes (latency vs. fidelity trade-off).
