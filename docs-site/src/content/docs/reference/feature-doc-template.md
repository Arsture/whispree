---
title: Feature doc template
description: SSoT shape for future Whispree feature documentation.
---

Use this template when a Whispree feature is added, changed, or made user-visible. It keeps feature explanations out of README sprawl.

```md
# Feature: <name>

- Status: Draft | Active | Deprecated
- Last updated: YYYY-MM-DD
- Owner/surface: <app area, service, view, or provider>
- Related implementation: <file paths>

## User outcome
What can the user do after this feature exists?

## When it runs
What triggers it? What state must be true?

## Flow
1. Step one.
2. Step two.
3. Step three.

## Configuration
Settings, provider choices, environment variables, or permissions.

## Failure modes
- What can fail?
- What does the user see?
- What fallback keeps data safe?

## Verification
Commands, manual checks, screenshots, or route/app smoke tests.

## Release notes
One or two sentences suitable for changelog/release copy.

## Open questions
- [ ] Question / owner / impact
```

## Required update rule

Before `main` merge/deploy, every user-facing feature should either update its feature doc or include a clear `No docs needed:` rationale.
