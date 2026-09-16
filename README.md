# redxiii (nix-darwin)

Whole-machine declarative setup for an Apple Silicon MacBook: packages, GUI apps
(Homebrew), Mac App Store apps, macOS system defaults, Firefox policy, VS Code
and dotfiles (home-manager), all from one flake.

## Layout

```
flake.nix                  inputs + the `vars` block (username, hostname, email)
bootstrap.sh               fresh-Mac installer: CLT → Nix → darwin-rebuild
.github/workflows/ci.yml   GitHub Actions: `nix build` of the config on a macOS runner
hosts/macbook/default.nix  system config for this machine
modules/darwin/
  defaults.nix             macOS preferences (Dock, Finder, trackpad, text input…)
  homebrew.nix             casks, brews, VS Code extensions, Mac App Store apps
  brew-gc.nix              post-activation pass that really removes what cleanup missed
  firefox.nix              Firefox add-ons + about:config, as enterprise policy
  ublock-filters.txt       uBlock Origin "My filters", pushed in via firefox.nix
modules/home/
  default.nix              home-manager entry
  packages.nix             CLI tools from nixpkgs (+ fzf, zoxide, direnv)
  zsh.nix                  shell, aliases, history
  starship.nix             prompt
  git.nix                  git + delta + gh, optional SSH commit signing
  ssh.nix                  ssh via the 1Password agent
  vscode.nix               VS Code settings.json (extensions live in homebrew.nix)
  firefox-backups.nix      Firefox's daily bookmark snapshots land in Proton Drive
  default-browser.nix      Firefox as the default browser, via defaultbrowser (nixpkgs)
  safari.nix               Safari AutoFill off (1Password does it); needs Full Disk Access
  terminal.nix             Terminal.app profile with the Nerd Font, imported once and made the default
  terminal/nix-darwin.terminal  the exported Clear Dark profile, renamed, with the Nerd Font
scripts/
  collect-mac-facts.sh     read-only capture of the Mac's state into mac-facts/
  firefox_facts.py         read-only capture of Firefox add-ons + prefs as a firefox.nix draft
  test_firefox_facts.py    unit tests for firefox_facts.py
docs/                      architecture, module reference, runbook, scripts, decisions
```

## Docs

| File | Read it when |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | you want to know how the flake, the three layers and a `drs` run fit together |
| [docs/MODULES.md](docs/MODULES.md) | you are editing a module and want its options, capture date and gotchas |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | you are operating the machine: fresh install, updates, rollback, troubleshooting |
| [docs/SCRIPTS.md](docs/SCRIPTS.md) | you are re-capturing machine or Firefox state |
| [docs/DECISIONS.md](docs/DECISIONS.md) | you are about to change something the table below says is settled |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | you are making a change and want the checklist |
| [docs/CODEMAPS/](docs/CODEMAPS/) | token-lean maps of the module graph and dependencies, for AI context |

## Fresh install

Before you start:

- The macOS account name must equal `username` in `flake.nix` (`whoami`).
  `bootstrap.sh` stops with both values if they differ; either edit the
  `vars` block or rename the account.
- Run `bootstrap.sh` as that user, never with `sudo`. It asks for your
  password once, keeps the credential fresh for the whole run, and escalates
  on its own where it has to.
- Sign in to the Mac App Store first if `masApps` lists anything.

1. Clone and run:

   ```sh
   git clone <this repo> ~/.config/nix-darwin
   cd ~/.config/nix-darwin
   ./bootstrap.sh
   ```

2. If it stops with "Reboot, then run ./bootstrap.sh again", do exactly
   that. The Nix installer declared the `/nix` firmlink, and on a fresh
   macOS the firmlink only appears at the next boot. The second run installs
   Nix, then Rosetta 2 if it is missing, and builds.
3. When it prints "Done", open a new terminal so the declared shell, the
   `drs` alias and the Nerd Font profile load.
