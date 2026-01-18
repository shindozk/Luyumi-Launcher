# GitHub Actions

## Build and Release Workflow

The `release.yml` workflow automatically builds the launcher for all platforms.

### Triggers

| Trigger | Builds | Creates Release |
|---------|--------|-----------------|
| Push to `main` | Yes | No |
| Push tag `v*` | Yes | Yes |
| Manual dispatch | Yes | No |

### Platforms

All builds run in parallel:

- **Linux** (ubuntu-latest): AppImage, deb
- **Windows** (windows-latest): NSIS installer, portable exe
- **macOS** (macos-latest): Universal DMG (Intel + Apple Silicon)

### Creating a Release

1. Update version in `package.json`
2. Commit and push to `main`
3. Create and push a version tag:

```bash
git tag v2.0.1
git push origin v2.0.1
```

The workflow will:
1. Build all platforms in parallel
2. Upload artifacts to GitHub Release
3. Generate release notes automatically

### Build Artifacts

After each build, artifacts are available in the Actions tab for 90 days:

- `linux-builds`: `.AppImage`, `.deb`
- `windows-builds`: `.exe`
- `macos-builds`: `.dmg`, `.zip`, `latest-mac.yml`

### Local Development

Build locally for your platform:

```bash
npm run build:linux
npm run build:win
npm run build:mac
```

Or build all platforms (requires appropriate OS):

```bash
npm run build:all
```
