<!-- Generated: 2026-09-14 | Files scanned: 24 | Token estimate: ~750 -->
# Architecture codemap

Single-host nix-darwin flake. No services, no runtime; the "program" is a
system closure that activates a Mac.

## Entry points
flake.nix                     inputs + `vars` (username/hostname/email/system/sshSigningKey)
  → darwinConfigurations.redxiii (nix-darwin.lib.darwinSystem, aarch64-darwin)
bootstrap.sh                  fresh Mac: CLT → Determinate Nix → symlink ~/.config/nix-darwin → first switch
zsh alias drs                 sudo -H darwin-rebuild switch --flake ~/.config/nix-darwin#redxiii < /dev/null
zsh alias dru                 nix flake update && drs
.github/workflows/ci.yml      nix build .#darwinConfigurations.<host>.system on macos-latest

## Module graph
hosts/macbook/default.nix (55)         host, user, time zone, nix.enable=false, firewall, touchid sudo (+ !use_pty), fonts
├─ modules/darwin/defaults.nix (154)   system.defaults.* (incl. timezone.auto off); pre/postActivation Dock+Finder fixes
├─ modules/darwin/homebrew.nix (131)   homebrew.{taps,brews,casks,vscode,masApps}; preActivation brew update
├─ modules/darwin/brew-gc.nix (121)    postActivation: uninstall unmanaged formulae/casks/ext/taps
└─ modules/darwin/firefox.nix (101)    system.defaults.CustomUserPreferences."org.mozilla.firefox"
   └─ ublock-filters.txt (26)          → 3rdparty uBlock toOverwrite.filters
nix-homebrew.darwinModules             installs brew from store, rosetta, autoMigrate
home-manager.darwinModules → modules/home/default.nix (32)
├─ packages.nix (40)   home.packages + fzf/zoxide/direnv
├─ zsh.nix (73)        aliases incl. drs/dru; sources ~/.zshrc.local
├─ starship.nix (40)
├─ git.nix (54)        identity from vars; ssh signing iff vars.sshSigningKey != ""
├─ ssh.nix (35)        includes ~/.orbstack/ssh/config, ~/.ssh/config.local; IdentityAgent=1Password
├─ vscode.nix (27)     settings.json as store symlink
├─ firefox-backups.nix (61)  activation: <profile>/bookmarkbackups → ~/Library/CloudStorage/ProtonDrive-*/Firefox/bookmarkbackups
├─ default-browser.nix (33)  activation: defaultbrowser firefox unless already '* firefox'
├─ safari.nix (38)           activation: defaults write com.apple.Safari AutoFill* false, iff ~/Library/Safari readable (FDA)
└─ terminal.nix (37)         activation: defaults write 'Window Settings' -dict-add nix-darwin <profile dict> once; Default/Startup Window Settings = nix-darwin

## Activation order (one root shell, stdin detached; postActivation fragments in module-merge order)
preActivation   homebrew.nix: brew update (only if bin/brew ∈ /nix/store; failure = warn)
preActivation   defaults.nix: flag if any dockApps path missing
userDefaults    nix-darwin writes system.defaults (incl. Firefox policy), restarts Dock
homebrew        brew bundle --force --quiet; upgrade; cleanup=zap
postActivation  home-manager: dotfiles (backup *.before-nix-darwin) → firefox-backups + default-browser + safari + terminal activations
postActivation  defaults.nix: activateSettings -u; rm /Applications/.DS_Store; killall Finder; Dock again if flagged
postActivation  brew-gc.nix: leaves loop ≤10 → casks --zap → vscode ext loop ≤10 → untap --force

## Capture loop (macOS only, read-only, output gitignored)
scripts/collect-mac-facts.sh (97)  → mac-facts/{identity,Brewfile,defaults,dock-apps,wallpaper-index.plist,vscode/,dotfile-contents,tools,fonts}
scripts/firefox_facts.py (345)     → mac-facts/firefox-{addons,prefs,policies}.txt + firefox.nix draft
scripts/test_firefox_facts.py (199) 18 unit tests: python3 -m unittest discover -s scripts
→ hand-merge into modules → drs

## Untracked inputs read at runtime
~/.zshrc.local  ~/.gitconfig.local  ~/.ssh/config.local  ~/.orbstack/{ssh/config,shell/init.zsh}  ~/.local/bin/env
flake.lock (rolling; never committed)
