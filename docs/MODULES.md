# Module reference

One entry per tracked source file, in the order the flake wires them
together. "Captured" is the date the values were read off the Mac before
being pruned by hand; re-capture with the scripts in [SCRIPTS.md](SCRIPTS.md).

## flake.nix

Inputs, all following `nixpkgs` where they can:

| Input | Source | Role |
|---|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixpkgs-unstable` | packages for both layers |
| `nix-darwin` | `github:nix-darwin/nix-darwin/master` | system layer |
| `home-manager` | `github:nix-community/home-manager` | user layer |
| `nix-homebrew` | `github:zhaofengli/nix-homebrew` | installs and pins Homebrew itself |

The `vars` block is the only place machine identity lives:

| Key | Value | Used by |
|---|---|---|
| `username` | `redxiii` | user account, home dir, Homebrew owner, Dock folder, screenshots path |
| `hostname` | `redxiii` | `networking.hostName`, the configuration name, `bootstrap.sh`, CI, `drs` |
| `computerName` | `redxiii` | `networking.computerName` |
| `fullName`, `email` | git identity | `git.nix` |
| `system` | `aarch64-darwin` | platform and formatter |
| `sshSigningKey` | `""` (off) | `git.nix`: non-empty turns on SSH commit and tag signing via 1Password |

Other settings in the flake: nix-homebrew with Rosetta and `autoMigrate`;
home-manager with `useGlobalPkgs`, `useUserPackages` and
`backupFileExtension = "before-nix-darwin"`; `nix fmt` mapped to `nixfmt`.

## bootstrap.sh

Fresh-Mac installer, safe to re-run: every step checks its own
precondition, so a second run only rebuilds. In order:

- refuses anything but macOS, running as root, and a `CHANGEME` hostname;
  warns when the checkout has no `flake.lock`
- reads `username` and `hostname` out of `flake.nix` with the same `sed`
  CI uses; a username that differs from `id -un` is fatal (both values and
  both fixes are printed), a hostname that differs from
  `scutil --get LocalHostName` is a warning
- `sudo -v`, then a background loop refreshes the credential every 60 s so
  casks that need root never prompt mid-run; the EXIT trap kills the loop
  and runs `stty sane`
- Xcode Command Line Tools if missing
- Nix via the Determinate installer if missing, after two preflight checks:
  `/etc/synthetic.conf` declares `nix` but `/nix` does not exist (reboot
  needed), or a "Nix Store" APFS volume exists with nothing mounted on
  `/nix` (prints the `diskutil apfs deleteVolume` and
  `security delete-generic-password` cleanup). The Nix profile is sourced
  first so a re-run does not mistake an installed Nix for a missing one
- Rosetta 2 via `softwareupdate` when `oahd` is not running (Apple Silicon)
- warns, and opens the Full Disk Access pane, when listing
  `~/Library/Safari` fails with "Operation not permitted" (the Safari step
  of the build needs the grant; nothing fails without it)
- symlinks the checkout to `~/.config/nix-darwin` if it lives elsewhere
- the first `darwin-rebuild switch` straight from the nix-darwin flake, as
  root with stdin detached

## hosts/macbook/default.nix

System-level settings for this one machine:

- imports the four `modules/darwin` files
- `networking.hostName` / `computerName` from `vars`
- `system.primaryUser` and the user account (shell `zsh`, home `/Users/<user>`)
- `nix.enable = false` (Determinate installer owns the daemon)
- `nixpkgs.config.allowUnfree = true`
- system packages: `git`, `curl`, `coreutils`
- `programs.zsh.enable` so `/etc/zshrc` sources the Nix environment
- Touch ID for `sudo`
- application firewall on, stealth mode on
- font: JetBrains Mono Nerd Font
- `system.stateVersion = 6`

## modules/darwin/defaults.nix

Captured 2026-08-20 from `defaults read`. Groups declared:

| Group | Notable values |
|---|---|
| `dock` | no autohide, tile size 59, recents on, bottom-right hot corner Quick Note, 14 pinned apps in order, Downloads as a fan stack |
| `finder` | show hidden files, list view, new windows open on Home, full POSIX path in the title, external and removable drives on the Desktop, trash emptied after 30 days, no rename warning |
| `NSGlobalDomain` | all filename extensions shown (the global key Finder and the Open/Save panels read; the `finder.*` variant writes `com.apple.finder` and was ignored), dark mode fixed, no auto-capitalise / period / spell-correct, natural scrolling off, force click on, spring-loading on |
| `trackpad` | tap-to-click off, right-click on, three-finger drag off |
| `screencapture` | thumbnail on, PNG, no window shadow, saved to `~/Pictures/Screenshots` (folder created by `modules/home/default.nix`) |
| `screensaver`, `loginwindow` | password immediately on lock, guest account off |
| `spaces` | displays do not have separate Spaces (menu bar and Dock stay on the main display) |
| `CustomUserPreferences` | personalised ads off; Finder's Recents view forced to list (undocumented key, verified on macOS 26) |

Activation hooks in the same file:

- **preActivation** notes whether any pinned Dock app is missing (fresh
  machine: the casks are installed after nix-darwin's Dock restart).
- **postActivation** runs `activateSettings -u`, deletes
  `/Applications/.DS_Store` (a per-folder view saved there beats the declared
  default), restarts Finder (it only reads its domain at launch; open Finder
  windows are lost), and restarts the Dock again if the flag was set.

## modules/darwin/homebrew.nix

Captured 2026-08-20 from `brew bundle dump` plus apps found in
`/Applications`.

`onActivation`: `autoUpdate = false`, `upgrade = true`, `cleanup = "zap"`,
`extraFlags = [ "--force" "--quiet" ]`. The index is refreshed instead by an
explicit `brew update` in preActivation, which only runs once nix-homebrew
owns the install and never aborts the rebuild.

| List | Entries |
|---|---|
| `taps` | `openai/tools` (trusted, for tart + softnet) |
| `brews` (15) | ansible, ansible-lint, cloudflared, f3, ffmpeg, mas, nmap, node, node@22, poppler, qrencode, openai/tools/tart, tcpdump, yamllint, yt-dlp |
| `casks` (21) | 1password, 1password-cli, adobe-creative-cloud, appcleaner, claude, google-chrome, itsytv, kdenlive, libreoffice, orbstack, proton-drive, proton-mail, proton-pass, protonvpn, royal-tsx, visual-studio-code, vlc, wireshark-app, discord, dropbox, firefox |
| `vscode` (8) | rainbow-csv, Python (debugpy, python, pylance, python-envs), Remote Containers, Makefile Tools, Markdown All in One |
| `masApps` | none (Keynote, Numbers, Pages commented out) |

Formulae stay in Homebrew rather than nixpkgs only where macOS integration
matters (cloudflared's launchd service, ffmpeg codecs).

## modules/darwin/brew-gc.nix

Runs in postActivation whenever `homebrew.onActivation.cleanup` is not
`"none"`. Exists because `brew bundle --force-cleanup` uninstalls in one
batch, and one protected shared dependency aborts the whole batch, so on a
machine with pre-existing packages nothing is actually removed.

Keep-lists are derived from the same `homebrew.*` options, so there is
nothing to maintain here:

- formulae and casks by exact name or basename (`openai/tools/tart` matches `tart`)
- taps: declared ones plus any tap implied by a fully-qualified name
- VS Code extensions, compared lower-cased

Then, as the Homebrew user with `HOMEBREW_NO_AUTO_UPDATE=1`: unmanaged leaf
formulae are peeled one at a time until a pass removes nothing (capped at 10
passes), unmanaged casks are removed with `--zap --force`, unmanaged VS Code
extensions are removed iteratively the same way (one may depend on another),
and non-`homebrew/*` taps are `untap --force`ed. Every step is best-effort;
the block always exits 0.

## modules/darwin/firefox.nix

Captured 2026-09-12 with `scripts/firefox_facts.py` and pruned by hand.
Written into the `org.mozilla.firefox` defaults domain, which the Homebrew
cask reads as enterprise policy on next launch (check `about:policies`).

- `EnterprisePoliciesEnabled`, `DisableTelemetry`
- `ExtensionSettings`: 1Password, Proton Pass, OneTab, uBlock Origin, all
  `normal_installed` (auto-installed, user can disable but not remove) with
  `default_area = "menupanel"` so a fresh profile keeps the buttons under the
  extensions menu
- `3rdparty` managed storage for uBlock Origin: `toOverwrite.filters` is
  read from `ublock-filters.txt`, one filter per line
- `Preferences`: 43 `about:config` values. `Status = "user"` re-applies at
  every start; `"locked"` (used for the built-in VPN button and the
  Mozilla-account toolbar button) also greys it out

Left out on purpose, with the reasons in the file header: uMatrix,
the `datareporting.*` prefs (covered by `DisableTelemetry`), and prefs the
Preferences policy refuses (`findbar.highlightAll`, `print_printer`,
`privacy.clearHistory.*`, `privacy.sanitize.timeSpan`,
`privacy.history.custom`).

## modules/darwin/ublock-filters.txt

uBlock Origin's "My filters" pane, pushed in at every Firefox launch. Edits
made inside uBlock's dashboard are lost on the next start; edit this file and
run `drs` instead. Currently a Reddit login-upsell blocker.

## modules/home/default.nix

home-manager entry. Imports the eight user modules, sets `home.username` and
`home.homeDirectory` from `vars`, session variables (`EDITOR=vim`,
`VISUAL=code --wait`, `PAGER=less -R`), creates `~/Pictures/Screenshots`
(macOS silently falls back to the Desktop if the declared folder is missing),
lets home-manager manage itself, `home.stateVersion = "25.05"`.

## modules/home/packages.nix

From nixpkgs: git, wget, uv, ripgrep, fd, bat, eza, jq, tree, htop, gh,
nixfmt, nil. Programs with zsh integration: fzf, zoxide, direnv (with
nix-direnv). Node and ffmpeg deliberately stay in Homebrew.

## modules/home/zsh.nix

Autosuggestions, syntax highlighting, completion, `autocd`; 50 000 lines of
shared, deduplicated history; Emacs keymap with up/down doing prefix history
search. `SHELL_SESSIONS_DISABLE=1` in `~/.zshenv` stops Terminal.app's
per-window session files from fighting the shared history.

| Alias | Expands to |
|---|---|
| `ls`, `ll`, `lt` | `eza` with icons (long with git status, tree depth 2) |
| `cat` | `bat --paging=never` |
| `g` | `git` |
| `..`, `...` | `cd ..`, `cd ../..` |
| `dnsflush` | flush the DNS cache and HUP `mDNSResponder` |
| `drs` | `sudo -H darwin-rebuild switch --flake ~/.config/nix-darwin#redxiii < /dev/null` |
| `dru` | `nix flake update --flake ~/.config/nix-darwin && drs` |

Functions: `mkcd <dir>` (mkdir and cd), `ports [port]` (listening TCP ports
with their process). Sourced if present: Homebrew `shellenv`, OrbStack
`init.zsh`, `~/.local/bin/env`, `~/.zshrc.local`.

## modules/home/starship.nix

Two-line prompt: directory (3 segments, truncated to the repo), git branch
and status, nix-shell state and command duration over 2 s on the first line,
then a `❯` on its own line that turns red on failure. No blank line between
prompts.

## modules/home/git.nix

| Setting | Value |
|---|---|
| identity | `vars.fullName` / `vars.email`, overridable from `~/.gitconfig.local` |
| defaults | `main` branch, `pull.rebase`, `push.autoSetupRemote`, `fetch.prune`, `rebase.autoStash`, `rerere`, `zdiff3` conflicts, histogram diff, `autocrlf = input` |
| global ignores | `.DS_Store`, `*.swp`, `.direnv/`, `result`, `.claude/settings.local.json` |
| signing (only when `vars.sshSigningKey` is set) | `gpg.format = ssh`, signer `op-ssh-sign` from 1Password.app, sign commits and tags |

Also enables delta (side-by-side, line numbers, navigate) and `gh`.

## modules/home/ssh.nix

`~/.ssh/config` with home-manager's default block turned off. Includes, in
order, `~/.orbstack/ssh/config` and `~/.ssh/config.local`; then a `Host *`
block whose only setting is `IdentityAgent` pointing at 1Password's socket
(quoted, the path contains spaces). Includes come first because ssh keeps
the first value it finds, so a private host block can override anything.
`SSH_AUTH_SOCK` is exported to the same socket for tools that bypass
`ssh_config`.

## modules/home/vscode.nix

Captured 2026-09-13. Generates `~/Library/Application Support/Code/User/settings.json`
as a read-only symlink into the Nix store, so the Settings UI can no longer
save; change values here and rebuild. Sets Solarized Dark, git autofetch and
smart commit, no window restore, no welcome page or walkthroughs, no release
notes, no extension recommendations, and `chat.disableAIFeatures` to hide
the built-in Copilot. Extensions are installed by `homebrew.nix`, not here.

## modules/home/wallpaper.nix and wallpaper/Index.plist

Since Sonoma the wallpaper choice lives in the per-user wallpaper store, not
in `defaults`. `Index.plist` is the captured store file for "Black" with the
Gradient toggle on all displays and Spaces. The activation step compares only
`AllSpacesAndDisplays.Linked.Content` (WallpaperAgent rewrites timestamps, so
a byte comparison would restart it every time), and when it differs copies
the file in, makes it writable for the agent, and restarts WallpaperAgent.
A declared file without that key path fails the activation with a message to
re-capture with all Spaces linked.

## modules/home/firefox-backups.nix

Firefox writes a compressed JSON snapshot of all bookmarks into
`<profile>/bookmarkbackups` once a day (idle time, or shutdown if it hasn't
happened yet), keeping the newest 15. This activation step replaces that
directory with a symlink to `Firefox/bookmarkbackups` inside the Proton
Drive folder, so the snapshots are backed up off the machine. One-way;
restore is manual, see [RUNBOOK.md](RUNBOOK.md#restoring-firefox-bookmarks).

- The default profile is resolved from `profiles.ini` the way Firefox does
  it: an `[Install*]` section wins, else the `[Profile*]` with `Default=1`.
- The Proton Drive folder is found by the pattern
  `~/Library/CloudStorage/ProtonDrive-*`, so the account name stays out of
  the repo.
- Skipped with a message until Firefox and Proton Drive have each been
  launched once, or if the resolved profile directory is missing.
- The first link is only made while Firefox is closed; snapshots already in
  the profile are copied across first (never overwriting a newer copy).
- Idempotent: an existing correct symlink means no output and no changes.

History, logins and open tabs stay in the profile and are not backed up.

## modules/home/default-browser.nix

Installs `defaultbrowser` from nixpkgs and, after `writeBoundary`, runs it
when Firefox is installed but not marked `*` in its handler list. Skips with
a message when `/Applications/Firefox.app` is missing or LaunchServices does
not list Firefox as an HTTP handler yet (before its first launch). macOS
confirms the change with a one-time dialog; an ignored dialog means the step
runs again on the next rebuild. Never fails the build.

## modules/home/safari.nix

Writes `AutoFillPasswords`, `AutoFillFromAddressBook` and
`AutoFillCreditCardData` as `false` into `com.apple.Safari` with `defaults
write`, which follows the sandboxed domain into
`~/Library/Containers/com.apple.Safari`. That container is TCC-protected, so
the step first lists `~/Library/Safari`: success means Full Disk Access and
the keys that differ are written; "Operation not permitted" means no grant,
so it warns, opens the Full Disk Access pane and continues; a missing
directory means Safari has never been launched and it skips. Not done
through `system.defaults.CustomUserPreferences` because nix-darwin's
activation is `set -e` and a failed write there would abort the rebuild.

## modules/home/terminal.nix and terminal/nix-darwin.terminal

Terminal.app stores a profile's font as an NSKeyedArchiver blob, so the
profile is a `.terminal` plist. Captured 2026-09-16: the "Clear Dark"
profile exported from the Mac (16 ANSI colours, translucent blurred
background, text, bold and selection colours, spacing, 120 x 30, profile
version 2.09), renamed `nix-darwin` so it never collides with Terminal's
own Clear Dark, with only the font archive changed from SF Mono 12 pt to
`JetBrainsMonoNF-Regular` 12 pt. The activation opens the file when
`defaults read com.apple.Terminal "Window Settings"` lacks the profile
(registers it, opens one window), then writes `Default Window Settings` and
`Startup Window Settings` when they differ. Both keys are set here, not via
`CustomUserPreferences`, so they follow the import. Open windows keep their
profile.

## .github/workflows/ci.yml

`nix build .#darwinConfigurations.<host>.system` on `macos-latest` with the
Determinate Nix installer action, on pushes to `main`, pull requests and
manual dispatch; read-only token, 45-minute timeout, superseded runs
cancelled. The host name is read from `flake.nix` with the same `sed` as
`bootstrap.sh`.
