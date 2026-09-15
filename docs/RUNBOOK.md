# Runbook

Operating the machine from this repo. Every command below runs in macOS
Terminal on the Mac itself unless it says otherwise.

## Everyday

| Task | Command |
|---|---|
| Apply the repo to the machine | `drs` |
| Update all flake inputs, then apply | `dru` |
| See what changed in the inputs | `git -C ~/.config/nix-darwin diff` (the lock file is untracked, so compare `nix flake metadata` before and after instead) |
| List generations | `darwin-rebuild --list-generations` |
| Undo the last switch | `sudo darwin-rebuild switch --rollback` |
| Format all `.nix` files | `nix fmt` (in the repo) |
| Free disk space | `sudo nix-collect-garbage --delete-older-than 30d` |

`drs` and `dru` are aliases from `modules/home/zsh.nix`; they only exist
once the first switch has run. Before that, use the command `bootstrap.sh`
prints, or:

```sh
sudo -H darwin-rebuild switch --flake ~/.config/nix-darwin#redxiii < /dev/null
```

## Fresh machine

1. Edit the `vars` block in `flake.nix` if this is a different Mac
   (`whoami`, `scutil --get LocalHostName`, `scutil --get ComputerName`).
   `username` must equal the macOS account name; `bootstrap.sh` refuses to
   build otherwise, and warns (only) when the hostname differs, since the
   build renames the machine.
2. Sign in to the Mac App Store if `masApps` lists anything.
3. Clone and run the installer as the normal user (it refuses `sudo`):

   ```sh
   git clone <this repo> ~/.config/nix-darwin
   cd ~/.config/nix-darwin
   ./bootstrap.sh
   ```

   It asks for your password once and keeps sudo alive for the run, installs
   the Xcode Command Line Tools (accept the dialog), Nix via the Determinate
   installer, Rosetta 2 if missing, then builds and activates. The first run
   downloads and installs everything Homebrew, so it takes a while.
4. If the script stops with "Reboot, then run ./bootstrap.sh again": the
   installer declared the `/nix` firmlink in `/etc/synthetic.conf`, and on a
   fresh macOS the firmlink only appears at the next boot. Reboot and re-run.
   If it instead reports a leftover "Nix Store" volume, run the `diskutil`
   and `security` commands it prints, then re-run.
