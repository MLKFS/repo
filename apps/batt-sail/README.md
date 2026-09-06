# batt-sail

A small macOS CLI that holds the battery inside a charge band — “sailing” —
to reduce wear on Intel MacBook Pros that mostly run on AC power.

batt-sail talks to the SMC directly. No `/usr/local/bin/smc`, no auto-downloaded
helpers, no `bclm` binary required at runtime.

> Primary target: Intel i9 MacBook Pro running macOS Monterey 12.x (T2).
> Apple Silicon CHWA is supported as a best-effort optional path.

---

## What sailing does

A naive “stop at 80%” limit causes micro-charging: charging stops at 80%,
the cell relaxes to 79%, charging resumes to 80%, repeat. Many cycles per day.

Sailing uses **hysteresis** between two thresholds:

```
maxPercent    e.g. 80   -- when battery reaches this, we lower the SMC limit
minPercent    e.g. 70   -- only when battery falls this low do we restore 100%
```

While the battery is anywhere between `minPercent` and `maxPercent`, batt-sail
does nothing. The result is one charge cycle every several days instead of
hundreds of micro-cycles per day.

On Intel, displayed battery percent can be a few points higher than the SMC
`BCLM` value. `intelDisplayCompensation` (default `3`) compensates for that
when lowering the limit, so a configured ceiling of 80% with min=70% writes
`BCLM=67` to stop charging, matching the `67 / 70` pattern from the temporary
bclm-sail shell script.

---

## Backends

| Hardware              | SMC key | Notes                                  |
| --------------------- | ------- | -------------------------------------- |
| Intel / T2 Mac        | `BCLM`  | Primary, fully supported               |
| Apple Silicon         | `CHWA`  | Best-effort; only 80 and 100 supported |

