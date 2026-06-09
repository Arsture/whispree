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

This docs site is a **separate Vercel project** (`docs-site`) so the macOS app
repo never deploys as a whole. Framework/build settings live in `vercel.json`
(Astro · `pnpm install --frozen-lockfile` · `pnpm build` · output `dist`).

Two deploy paths, depending on the project's **Root Directory** setting:

### A. CLI deploy from this folder (current setup, Root Directory = `.`)

The linked project uses Root Directory `.`, so deploys run from *inside*
`docs-site/`, uploading only this folder:

```bash
cd docs-site
vercel deploy --yes          # preview
vercel deploy --prod --yes   # production (intentional docs release only)
```

`vercel link --yes --project docs-site` (run once from `docs-site/`) recreates
the local `.vercel/` link if it is missing.

### B. GitHub push-to-deploy (Root Directory = `docs-site`)

If you later connect the project to the `Arsture/whispree` GitHub repo for
automatic preview/production deploys on push, change the project's **Root
Directory to `docs-site`** in the dashboard so Vercel builds this nested folder
instead of the repo root. Do not mix the two: Root Directory `.` is for CLI
deploys from inside `docs-site/`; `docs-site` is for repo-root Git builds.

Production deploys should follow the docs-update gate in
[`/reference/release-process`](./src/content/docs/reference/release-process.md).
