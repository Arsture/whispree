---
title: Release process
description: Branch, deploy, and documentation rules for Whispree.
---

Whispree development happens on `dev`. The `main` branch is the deployment branch and should not be updated without an explicit release instruction.

## Branch rules

- Work on `dev` by default.
- Commit complete features/fixes only; avoid mid-feature commits.
- Do not merge or push to `main` unless the maintainer explicitly says to deploy, merge to main, or push main.

## Docs-update gate before main

Before merging/deploying to `main`, update documentation for any user-facing, architectural, provider, permission, release, or workflow change.

At minimum, do one of these:

1. Update the affected page under `docs-site/src/content/docs/`.
2. Add or update a feature SSoT using the [feature doc template](/reference/feature-doc-template/).
3. Record a short `No docs needed:` rationale in the handoff/commit when the change is internal-only.

## Docs deployment

The docs site is a nested Vercel project rooted at `docs-site`.

```bash
pnpm --dir docs-site build
vercel docs-site
vercel docs-site --prod
```

Use production deploy only when intentionally releasing docs.
