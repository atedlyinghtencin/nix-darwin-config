# Decisions

Settled choices, dated from when they were made, with the context that a
future reader would otherwise have to dig out of comments. The git history
was squashed to a single commit on 2026-09-14 before the first push, so the
dates here are the only record of the sequence. Revisit only with new
evidence. The README carries a one-line summary of each.

## 2026-08-29 Capture the machine first, then declare

**Context.** This started as a working Mac, not a blank one.
**Decision.** Every module was generated from a read-only capture
(`scripts/collect-mac-facts.sh`, later `scripts/firefox_facts.py`) and pruned
by hand, so the first rebuild changed nothing the machine did not already
have. Each module header records the capture date.
**Consequence.** New state follows the same loop; `mac-facts/` is gitignored
and never applied automatically.

## 2026-08-29 Homebrew for GUI apps, nixpkgs for CLI tools

**Decision.** Casks for anything with a `.app` (updates, launch services and
code signing work the way macOS expects); nixpkgs for command-line tools.
A few formulae stay in Homebrew where macOS integration matters:
cloudflared's launchd service, ffmpeg codecs.
**Consequence.** Two package lists to maintain, one lock for CLI tools.

## 2026-08-29 Nix via the Determinate installer, `nix.enable = false`

**Context.** The Determinate installer survives macOS upgrades and owns the
daemon and `/etc/nix/nix.conf`.
**Decision.** Tell nix-darwin not to manage Nix. `bootstrap.sh` uses that
installer.
**Consequence.** Anyone using the official installer must flip
`nix.enable` to `true`.

## 2026-08-29 Rolling inputs: `flake.lock` stays untracked

**Decision.** Fix forward rather than pin. Every `dru`, fresh clone and CI
run resolves nixpkgs, nix-darwin, home-manager and nix-homebrew to their
latest revisions; a plain `drs` reuses the lock file the previous build
left in the checkout.
**Consequence.** Upstream breakage lands whenever it lands; the runbook
covers rollback and temporary pinning. To pin permanently, track the lock
file.

## 2026-08-29 Automation never prompts

A sequence of fixes converged on one rule: nothing in a rebuild may stop
and wait.

- **`--force` for `brew bundle`**: casks adopt existing apps and
  the tap trust store follows the Brewfile.
- **`openai/tools` marked `trusted`**: Homebrew 6's tap-trust gate
  would otherwise prompt.
- **`HOMEBREW_NO_ASK` tried and reverted**: `brew bundle`
  already sets it; `brew untap` ignores it (Homebrew bug as of 6.x).
- **stdin detached**: `drs` and `bootstrap.sh` run the rebuild
  with `< /dev/null`, so Homebrew's y/n prompts, which only fire on a TTY,
  take their safe default. `sudo` still reads the password from `/dev/tty`.
- **`brew-gc.nix`**: `brew bundle --force-cleanup` uninstalls in
  one batch, and a single protected dependency aborts the batch, so on a
  pre-existing Homebrew nothing was actually removed and the following
  `untap` could prompt. The post-activation pass peels leaves one at a
  time, zaps casks, removes VS Code extensions iteratively (2026-09-13) and
  `untap --force`s, all best-effort, and always converges.

**Consequence.** Anything declared as removed is actually removed on the
same rebuild, never deferred to a manual command.

## 2026-08-29 Back up pre-existing dotfiles instead of aborting

`home-manager.backupFileExtension = "before-nix-darwin"`. A Mac with a
pre-nix `~/.zprofile` activates on the first try; the old file is kept next
to the new one for review.

## 2026-09-13 `brew update` in preActivation, not `autoUpdate`

**Context.** When `brew bundle` auto-updates it re-execs itself, and
nix-homebrew's generated launcher then records its own reduced `PATH` as the
original; the second pass can no longer find `code` or `mas`, so VS Code
extensions and App Store apps fail to install.
**Decision.** `autoUpdate = false`; an explicit `brew update` runs first,
only once nix-homebrew owns `bin/brew`, and never aborts the rebuild.

## 2026-09-13 Firefox as enterprise policy

