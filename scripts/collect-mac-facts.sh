#!/usr/bin/env bash
# Run this in macOS Terminal (NOT in the devcontainer). Read-only: it only
# inspects the machine and writes text files into ./mac-facts/ for review.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=mac-facts
mkdir -p "$OUT"

echo "==> identity"
{
  echo "username=$(whoami)"
  echo "hostname=$(scutil --get LocalHostName)"
  echo "computername=$(scutil --get ComputerName)"
  echo "fullname=$(id -F)"
  echo "arch=$(uname -m)"
  echo "macos=$(sw_vers -productVersion)"
  echo "shell=$SHELL"
  echo "git_name=$(git config --global user.name 2>/dev/null || true)"
  echo "git_email=$(git config --global user.email 2>/dev/null || true)"
} > "$OUT/identity.txt"

echo "==> homebrew"
if command -v brew >/dev/null 2>&1; then
  brew bundle dump --force --file="$OUT/Brewfile" --describe 2>/dev/null || brew bundle dump --force --file="$OUT/Brewfile"
  brew leaves > "$OUT/brew-leaves.txt"
  brew list --cask > "$OUT/brew-casks.txt"
else
  echo "homebrew not installed" > "$OUT/Brewfile"
fi

echo "==> app store + /Applications"
command -v mas >/dev/null 2>&1 && mas list > "$OUT/mas-apps.txt" || echo "mas not installed" > "$OUT/mas-apps.txt"
ls /Applications > "$OUT/applications.txt"
ls "$HOME/Applications" > "$OUT/applications-user.txt" 2>/dev/null || true

echo "==> dock + macOS defaults"
defaults read com.apple.dock persistent-apps 2>/dev/null \
  | grep -o '"_CFURLString" = "[^"]*"' | sed 's/.*= "//; s/"$//' > "$OUT/dock-apps.txt" || true
# Finder's recent-folder lists are personal history (real paths, cloud-drive
# folders named after accounts) and never something to declare, so the two
# top-level arrays are cut out and replaced with a marker. Each is an array
# at 4-space indent that closes with "    );" at the same indent.
drop_finder_recents() {
  awk '
    /^    (FXRecentFolders|RecentMoveAndCopyDestinations) = +\($/ { print "    " $1 " = (redacted by collect-mac-facts.sh);"; skip = 1; next }
    skip && /^    \);$/ { skip = 0; next }
    !skip
  '
}
for d in com.apple.dock com.apple.finder NSGlobalDomain com.apple.AppleMultitouchTrackpad \
         com.apple.screencapture com.apple.desktopservices com.apple.menuextra.clock \
         com.apple.spaces com.apple.screensaver com.apple.loginwindow; do
  echo "### $d"; defaults read "$d" 2>/dev/null; echo
done | drop_finder_recents > "$OUT/defaults.txt"

echo "==> wallpaper"
# Since Sonoma the wallpaper choice (including the built-in Colors with the
# Gradient toggle, which is not an image file) lives in this per-user store,
# not in `defaults`. Dumped as XML so it can be read and re-declared.
WALLPAPER_STORE="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
if [ -f "$WALLPAPER_STORE" ]; then
  plutil -convert xml1 -o "$OUT/wallpaper-index.plist" "$WALLPAPER_STORE" \
    || echo "plutil failed" > "$OUT/wallpaper-index.plist"
else
  echo "no wallpaper store at $WALLPAPER_STORE" > "$OUT/wallpaper-index.plist"
fi

echo "==> vscode (user settings, keybindings, snippets)"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
mkdir -p "$OUT/vscode"
for f in settings.json keybindings.json; do
  [ -f "$VSCODE_USER/$f" ] && cp "$VSCODE_USER/$f" "$OUT/vscode/$f"
done
[ -d "$VSCODE_USER/snippets" ] && cp -R "$VSCODE_USER/snippets" "$OUT/vscode/"

echo "==> dotfiles (names + sizes only, then contents of the common ones)"
ls -la "$HOME" | grep -E '^\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\.' > "$OUT/home-dotfiles.txt"
ls -la "$HOME/.config" > "$OUT/config-dir.txt" 2>/dev/null || true
for f in .zshrc .zprofile .zshenv .gitconfig .gitignore_global .ssh/config; do
  [ -f "$HOME/$f" ] && { echo "### ~/$f"; cat "$HOME/$f"; echo; }
done > "$OUT/dotfile-contents.txt"

echo "==> tools"
{
  for t in nix brew mas starship fzf zoxide direnv nvim code cursor gh node python3 uv docker; do
    printf '%-10s %s\n' "$t" "$(command -v "$t" 2>/dev/null || echo '-')"
  done
  echo; echo "vscode extensions:"; command -v code >/dev/null && code --list-extensions 2>/dev/null
} > "$OUT/tools.txt"

echo "==> fonts (user-installed)"
ls "$HOME/Library/Fonts" > "$OUT/fonts.txt" 2>/dev/null || true

echo
echo "Wrote $OUT/. Review for anything sensitive before sharing:"
echo "  grep -iE 'token|secret|password|key' $OUT/dotfile-contents.txt"
ls -1 "$OUT"