5. Open a new terminal so the declared zsh config and aliases load.
6. Work through the checklist in
   [README.md](../README.md#manual-steps-after-first-bootstrap): 1Password
   and its SSH agent, the optional signing key, launching Firefox once, and
   everything later sections of this runbook cannot do for you.

## Adopting a Mac that already has stuff on it

- Existing dotfiles that home-manager wants to own are moved aside as
  `<name>.before-nix-darwin`, not overwritten. Diff them against the
  declared versions, move anything private into the `.local` files, then
  delete the backups.
- An existing `/opt/homebrew` is adopted by nix-homebrew (`autoMigrate`).
- **`cleanup = "zap"` removes every cask and formula that is not declared,
  and `brew-gc.nix` makes sure that really happens.** Capture the machine
  first (`./scripts/collect-mac-facts.sh`), merge what you want to keep into
  `homebrew.nix`, or set `cleanup = "none"` for the first switch.
- The screensaver, Finder, Dock, trackpad and text-input settings are all
  overwritten by `defaults.nix`. Capture first if you care about the
  current values.

## Re-capturing machine state

```sh
./scripts/collect-mac-facts.sh     # everything except Firefox
./scripts/firefox_facts.py         # Firefox add-ons and prefs
```

Both write into the gitignored `mac-facts/`. Merge by hand into the module
that owns the setting (see [MODULES.md](MODULES.md)), update the "captured"
date in that module's header comment, run `drs`. Details of every output
file are in [SCRIPTS.md](SCRIPTS.md).

## Where a change goes

| I want to… | Edit |
|---|---|
| add a CLI tool | `modules/home/packages.nix` (search at search.nixos.org first) |
| add a GUI app | `casks` in `modules/darwin/homebrew.nix` |
| add a formula that needs macOS integration | `brews` in `homebrew.nix` |
| add an App Store app | `masApps` (`mas search <name>` for the id) |
| add or remove a VS Code extension | `vscode` in `homebrew.nix` |
| change a VS Code setting | `modules/home/vscode.nix` (the Settings UI can't save) |
| change a macOS preference (Dock, Finder, trackpad, text input, screenshots, lock) | `modules/darwin/defaults.nix` (options: nix-darwin manual) |
| pin or reorder Dock apps | `dockApps` in `defaults.nix` |
| change a Firefox setting or add-on | `modules/darwin/firefox.nix` |
| add a uBlock Origin filter | `modules/darwin/ublock-filters.txt` |
| add a shell alias or function | `modules/home/zsh.nix` |
| change the prompt | `modules/home/starship.nix` |
| change a git default | `modules/home/git.nix` |
| add a generic ssh option | `modules/home/ssh.nix`; host blocks go in `~/.ssh/config.local` |
| change a Safari preference | `modules/home/safari.nix` (needs Full Disk Access for the terminal) |
| change the default browser | `modules/home/default-browser.nix` (Firefox hardcoded; macOS confirms with a dialog) |
| change where Firefox bookmark backups go | `modules/home/firefox-backups.nix` (restore steps below) |
| change the wallpaper | pick it in System Settings, run `collect-mac-facts.sh`, copy `mac-facts/wallpaper-index.plist` over `modules/home/wallpaper/Index.plist` |
| keep a secret or work-only setting | `~/.zshrc.local`, `~/.gitconfig.local`, `~/.ssh/config.local` (never tracked) |

## Restoring Firefox bookmarks

Firefox snapshots its bookmarks once a day into `Firefox/bookmarkbackups`
in Proton Drive (see `modules/home/firefox-backups.nix`). Nothing restores
automatically; on a fresh machine or after a mistake:

1. Make sure Proton Drive is signed in and the folder has synced.
2. In Firefox: Bookmarks → Manage Bookmarks (⌘⇧O).
3. Import and Backup → Restore. Dated entries are the snapshots Firefox can
   see through the symlink; "Choose File…" lets you pick any `.jsonlz4` from
   Proton Drive, for example one made by a different Mac.
4. Confirm. The restore replaces all current bookmarks with the snapshot.

On a fresh machine the order is: `drs`, launch Firefox once, sign in to
Proton Drive, `drs` again (the first run skips because neither existed yet),
then restore.

## Verifying a change without touching the machine

- **CI** builds the system closure on a hosted macOS runner for every push
  and pull request. Green means it evaluates and builds; it says nothing
  about what activation does.
- **Locally on a Mac**, the same check is
  `nix build .#darwinConfigurations.redxiii.system --no-link`.
- **Behaviour** (Homebrew, defaults, Firefox policy, Dock) is verified in a
  tart VM: install a macOS image, clone the repo inside it, run
  `./bootstrap.sh`, and look. The VM's hostname may end in `-2`; the
  configuration is still addressed as `#redxiii` and builds regardless.
- The Python scripts have unit tests that run anywhere:
  `python3 -m unittest discover -s scripts`.

## When inputs roll forward and break

`flake.lock` is untracked, so a `dru` (or a fresh clone) can pull an upstream
change that fails to evaluate or misbehaves.

1. `sudo darwin-rebuild switch --rollback` gets the machine back.
2. To keep working while upstream fixes it, pin the offending input in
   `flake.nix` temporarily, for example
   `nixpkgs.url = "github:NixOS/nixpkgs/<known-good-commit>";`, run `drs`,
   and revert the pin later.
3. To stop rolling for good, delete the `flake.lock` line from `.gitignore`
   and commit the lock file; `dru` then becomes the only way inputs move.

## Troubleshooting

**`bootstrap.sh` says the username does not match.** The macOS account
(`id -un`) and `username` in `flake.nix` differ. Fix the flake, or rename the
account (log in as another admin, System Settings > Users & Groups >
right-click the user > Advanced Options; the home folder must be renamed
too). Renaming is the riskier of the two.

**`bootstrap.sh` refuses to run as root.** Run it as your user. Nix would
otherwise refuse the checkout (libgit2 "repository path is not owned by
current user") and Homebrew refuses root outright; the script uses sudo
itself where needed.

**Nix installer: "Volume on diskNsM failed to mount", "/nix Read-only file
system".** The `/nix` firmlink did not exist yet. Reboot and re-run
`bootstrap.sh`; it now detects this state before starting the installer and
also spots a "Nix Store" volume left behind by the failed attempt, printing
the cleanup commands. Determinate also ships a graphical `.pkg` installer
(https://dtr.mn/determinate-nix); it drives the same installer engine, so it
is not expected to avoid this, and switching would trade the scriptable
`curl | sh` step for a download plus `installer -pkg`.

**`safari: this terminal has no Full Disk Access`.** Safari's preferences
live in its sandbox container, which TCC protects. System Settings >
Privacy & Security > Full Disk Access: add the terminal app (Terminal.app,
or whatever runs `drs`), open a new terminal window and run `drs` again.
The step also opens that pane for you.

**A cask asks for a password in the middle of `drs`.** Its installer needs
root and the sudo credential from the start of the run has expired (macOS
caches it for five minutes per terminal). Run `sudo -v` right before `drs`,
or answer the prompt; if the terminal is left printing staircase output
afterwards, `stty sane`.

**The rebuild stops and waits for input.** It should not: `drs` and
`bootstrap.sh` detach stdin so Homebrew's y/n prompts take their default.
If you ran `darwin-rebuild` by hand, add `< /dev/null`. `sudo` still asks
for the password via `/dev/tty`.

**`brew untap` reports a tap with stuck formulae.** Homebrew's untap
ignores `HOMEBREW_NO_ASK`. `brew-gc.nix` uses `untap --force`, which never
prompts; if a tap still survives, run `brew untap --force <tap>` once.

**`warning: brew update failed; continuing with the current index`.**
Network or GitHub hiccup while refreshing Homebrew's index. The rebuild
continues with the old index; re-run `drs` later.

**`brew bundle` says "VSCode is not installed" or can't find `mas`.** This
is what happens when `brew bundle` auto-updates and re-execs itself under
nix-homebrew's launcher. `homebrew.onActivation.autoUpdate` must stay
`false`; the index is refreshed in preActivation instead.

**Question-mark tiles in the Dock after the first run.** nix-darwin restarts
the Dock before Homebrew installs the pinned casks. `defaults.nix` restarts
it a second time when that happened; if a tile is still `?`, `killall Dock`.

**Finder windows disappear during `drs`.** Expected: Finder is restarted so
it picks up the declared view settings.

**"Nix warns that $HOME is not owned by root".** Run the rebuild with
`sudo -H`, as `drs` does.

**Activation fails because a file in `~` already exists.** Home-manager is
configured to back files up as `*.before-nix-darwin` rather than abort, so
this should not happen. If a backup from an earlier run is in the way,
delete it and re-run.

**Firefox ignores a new setting.** Policies apply on the next launch; quit
Firefox fully (⌘Q) and reopen. `about:policies` shows what is active and
flags errors. Prefs the `Preferences` policy refuses are listed in the
module header and in `mac-facts/firefox-prefs.txt`.

**Edits in uBlock Origin's "My filters" vanish.** The pane is overwritten
from `ublock-filters.txt` at every launch. Edit the file, `drs`, relaunch.

**VS Code says settings.json is read-only.** It is a symlink into the Nix
store. Change `modules/home/vscode.nix` and rebuild.

**Screenshots land on the Desktop.** macOS falls back silently when the
declared folder is missing. `modules/home/default.nix` creates
`~/Pictures/Screenshots`; if it was deleted, run `drs`.

**`wallpaper: declared Index.plist has no AllSpacesAndDisplays.Linked.Content`.**
The captured store file was taken while displays or Spaces had different
wallpapers. In System Settings set the wallpaper with all Spaces linked,
re-capture, and replace `modules/home/wallpaper/Index.plist`.

**`firefox-backups: … skipping` during `drs`.** Firefox or Proton Drive has
not been launched on this machine yet, or the profile `profiles.ini` names
is missing. Launch the missing app, sign in, and run `drs` again.

**`firefox-backups: quit Firefox and run drs again`.** The first link is
only made while Firefox is closed, so a snapshot in flight can't be lost.
Quit Firefox (⌘Q, not just close the window) and rebuild.

**Bookmark snapshots stopped appearing in Proton Drive.** Firefox only
writes a new snapshot when bookmarks changed since the last one, and only
during idle time or a clean quit. Check `<profile>/bookmarkbackups` is
still a symlink (`readlink`); a Firefox profile reset recreates it as a
plain directory, and the next `drs` fixes that.

**Nix was installed with the official installer, not Determinate.** Set
`nix.enable = true` in `hosts/macbook/default.nix` so nix-darwin manages
the daemon and `nix.conf`.

**Commits are not "Verified" on GitHub.** `sshSigningKey` must be non-empty
in `flake.nix`, 1Password's SSH agent must be on, and the same public key
must be added to GitHub as a signing key (not only an authentication key).
`git log --show-signature -1` shows whether signing happened locally.

**The machine's name changed (for example to `redxiii-2`).** A LAN name
clash made macOS rename it. `drs` still builds because the configuration
is addressed by name, and the switch sets `networking.hostName` back.
