# Release Process

This document describes the automated release process for Whispree.

## Version Management

Whispree follows [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward-compatible)
- **PATCH**: Bug fixes (backward-compatible)

## Automated Releases

Every push to the `main` branch triggers an automated release:

### Version Determination

The workflow automatically determines the version:

- **Manual version** (커밋 메시지에 `GO LIVE X.X.X` 포함):
  ```bash
  git commit -m "feat: new feature GO LIVE 2.0.0"
  git push origin main
  ```
  → 버전이 **2.0.0**으로 설정됩니다.

- **Auto-increment** (기본값, 커밋 메시지에 패턴 없음):
  ```bash
  git commit -m "fix: bug fix"
  git push origin main
  ```
  → 버전이 자동으로 **패치 증가** (1.0.0 → 1.0.1)

### Release Process

1. **Version Bump**: GitHub Actions가 버전을 결정하고 `Info.plist`를 업데이트한 후 커밋.
2. **Build**: macOS arm64용 앱 빌드 (현재 unsigned).
3. **Package**: `.zip` 및 `.dmg` 아카이브 생성.
4. **Release**: GitHub Release 생성 (semantic version 태그).
5. **Appcast**: Sparkle `appcast.xml` 생성 및 GitHub Pages 배포 (`/releases/appcast.xml`).

## Sparkle Auto-Updates

The app checks for updates automatically using Sparkle:
- **Feed URL**: `https://github.com/Arsture/whispree/releases/appcast.xml`
- **Update Check**: On app launch
- **Auto-Download**: Enabled (background download)
- **User Notification**: User is notified when update is ready to install

## Version Bump Examples

### Major Version (Breaking Changes)
```bash
git commit -m "feat!: complete redesign GO LIVE 2.0.0"
git push origin main
# → v2.0.0 릴리즈 생성
```

### Minor Version (New Features)
```bash
git commit -m "feat: add new STT provider GO LIVE 1.1.0"
git push origin main
# → v1.1.0 릴리즈 생성
```

### Patch Version (Bug Fixes - 자동)
```bash
git commit -m "fix: resolve crash on startup"
git push origin main
# → v1.0.1 릴리즈 자동 생성 (패치 증가)
```

**팁**: PR 제목에도 `GO LIVE X.X.X`를 포함하면 merge 시 자동으로 해당 버전으로 릴리즈됩니다.

## Code Signing (TODO)

Currently, releases are **unsigned**. To enable proper code signing:

1. Export your Apple Developer certificate as a `.p12` file.
2. Add GitHub secrets:
   - `APPLE_DEVELOPER_CERTIFICATE`: Base64-encoded `.p12` file
   - `APPLE_CERTIFICATE_PASSWORD`: Certificate password
   - `SPARKLE_PRIVATE_KEY`: EdDSA private key for signing appcast
3. Update `.github/workflows/release.yml` to use the certificate for signing.

## Homebrew Cask

The Homebrew Cask formula (`Casks/whispree.rb`) is already created. To publish:

### Option 1: Submit to official homebrew/cask

```bash
# Fork homebrew/cask
# Add Casks/whispree.rb to the fork
# Submit a PR to homebrew/homebrew-cask
```

### Option 2: Create a custom tap

```bash
# Create a new repo: Arsture/homebrew-whispree
# Add Casks/whispree.rb to the repo
# Users install with: brew tap Arsture/whispree && brew install --cask whispree
```

## Testing Releases

After a release is published:

1. **Download**: Download the `.zip` from GitHub Releases.
2. **Install**: Extract and move `Whispree.app` to `/Applications`.
3. **Test Auto-Update**: Launch the app, wait for update check.
4. **Homebrew**: Test installation via `brew install --cask whispree`.

## Current Version

- **v1.0.0**: Initial release with Sparkle auto-update support
