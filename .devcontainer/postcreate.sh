#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CONFIG_DIR"
cp "$(dirname "$0")/claude-settings.json" "$CONFIG_DIR/settings.json"

# ECC rules must be copied manually; plugins can't distribute them
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/affaan-m/ECC "$tmp/ecc"
mkdir -p "$CONFIG_DIR/rules/ecc"
cp -R "$tmp/ecc/rules/common" "$CONFIG_DIR/rules/ecc/"
# add stack-specific rule sets here if ECC ships them, e.g. an ansible set
rm -rf "$tmp"

# Sign commits with the SSH key in 1Password, through the agent VS Code
# forwards from the Mac (op-ssh-sign only exists there). "key::" hands git
# the public half; the agent does the signing. The copied host git config
# includes this file and points gpg.ssh.allowedSignersFile at ~/.ssh.
signing_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDZSglK9ab22yLwAEXgat5D0rX72T6UNZ9CWhiLQsmQ9"
local_git="$HOME/.gitconfig.local"
git config --file "$local_git" gpg.format ssh
git config --file "$local_git" user.signingkey "key::$signing_key"
git config --file "$local_git" commit.gpgsign true
git config --file "$local_git" tag.gpgsign true

# Local verification (`git log --show-signature`), same format as the Mac's.
# "*" (any identity) if the host git config hasn't been copied in yet.
mkdir -p "$HOME/.ssh"
signer="$(git config user.email || echo '*')"
echo "$signer $signing_key" > "$HOME/.ssh/allowed_signers"
