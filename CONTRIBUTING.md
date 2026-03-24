# Contributing to Whispree

Thanks for your interest in contributing!

## Quick Start

1. Fork & clone the repo
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
3. Generate the Xcode project: `xcodegen generate`
4. Build: `xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' build`
5. Run tests: `xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' test`

## Pull Requests

- Branch from `dev`
- Keep PRs focused — one feature or fix per PR
- Ensure the build passes before submitting
- Use [conventional commits](#commit-convention) for commit messages

## Commit Convention

| Prefix | Use |
|--------|-----|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `refactor:` | Code change that neither fixes a bug nor adds a feature |
| `docs:` | Documentation only |
| `chore:` | Build process, dependencies, or tooling |
| `test:` | Adding or updating tests |

### Version Bumps

Include `GO LIVE X.X.X` in your commit message or PR title to set a specific release version:

```
feat: add new STT provider GO LIVE 1.1.0
```

Without `GO LIVE`, the patch version auto-increments on merge to `main`.

## Project Structure

```
Whispree/
├── App/            # Entry point, AppDelegate, AppState
├── Models/         # Data models, settings
├── Services/       # Audio, STT, LLM, TextInsertion, Hotkey
├── Coordinators/   # Pipeline orchestration
├── Views/          # SwiftUI UI layer
└── Resources/      # Assets, Info.plist, entitlements
```

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (arm64)
- Xcode 16.0+
- Swift 5.9
