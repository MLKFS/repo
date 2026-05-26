# batt-sail

macOS battery charge limit CLI with presets, sailing mode, scheduling, and LaunchDaemon support.

## Install from source

```bash
git clone https://github.com/MLKFS/repo.git
cd repo/apps/batt-sail
make universal
sudo install -m 0755 dist/batt-sail /usr/local/bin/batt-sail
```

Then start with one preset:

```bash
sudo batt-sail preset cycle
batt-sail status
```

## STEP 1: Core Architecture & Hardware Bridge

- `HardwareBridge` reads battery state from `pmset -g batt`.
- Intel/T2 path uses SMC key `BCLM` via `smc -k BCLM`.
- Apple Silicon path uses SMC key `CHWA` via `smc -k CHWA`.
- Before writing any limit, `readCurrentLimit()` is called; no write occurs if already at target.

## STEP 2: CLI Logic & Hysteresis Engine

Commands:

- `batt-sail preset desktop` => min=50, max=55
- `batt-sail preset cycle` => min=60, max=80
- `batt-sail custom --max 80 --min 75`
- `batt-sail status`

Hysteresis enforcement:

- If battery >= max => set charge limit to `min` (halts active charging around band top).
- If battery <= min => set charge limit to `100` (resume charging until band ceiling hit next cycle).

`enforce` subcommand is intended for daemon invocation every 5 minutes.

## STEP 3: Scheduler Logic & LaunchDaemon Generator

Scheduler command:

```bash
batt-sail schedule --time 07:30 --days Mon,Tue,Wed,Thu,Fri --target 100
```

Implementation stores schedule metadata in `/Library/Application Support/batt-sail/config.json`.
Daemon cycle calls `maybePrimeForNextEvent()`:

- parses configured HH:MM
- computes a 120-minute lead window
- if current time is in `[event-2h, event]`, temporarily lifts limit to scheduler target.

Daemon commands:

```bash
sudo batt-sail daemon install
sudo batt-sail daemon start
sudo batt-sail daemon stop
```

`install` generates `/Library/LaunchDaemons/com.battsail.daemon.plist` and bootstraps it with `launchctl`.

## STEP 4: Build, GitHub Release & Homebrew Tap

### Build universal binary

```bash
make universal
```

### GitHub + Homebrew publishing

See [`RELEASE.md`](./RELEASE.md) for full steps and formula template under `Formula/batt-sail.rb`.

## Dependencies

- Apple `swift-argument-parser`
- An installed `smc` utility at `/usr/local/bin/smc` (from a trusted open-source SMC toolchain such as `smcFanControl`/`smc` CLI builds).

## Notes

- Root privileges are required for SMC writes and LaunchDaemon install.
- This project targets macOS 12+
