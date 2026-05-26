#!/bin/sh
set -eu

REPO_URL="https://github.com/MLKFS/repo.git"
APP_PATH="apps/batt-sail"
INSTALL_PATH="/usr/local/bin/batt-sail"
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

need git
need swift
need sudo

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

echo "Fetching batt-sail..."
git clone --filter=blob:none --sparse --depth=1 "$REPO_URL" "$WORK_DIR/repo"
git -C "$WORK_DIR/repo" sparse-checkout set "$APP_PATH"

echo "Building batt-sail..."
cd "$WORK_DIR/repo/$APP_PATH"
swift build -c release

echo "Installing to $INSTALL_PATH..."
sudo install -m 0755 .build/release/batt-sail "$INSTALL_PATH"

echo "Installed:"
"$INSTALL_PATH" --help | sed -n '1,8p'

if [ ! -x /usr/local/bin/smc ]; then
  echo ""
  echo "Note: /usr/local/bin/smc was not found."
  echo "batt-sail installs successfully, but battery limit commands need an SMC utility."
fi