**Context.** No Firefox account, so no Sync. `programs.firefox` in
home-manager wants the nixpkgs build; the Homebrew cask honours the
`org.mozilla.firefox` defaults domain as policy.
**Decision.** Add-ons via `ExtensionSettings` (`normal_installed`, placed in
the extensions menu rather than pinned), prefs via the `Preferences` policy,
uBlock Origin's custom filters via `3rdparty` managed storage from a plain
text file.
**Consequence.** uBlock's "My filters" pane and any locked pref are
effectively read-only in the browser. Prefs the policy refuses are listed in
the module header and stay unmanaged.

## 2026-09-13 CI evaluates and builds, never activates

**Decision.** A hosted macOS runner does `nix build` of the system closure
on every push and PR. No `brew bundle`, no `defaults write`, no
home-manager switch.
**Consequence.** Nix errors are caught on every push and rolling inputs are
proven to resolve; behaviour is still verified by hand in a tart VM.

## 2026-09-13 `sudo -H` for rebuilds

Nix warns when `$HOME` is not owned by root. `-H` resets it. Baked into
`drs` and `bootstrap.sh`.

## 2026-09-13 VS Code: settings declared, extensions via Homebrew, Copilot off

**Decision.** `settings.json` is generated into the Nix store and symlinked,
so the Settings UI cannot save; the welcome flow is skipped; the built-in
Copilot is disabled with one switch. Extensions are a Brewfile `vscode`
list so `brew bundle` installs them and `brew-gc.nix` removes the rest.
**Consequence.** Every editor change goes through the repo.

## 2026-09-13 Wallpaper from the captured store file

Since Sonoma the choice of a built-in colour with the Gradient toggle is
neither a `defaults` key nor an image. The captured `Index.plist` is installed
verbatim when its `Linked.Content` differs from the store's, then
WallpaperAgent is restarted. Comparing the key path rather than the file
avoids restarting the agent on every rebuild.

## 2026-09-13 Heal "?" Dock tiles with a second restart

nix-darwin writes and restarts the Dock before Homebrew installs the pinned
casks. preActivation checks whether any pinned app is missing;
postActivation restarts the Dock again only in that case.

## 2026-09-13 Finder restarted and `/Applications/.DS_Store` removed on every rebuild

Finder reads its domain only at launch, and a per-folder view saved in
`/Applications/.DS_Store` beats the declared default. Cost: open Finder
windows are lost on each `drs`; a hand-changed view of `/Applications` is
reset.

## 2026-09-13 SSH keys and commit signing through 1Password, no GPG

**Decision.** One agent for every key, unlocked by Touch ID. `ssh.nix`
declares only generic options plus the agent socket; host blocks live in
untracked `~/.ssh/config.local`. Signing uses `op-ssh-sign` and turns on
only when `sshSigningKey` is set in `flake.nix`.
**Consequence.** Nothing secret in `~/.ssh` or `~/.gnupg` to back up; the
repo contains no ssh host names or users.

## 2026-09-13 Configuration addressed by name, never by hostname

`bootstrap.sh`, CI and the `drs` alias all use `#redxiii`, read from the
one `hostname` line in `flake.nix`. A machine that macOS renamed after a LAN
clash still builds, and the switch renames it back.

## 2026-09-14 Firefox bookmarks backed up to Proton Drive, restored by hand

**Context.** Bookmarks live in `places.sqlite` inside the profile. Moving
the profile onto a synced folder risks corrupting a live SQLite database
under Proton Drive's File Provider, and Firefox Sync needs a Mozilla account.
**Decision.** Leave the profile alone and redirect only Firefox's own daily
`bookmarkbackups` snapshots into Proton Drive through a symlink
(`modules/home/firefox-backups.nix`). One-way: restore is a few clicks in
Firefox, documented in the runbook. The Proton Drive folder is found by
pattern so the account name stays out of the repo.
**Consequence.** Up to 15 dated snapshots are always off-machine; history,
logins and tabs are not covered. Firefox's own retention deletes old
snapshots from Proton Drive too.
