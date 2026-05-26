# batt-sail: Build, Release, and Homebrew Tap

## Build universal binary

```bash
make universal
```

Binary output: `dist/batt-sail`

## GitHub Release

1. Push source:
   ```bash
   git push -u origin main
   ```
2. Tag and release:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. Upload `dist/batt-sail` as a release asset.

## Homebrew Tap

`Formula/batt-sail.rb` is a HEAD formula for the app inside the MLKFS repo. If you publish a stable release formula, replace `head` with a real release tarball URL and SHA-256.

## End-user install

```bash
brew install --HEAD ./Formula/batt-sail.rb
```

## Typical runtime setup

```bash
sudo batt-sail preset desktop
sudo batt-sail daemon install
batt-sail status
sudo launchctl print system/com.mlkfs.batt-sail
```

The LaunchDaemon is bootstrapped automatically by `daemon install`;
explicit `daemon start` is not required. Use
`sudo batt-sail daemon uninstall` to bootout and remove the plist.
