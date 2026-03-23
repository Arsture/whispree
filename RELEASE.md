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

1. **Version Bump**: GitHub Actions reads `CFBundleVersion` from `Info.plist`, increments the patch version, and commits the change.
2. **Build**: Builds the app for macOS arm64 (unsigned for now).
3. **Package**: Creates `.zip` and `.dmg` archives.
4. **Release**: Creates a GitHub Release with semantic version tag (e.g., `v1.0.1`).
5. **Appcast**: Generates Sparkle `appcast.xml` and deploys to GitHub Pages (`/releases/appcast.xml`).

## Sparkle Auto-Updates

The app checks for updates automatically using Sparkle:
- **Feed URL**: `https://github.com/Arsture/whispree/releases/appcast.xml`
- **Update Check**: On app launch
- **Auto-Download**: Enabled (background download)
- **User Notification**: User is notified when update is ready to install

## Manual Release Steps

For major/minor version bumps, manually update `Info.plist` before pushing to `main`:

```bash
# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2.0.0" Whispree/Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 2.0.0" Whispree/Resources/Info.plist

# Commit and push
git add Whispree/Resources/Info.plist
git commit -m "chore: bump version to 2.0.0"
git push origin main
```

GitHub Actions will handle the rest (build, package, release, appcast).

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
