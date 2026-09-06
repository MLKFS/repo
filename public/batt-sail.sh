#!/bin/sh
set -eu

INSTALL_PATH="/usr/local/bin/batt-sail"
BIN_URL="https://mlkfs.com/downloads/batt-sail-darwin-universal"
BIN_SHA256="e995533eeedb018d5010946f4ccf8885a3f920db4927f715f200536d54dd6327"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/batt-sail.XXXXXX")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [ "$(uname -s)" != "Darwin" ]; then
  echo "batt-sail installer is for macOS only." >&2
  exit 1
fi

need curl
need shasum
need sudo

BIN_PATH="$WORK_DIR/batt-sail"

echo "Downloading batt-sail..."
curl -fsSL "$BIN_URL" -o "$BIN_PATH"

ACTUAL_SHA256="$(shasum -a 256 "$BIN_PATH" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$BIN_SHA256" ]; then
  echo "Checksum mismatch while downloading batt-sail." >&2
  echo "Expected: $BIN_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

echo "Installing to $INSTALL_PATH..."
sudo install -m 0755 "$BIN_PATH" "$INSTALL_PATH"

echo "Installed:"
"$INSTALL_PATH" --help | sed -n '1,8p'
