#!/usr/bin/env bash
# One-shot setup for a fresh Mac. Safe to re-run: every step checks its own
# precondition, so a second run on a configured machine only rebuilds.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/.config/nix-darwin"
flake_var() { sed -n "s/^[[:space:]]*$1 = \"\(.*\)\";.*/\1/p" "$SRC_DIR/flake.nix"; }
HOSTNAME_FROM_FLAKE="$(flake_var hostname)"
USERNAME_FROM_FLAKE="$(flake_var username)"

die() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "this script is for macOS"
# Never as root: Nix refuses a checkout owned by someone else (libgit2
# "repository path is not owned by current user") and Homebrew must run as
# the normal user. The script escalates with sudo itself where it has to.
[[ $EUID -ne 0 ]] || die "run this as your normal user, not with sudo; it escalates on its own where needed"
[[ -n "$HOSTNAME_FROM_FLAKE" && "$HOSTNAME_FROM_FLAKE" != "CHANGEME" ]] \
  || die "edit the vars block in flake.nix first"

# 0. Identity. The flake names the macOS account and the machine. A mismatch
# only surfaces deep inside the first build ("primary user X does not exist",
# then home-manager's 'USER is "Y", expected "X"'), so compare up front.
current_user="$(id -un)"
if [[ "$USERNAME_FROM_FLAKE" != "$current_user" ]]; then
  cat >&2 <<EOF
error: flake.nix has username = "$USERNAME_FROM_FLAKE" but you are logged in as "$current_user".
Either edit the vars block in flake.nix:

  username = "$current_user";

or rename the macOS account to "$USERNAME_FROM_FLAKE" (log in as a different
admin, System Settings > Users & Groups > right-click the user > Advanced
Options: account name and home folder), then run ./bootstrap.sh again.
EOF
  exit 1
fi
# The hostname is only a warning: the build sets networking.hostName itself.
current_host="$(scutil --get LocalHostName 2>/dev/null || true)"
if [[ "$HOSTNAME_FROM_FLAKE" != "$current_host" ]]; then
  echo "warning: flake.nix has hostname = \"$HOSTNAME_FROM_FLAKE\" but this Mac is \"$current_host\"; the build renames it" >&2
fi

# Ask for sudo once and keep the credential fresh for the whole run. Casks
# whose installer needs root call sudo themselves, and sudo caches the
# credential per terminal for five minutes; the first bundle runs far
# longer than that. Two conditions make this work: the keepalive below, and
# `Defaults !use_pty` in hosts/macbook/default.nix (sudo 1.9.14+ otherwise
# runs the rebuild in a fresh pty where nothing is cached, so casks
# prompted "Password:" mid-run and left the tty with echo off). Neither
# nix-darwin's homebrew module nor nix-homebrew has a non-interactive or
# sudo pass-through option; brew bundle runs as this user via sudo --user.
echo "==> sudo is needed for the Nix installer, Rosetta and the first rebuild"
sudo -v
( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE=$!
cleanup() {
  kill "$SUDO_KEEPALIVE" 2>/dev/null || true
  # a password prompt that was interrupted can leave the terminal unusable
  if [[ -t 0 ]]; then stty sane 2>/dev/null || true; fi
}
trap cleanup EXIT

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

# 3. Rosetta 2. nix-homebrew's Intel prefix (enableRosetta) and OrbStack's
# Intel containers need it; without it activation warns "The Intel Homebrew
# prefix has been set up, but Rosetta isn't installed yet". oahd is
# Rosetta's daemon and only runs when it is installed.
if [[ "$(uname -m)" == "arm64" ]] && ! /usr/bin/pgrep -q oahd; then
  echo "==> Installing Rosetta 2…"
  sudo softwareupdate --install-rosetta --agree-to-license
fi

# 4. Put the repo where the `drs` alias expects it
if [[ "$SRC_DIR" != "$REPO_DIR" && ! -e "$REPO_DIR" ]]; then
  mkdir -p "$(dirname "$REPO_DIR")"
  ln -s "$SRC_DIR" "$REPO_DIR"
fi

# 5. Full Disk Access. Safari's settings (modules/home/safari.nix) live in a
# TCC-protected container, so the terminal app running the build needs the
# grant. Warn now, so it can be made while the build runs; without it that
# one step is skipped, nothing fails. ~/Library/Safari is a protected path:
# "Operation not permitted" means no access, a missing directory only means
# Safari has never been launched.
if err="$(/bin/ls "$HOME/Library/Safari" 2>&1 >/dev/null)"; then
  :
elif [[ "$err" == *"Operation not permitted"* ]]; then
  echo "warning: this terminal has no Full Disk Access; Safari settings are skipped until it does" >&2
  echo "         System Settings > Privacy & Security > Full Disk Access: add the terminal app," >&2
  echo "         then run drs from a new terminal window" >&2
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
fi

# 6. First build: darwin-rebuild isn't installed yet, so run it from the flake.
# stdin is detached so nothing downstream can stop and prompt: Homebrew's
# y/n confirmations (e.g. `brew untap` on a tap with stuck formulae) only
# fire on a TTY and otherwise take their safe non-interactive default.
# sudo still works — it reads the password from /dev/tty, not stdin. -H
# resets HOME to root's, otherwise Nix warns that $HOME is not owned by root.
echo "==> Building and activating ${HOSTNAME_FROM_FLAKE}…"
sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_DIR#${HOSTNAME_FROM_FLAKE}" < /dev/null

echo
echo "Done. Open a new terminal. From now on use:  drs   (darwin-rebuild switch)"
