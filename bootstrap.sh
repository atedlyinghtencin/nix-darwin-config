#!/usr/bin/env bash
# One-shot setup for a fresh Mac. Safe to re-run.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/.config/nix-darwin"
HOSTNAME_FROM_FLAKE="$(sed -n 's/^[[:space:]]*hostname = "\(.*\)";.*/\1/p' "$SRC_DIR/flake.nix")"

die() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "this script is for macOS"
[[ -n "$HOSTNAME_FROM_FLAKE" && "$HOSTNAME_FROM_FLAKE" != "CHANGEME" ]] \
  || die "edit the vars block in flake.nix first"

# 1. Xcode Command Line Tools (git, compilers)
if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Installing Xcode Command Line Tools (accept the dialog)…"
  xcode-select --install
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
fi

# 2. Nix (Determinate installer: survives macOS upgrades, flakes on by default)
if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix…"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# 3. Put the repo where the `drs` alias expects it
if [[ "$SRC_DIR" != "$REPO_DIR" && ! -e "$REPO_DIR" ]]; then
  mkdir -p "$(dirname "$REPO_DIR")"
  ln -s "$SRC_DIR" "$REPO_DIR"
fi

# 4. First build: darwin-rebuild isn't installed yet, so run it from the flake.
# stdin is detached so nothing downstream can stop and prompt: Homebrew's
# y/n confirmations (e.g. `brew untap` on a tap with stuck formulae) only
# fire on a TTY and otherwise take their safe non-interactive default.
# sudo still works — it reads the password from /dev/tty, not stdin. -H
# resets HOME to root's, otherwise Nix warns that $HOME is not owned by root.
echo "==> Building and activating ${HOSTNAME_FROM_FLAKE}…"
sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_DIR#${HOSTNAME_FROM_FLAKE}" < /dev/null

echo
echo "Done. Open a new terminal. From now on use:  drs   (darwin-rebuild switch)"
