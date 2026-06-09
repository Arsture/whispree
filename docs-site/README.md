# Whispree Docs Site

Nested Vercel-hosted documentation site for Whispree, built with Astro Starlight.

Current deployment: https://docs-site-azure-psi.vercel.app

## Why this stack

Whispree docs should feel like a static site: fast first load, simple Markdown updates, no server runtime, and a Vercel-docs-like information architecture. Astro Starlight gives the docs shell, search, sidebar, table of contents, Markdown/MDX, SEO, and static output without adopting a heavier Next.js docs app.

## Local commands

```bash
pnpm --dir docs-site install
pnpm --dir docs-site dev
pnpm --dir docs-site build
pnpm --dir docs-site preview
```

## Vercel deployment

Use a separate Vercel project connected to the existing `Arsture/whispree` repository.

Recommended dashboard settings:

- **Framework Preset**: Astro
- **Root Directory**: `docs-site`
- **Install Command**: `pnpm install --frozen-lockfile`
- **Build Command**: `pnpm build`
- **Output Directory**: `dist`

CLI path:

```bash
# From repository root, link the docs project in monorepo mode.
vercel link --repo

# Deploy this nested project after linking.
vercel docs-site

# Production deploy only when intentionally releasing docs.
vercel docs-site --prod
```

Vercel's monorepo guidance recommends selecting the project root directory for the app you want to deploy. The local `vercel.json` mirrors the dashboard settings so the nested project remains explicit.
