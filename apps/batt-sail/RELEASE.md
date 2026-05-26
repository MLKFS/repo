# batt-sail: Build, Release, and Homebrew Tap

## Build universal binary

```bash
make universal
```

Binary output: `dist/batt-sail`

## GitHub Release

1. Create a GitHub repo named `batt-sail`.
2. Push source:
   ```bash
   git remote add origin git@github.com:<username>/batt-sail.git
   git push -u origin main
   ```
3. Tag and release:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
4. Upload `dist/batt-sail` as a release asset.

## Homebrew Tap

1. Create repo `homebrew-batt-sail`.
2. Copy `Formula/batt-sail.rb` into that repo.
3. Replace `url` and `sha256` with your release tarball details.
4. Publish tap repo.

## End-user install

```bash
brew tap <username>/batt-sail
brew install batt-sail
```

## Typical runtime setup

```bash
sudo batt-sail preset desktop
sudo batt-sail daemon install
sudo batt-sail daemon start
batt-sail status
```