The native SMC client is adapted from [zackelia/bclm](https://github.com/zackelia/bclm)
and SMCKit (both MIT). See [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md).

---

## Build (Intel Monterey)

Requires Swift 5.7+ via Command Line Tools or Xcode.

```bash
cd apps/batt-sail
swift build -c release
sudo install -m 0755 .build/release/batt-sail /usr/local/bin/batt-sail
```

Universal binary:

```bash
make universal      # writes dist/batt-sail
sudo make install   # installs to /usr/local/bin/batt-sail
```

---

## Usage

```bash
batt-sail status                                # safe without sudo, reads SMC + pmset
batt-sail backend                               # show selected backend
batt-sail doctor                                # full environment check
sudo batt-sail custom --min 70 --max 80         # save a sailing band
sudo batt-sail custom --min 70 --max 80 --compensation 3
sudo batt-sail preset desktop                   # 70/80 with default compensation
sudo batt-sail enforce --dry-run                # show decision, no SMC write
sudo batt-sail enforce                          # apply the decision once
sudo batt-sail reset                            # restore BCLM=100
sudo batt-sail reset --remove-config            # also delete saved config
sudo batt-sail daemon install                   # install LaunchDaemon (6h interval)
sudo batt-sail daemon uninstall                 # bootout and remove the plist
sudo batt-sail uninstall                        # completely remove daemon, config, logs, binary and reset SMC to 100%
```

### Hysteresis rules

- `battery >= maxPercent` → write `max(40, minPercent − intelDisplayCompensation)`
  (Intel only; Apple Silicon CHWA writes 80).
- `battery <= minPercent` → write `100` to resume charging.
- otherwise → no SMC write.

A write is skipped if the current SMC value already equals the target, so a
daemon ticking every 6 hours produces zero unnecessary SMC writes when nothing
has changed.

---

## LaunchDaemon

```bash
sudo batt-sail daemon install
sudo launchctl print system/com.mlkfs.batt-sail
tail -n 20 /var/log/batt-sail.out
```

Installs `/Library/LaunchDaemons/com.mlkfs.batt-sail.plist`:

- `Label` — `com.mlkfs.batt-sail`
- `ProgramArguments` — `/usr/local/bin/batt-sail enforce`
- `RunAtLoad` — `true`
- `StartInterval` — `21600` (6 hours; override with `--interval`)
- `StandardOutPath` — `/var/log/batt-sail.out`
- `StandardErrorPath` — `/var/log/batt-sail.err`
- `chmod 644`, `chown root:wheel`
- Bootstrapped into the system domain idempotently
- Boots out any prior `com.mlkfs.batt-sail`, `com.battsail.daemon`, or
  `com.mlkfs.bclm-sail` daemon before installing.

`daemon uninstall` boots the daemon out and removes the plist. It does **not**
reset the charge limit — run `sudo batt-sail reset` explicitly if you want
`BCLM=100`.

---

## Uninstall

To completely remove `batt-sail` from your system:

```bash
sudo batt-sail uninstall
```

This single command:
1. Resets the SMC charge limit back to `100%` (safe charging state).
2. Unloads and removes the LaunchDaemon plist (`com.mlkfs.batt-sail.plist`).
3. Deletes saved configuration (`/Library/Application Support/batt-sail`).
4. Deletes daemon log files (`/var/log/batt-sail.*`).
5. Removes the binary from `/usr/local/bin/batt-sail`.

Alternatively, from the repository source folder:

```bash
sudo make uninstall
```

---

## Config

`/Library/Application Support/batt-sail/config.json`

```json
{
  "intelDisplayCompensation" : 3,
  "maxPercent" : 80,
  "minPercent" : 70,
  "mode" : "desktop"
}
```

Status and enforce read the same file. If it is missing, defaults
`min=70, max=80, intelDisplayCompensation=3` are used.

Legacy keys (`minLimit`, `maxLimit`, `compensateIntelOffset`) are still
honoured for backwards compatibility.

---

## Safety rules

- `min` must be in `[40, 99]`.
- `max` must be in `[41, 100]` and strictly greater than `min`.
- `intelDisplayCompensation` must be `>= 0` and `min − compensation >= 40`.
- SMC writes require root.
- A write is never issued if the current SMC value already equals the target.
- Unsupported macOS / hardware fails clearly; no fallback to random helpers.

---

## Test checklist (target Intel Monterey)

```bash
swift build -c release
sudo .build/release/batt-sail custom --min 70 --max 80
.build/release/batt-sail status
sudo .build/release/batt-sail enforce --dry-run
sudo .build/release/batt-sail enforce
sudo .build/release/batt-sail daemon install
sudo launchctl print system/com.mlkfs.batt-sail
tail -n 20 /var/log/batt-sail.out
# Optional: bclm read   # for comparison if zackelia/bclm is installed
```

---

## Troubleshooting

- **`SMC key BCLM was not found`** — your Mac is not Intel/T2, or the SMC is
  rejecting the key. Run `batt-sail doctor` to confirm architecture.
- **`This operation requires sudo/root privileges`** — re-run with `sudo`.
  Only writes require root; `status`, `backend`, `doctor` do not.
- **`error: 'batt-sail': Invalid manifest`** — your Command Line Tools install
  is broken. Run `xcode-select --install`, then
  `sudo xcode-select -s /Library/Developer/CommandLineTools`. Confirm with
  `swift --version` (should be 5.7+).
- **Old daemon still loaded** — `sudo batt-sail daemon install` automatically
  boots out `com.battsail.daemon` and `com.mlkfs.bclm-sail`.

---

## Caution

batt-sail manipulates a low-level SMC key that controls the battery charger.
It has been tested on Intel/T2 MacBook Pros but you should verify the value
with `pmset -g batt` and the displayed battery icon after the first run.
`sudo batt-sail reset` restores the default `BCLM=100` at any time.

---

## License / attribution

Project license: see repo root `LICENCE`.
Native SMC client adapted from MIT-licensed
[zackelia/bclm](https://github.com/zackelia/bclm) and SMCKit by beltex;
see [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md).