4. Work through [Manual steps after first bootstrap](#manual-steps-after-first-bootstrap).

From then on every change is `drs`. A rebuild that installs a cask whose
installer needs root asks for your password in the middle of the run; run
`sudo -v` right before `drs` so the credential is fresh, or type it when
asked. Details, adopting a Mac that already has software on it, and
troubleshooting in [docs/RUNBOOK.md](docs/RUNBOOK.md#fresh-machine).

## Manual steps after first bootstrap

What macOS and the apps do not let this repo set. Each is a one-time step
on a fresh machine.

- **1Password**: sign in, then Settings > Developer > "Use the SSH agent".
  Private host blocks go in `~/.ssh/config.local` (see below). To sign
  commits, put the key's public half in `sshSigningKey` in `flake.nix`, run
  `drs`, and add the same key to GitHub as a signing key.
- **Firefox**: launch it once. The policy installs the add-ons (1Password,
  Proton Pass, OneTab, uBlock Origin) and applies the prefs on first start.
  After any rebuild that changes `firefox.nix`, quit Firefox fully (⌘Q)
  and relaunch; policies are read at startup. 1Password and Proton Pass
  each need a one-time sign-in in the extension.
- **Proton Pass extension, first launch**: Settings > disable Autofill,
  Autosave, Autosuggest, and Passkeys. These are stored in the extension
  and cannot be set by this config.
- **Default browser**: the first rebuild after Firefox is installed runs
  `defaultbrowser firefox`, and macOS asks "Do you want to change your
  default web browser?" once. Accept it. That dialog cannot be suppressed
  without MDM; if LaunchServices did not know Firefox yet, the step says so
  and the next `drs` asks again.
- **Proton Drive**: sign in, then run `drs` again so Firefox's bookmark
  snapshots start landing in it.
- **Full Disk Access** (System Settings > Privacy & Security > Full Disk
  Access; TCC, so no config can grant it):
  - Terminal.app, or whatever runs `drs`: `modules/home/safari.nix` writes
    Safari's preferences, which live in its sandbox container. Without the
    grant that step warns and opens this pane.
  - AppCleaner.app: it removes app support files under
    `~/Library/Containers`, which are protected the same way.
- **Safari AutoFill**: turned off by `modules/home/safari.nix` once
  Terminal has Full Disk Access. Open a new terminal window after granting
  it, quit Safari, run `drs`, then check with
  `defaults read com.apple.Safari AutoFillPasswords` (prints `0`).
- **System Settings > General > AutoFill & Passwords**: enable 1Password,
  disable Passwords (iCloud Keychain).
- **Log out and back in once**: "Displays have separate Spaces" is turned
  off by `defaults.nix` (`spaces.spans-displays = true`, nix-darwin's
  inverted name), which stops the Dock from jumping to whichever display
  the pointer is on. macOS only reads it at login.
- **OrbStack**: launch it once and accept the macOS permission dialogs it
  raises. Docker, and with it VS Code Dev Containers, only works while
  OrbStack is running: open it before using Dev Containers, or turn on
  start at login in OrbStack > Settings so it is always up.
- **Terminal profile**: the first rebuild adds the `nix-darwin` profile
  (Clear Dark colours, JetBrainsMono Nerd Font 12 pt, 120 x 30) and makes
  it the default. Terminal only reads profiles at launch, so quit it (⌘Q)
  and reopen; until then windows keep the old profile. To change it, export
  from Terminal > Settings > Profiles > gear > Export and replace
  `modules/home/terminal/nix-darwin.terminal`, keeping the name `nix-darwin`
  and the Nerd Font (see the comment in `modules/home/terminal.nix`).

## Day to day

| Command | What it does |
|---|---|
| `drs` | `darwin-rebuild switch` — apply changes in this repo |
| `dru` | update all flake inputs, then switch |
| `darwin-rebuild --list-generations` | see history |
| `sudo darwin-rebuild switch --rollback` | undo the last switch |
| `nix fmt` | format all `.nix` files |
| `python3 -m unittest discover -s scripts` | test the Firefox capture script |

Edit a `.nix` file, run `drs`, done. `flake.lock` is deliberately untracked
(see `.gitignore`): `dru`, a fresh clone and every CI run resolve all inputs
to their latest revisions, while a plain `drs` reuses the last lock. Rolling policy — upstream breakage lands whenever it lands; to pin
a known-good state instead, remove `flake.lock` from `.gitignore` and commit it.

## Where things go

- **CLI tool** → `modules/home/packages.nix` (nixpkgs first; search at search.nixos.org)
- **GUI app** → `modules/darwin/homebrew.nix` `casks`
- **App Store app** → `masApps` (`mas search <name>` for the ID)
- **VS Code extension** → `modules/darwin/homebrew.nix` `vscode` (IDs from `code --list-extensions`)
- **VS Code setting** → `modules/home/vscode.nix` (the Settings UI can't save; settings.json is a store symlink)
- **macOS setting** → `modules/darwin/defaults.nix` (option list in the
  [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/))
- **Re-capture machine facts** → `./scripts/collect-mac-facts.sh` (run in macOS Terminal)
- **Firefox add-on / setting** → `modules/darwin/firefox.nix`. To re-capture what
  Firefox currently has, run `./scripts/firefox_facts.py` (macOS Terminal) and
  merge `mac-facts/firefox.nix` in by hand.
- **uBlock Origin custom filter** → `modules/darwin/ublock-filters.txt` (one filter
  per line; overwrites the "My filters" pane on every Firefox launch)
- **Firefox bookmarks** → backed up to Proton Drive daily by `modules/home/firefox-backups.nix`;
  restore is a few clicks in Firefox, see [docs/RUNBOOK.md](docs/RUNBOOK.md#restoring-firefox-bookmarks)
- **Secrets / work-only config** → `~/.zshrc.local`, `~/.gitconfig.local`,
  `~/.ssh/config.local` (private hosts) — sourced if present, never tracked.
  Generic ssh options live in `modules/home/ssh.nix`; host names and users
  go in `config.local`. Private keys live in 1Password, not in `~/.ssh`

## Decisions

Settled choices and why. Revisit only with new evidence; the full context
for each is in [docs/DECISIONS.md](docs/DECISIONS.md).

| Decision | Why |
|---|---|
| `flake.lock` is untracked (rolling inputs) | Fix forward rather than pin; every rebuild pulls the latest nixpkgs, nix-darwin, home-manager. |
| Automation never prompts | Rebuilds run with stdin detached so Homebrew can't stop for y/n; anything declared as removed is actually removed (`brew-gc.nix`), never deferred to a manual command. |
| Homebrew for GUI apps, nixpkgs for CLI tools | Casks integrate with macOS (updates, launch services); CLI tools are pinned and reproducible via the flake. |
| Nix via the Determinate installer, `nix.enable = false` | Survives macOS upgrades and owns the daemon; nix-darwin is told not to fight it. |
| Firefox configured as enterprise policy, not Sync or `programs.firefox` | No Firefox account; the Homebrew cask honours `org.mozilla.firefox` policy, and `programs.firefox` would want the nixpkgs build. |
| Configuration named explicitly (`#redxiii`) in bootstrap and `drs` | A machine renamed by a LAN name clash (e.g. a VM getting "-2") must still build. |
| `sudo -H` for rebuilds | Nix warns when `$HOME` isn't owned by root otherwise. |
| SSH keys and commit signing through 1Password, no GPG | One agent for every key, unlocked by Touch ID; nothing secret in `~/.ssh` or `~/.gnupg` to back up. Set `sshSigningKey` in `flake.nix` to turn signing on. |
| VS Code settings declared, extensions via Homebrew, Copilot off | Every editor change goes through the repo; `brew bundle` installs extensions and `brew-gc.nix` removes the rest. |
| Firefox bookmarks backed up to Proton Drive, restored by hand | Firefox already snapshots bookmarks daily; a symlink sends them off-machine with no account, no Sync and no live database on a synced folder. |
| CI only evaluates and builds, never activates | Catches Nix errors on every push; behaviour (Homebrew, defaults, Firefox) is verified in a tart VM. |

## Notes

- `homebrew.onActivation.cleanup = "zap"` removes any cask/brew not listed. If
  you want to keep manually-installed apps, change it to `"none"`.
- `nix.enable = false` in `hosts/macbook/default.nix` is required with the
  Determinate installer. If you install Nix another way, set it to `true`.
- First `bootstrap.sh` run takes a while (it builds/downloads everything).
