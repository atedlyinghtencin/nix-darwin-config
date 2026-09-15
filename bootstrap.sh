#!/usr/bin/env bash
# One-shot setup for a fresh Mac. Safe to re-run: every step checks its own
# precondition, so a second run on a configured machine only rebuilds.
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
#
# /nix is a firmlink. The installer declares it in /etc/synthetic.conf and
# asks apfs.util to create it right away, but on a fresh macOS that request
# can silently do nothing until the next boot. The installer then mounts the
# "Nix Store" volume it just created onto a path that does not exist
# ("Volume on diskNsM failed to mount", "Error saving receipt: /nix
# Read-only file system") and leaves the volume behind; a plain re-run after
# the reboot makes a second one. Catch both states before the installer runs.
# Cleanup commands are the ones the installer itself prints
# (src/action/macos/encrypt_apfs_volume.rs in DeterminateSystems/nix-installer).
nix_preflight() {
  if [[ ! -d /nix ]] && grep -qE '^nix([[:space:]]|$)' /etc/synthetic.conf 2>/dev/null; then
    die "/etc/synthetic.conf declares /nix but the firmlink does not exist yet.
Reboot, then run ./bootstrap.sh again."
  fi

  local vol disk
  vol="$(diskutil list 2>/dev/null | awk '/APFS Volume Nix Store/ { print $NF; exit }')"
  if [[ -n "$vol" ]] && ! mount | grep -q ' on /nix '; then
    disk="${vol%s*}"
    cat >&2 <<EOF
error: an APFS volume "Nix Store" ($vol) exists but nothing is mounted on /nix,
most likely left behind by an earlier installer run. Remove it and its keychain
entry, then run ./bootstrap.sh again:

  sudo diskutil apfs deleteVolume $vol
  sudo security delete-generic-password -a "Nix Store" -s "Nix Store" -l "$disk encryption password" -D "Encrypted volume password"

Repeat the security command until it prints "The specified item could not be
found in the keychain". If deleteVolume fails with error -69888, run these
first:

  sudo launchctl bootout system/org.nixos.darwin-store
  sudo launchctl bootout system/org.nixos.nix-daemon
EOF
    exit 1
  fi
}

# A non-interactive bash does not read /etc/bashrc, so on a re-run Nix is
# installed but not on PATH until its profile is sourced here.
NIX_PROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
if [[ -r "$NIX_PROFILE" ]]; then
  # shellcheck disable=SC1090
  . "$NIX_PROFILE"
fi
if ! command -v nix >/dev/null 2>&1; then
  nix_preflight
  echo "==> Installing Nix…"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1090
  . "$NIX_PROFILE"
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
