<!-- Generated: 2026-09-14 | Files scanned: 24 | Token estimate: ~520 -->
# Dependencies codemap

## Flake inputs (unpinned: flake.lock is untracked)
nixpkgs        github:NixOS/nixpkgs/nixpkgs-unstable
nix-darwin     github:nix-darwin/nix-darwin/master        follows nixpkgs
home-manager   github:nix-community/home-manager           follows nixpkgs
nix-homebrew   github:zhaofengli/nix-homebrew

## nixpkgs packages
system   git curl coreutils nerd-fonts.jetbrains-mono zsh
user     git wget uv ripgrep fd bat eza jq tree htop gh nixfmt nil defaultbrowser
         + programs: fzf zoxide direnv(nix-direnv) starship delta gh home-manager

## Homebrew (modules/darwin/homebrew.nix)
tap      openai/tools (trusted)
brews    ansible ansible-lint cloudflared f3 ffmpeg mas nmap node node@22 poppler qrencode openai/tools/tart tcpdump yamllint yt-dlp
casks    1password 1password-cli adobe-creative-cloud appcleaner claude google-chrome itsytv kdenlive libreoffice orbstack
         proton-drive proton-mail proton-pass protonvpn royal-tsx visual-studio-code vlc wireshark-app discord dropbox firefox
vscode   mechatroner.rainbow-csv ms-python.{debugpy,python,vscode-pylance,vscode-python-envs} ms-vscode-remote.remote-containers
         ms-vscode.makefile-tools yzhang.markdown-all-in-one
mas      (none)

## Firefox policy (modules/darwin/firefox.nix)
add-ons  1Password, Proton Pass, OneTab, uBlock Origin  ← addons.mozilla.org latest.xpi, normal_installed, menupanel
prefs    43 via Preferences policy (2 locked: browser.ipProtection.enabled, identity.fxaccounts.toolbar.enabled)
filters  ublock-filters.txt → 3rdparty.Extensions.uBlock0.toOverwrite.filters

## External services touched
install.determinate.systems   bootstrap.sh (Nix installer)
DeterminateSystems/nix-installer-action  ci.yml
github.com                    flake inputs, Homebrew taps, actions/checkout
addons.mozilla.org            add-on install_url
1Password.app                 ssh agent socket (~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock), op-ssh-sign
OrbStack                      ~/.orbstack/ssh/config, shell init
Proton Drive.app              ~/Library/CloudStorage/ProtonDrive-*/Firefox/bookmarkbackups (symlink target)
macOS private API             activateSettings -u, plutil, defaults, killall Dock/Finder/WallpaperAgent

## Tooling for the scripts
python3 stdlib only (argparse, configparser, json, re, subprocess, sys, pathlib; tests: unittest, tempfile)
bash + macOS CLI: scutil sw_vers defaults plutil brew mas code
