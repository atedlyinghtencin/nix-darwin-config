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
