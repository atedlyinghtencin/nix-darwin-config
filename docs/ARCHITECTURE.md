# Architecture

How the pieces of this repo fit together and what actually happens when you
run `drs`. For the per-file reference see [MODULES.md](MODULES.md); for
day-to-day operations see [RUNBOOK.md](RUNBOOK.md).

## One flake, one machine

`flake.nix` is the single entry point. Its `vars` block (username, hostname,
computer name, git identity, platform, optional signing key) is the only
machine-specific data in the repo; everything else reads from it via
`specialArgs` / `extraSpecialArgs`.

The flake exposes exactly one system, `darwinConfigurations.redxiii`, built
with `nix-darwin.lib.darwinSystem` from three module groups:

```
flake.nix
└── darwinConfigurations.redxiii
    ├── hosts/macbook/default.nix          system layer (nix-darwin)
    │   ├── modules/darwin/defaults.nix      macOS preferences + Dock/Finder fixes
    │   ├── modules/darwin/homebrew.nix      Brewfile: taps, brews, casks, VS Code ext, mas
    │   ├── modules/darwin/brew-gc.nix       post-activation garbage collector
    │   └── modules/darwin/firefox.nix       Firefox enterprise policy
    │       └── modules/darwin/ublock-filters.txt
    ├── nix-homebrew.darwinModules           installs/pins Homebrew itself
    └── home-manager.darwinModules           user layer (home-manager)
        └── modules/home/default.nix
            ├── packages.nix    CLI tools + fzf/zoxide/direnv
            ├── zsh.nix         shell, aliases (drs/dru), history
            ├── starship.nix    prompt
            ├── git.nix         git + delta + gh, optional SSH signing
            ├── ssh.nix         1Password agent, config.local include
            ├── vscode.nix      settings.json (store symlink)
            ├── firefox-backups.nix  bookmarkbackups → Proton Drive symlink
            ├── default-browser.nix  defaultbrowser firefox, once
            ├── safari.nix           AutoFill off, only with Full Disk Access
            └── terminal.nix         Nerd Font profile (+ terminal/nix-darwin.terminal), imported once
```

The configuration is always addressed by its explicit name (`#redxiii`) in
`bootstrap.sh`, the `drs` alias and CI, never by looking up the current
hostname. A machine that macOS renamed (for example a VM that got `-2` after
a LAN name clash) still builds, and the switch sets the name back.

## Three layers, three package managers

| Layer | Tool | Manages | Declared in |
|---|---|---|---|
| System | nix-darwin | hostname, users, `system.defaults`, fonts, firewall, Touch ID sudo, `/etc/zshrc` | `hosts/macbook/default.nix`, `modules/darwin/*` |
| Homebrew | nix-homebrew + `homebrew.*` | GUI apps (casks), formulae that need macOS integration, VS Code extensions, App Store apps | `modules/darwin/homebrew.nix` |
| User | home-manager | dotfiles, CLI tools from nixpkgs, shell, git, ssh, VS Code settings | `modules/home/*` |

nix-homebrew installs Homebrew into its default prefix (`/opt/homebrew`) from the Nix store
(`autoMigrate` adopts a pre-existing install) and enables Rosetta for
Intel-only casks. The `homebrew.*` options then generate a Brewfile that
`brew bundle` applies on every switch.

Nix itself is installed by the Determinate installer, which owns the daemon
and `/etc/nix/nix.conf`; `nix.enable = false` tells nix-darwin not to manage
either.

## What a rebuild does

`drs` expands to:

```sh
sudo -H darwin-rebuild switch --flake ~/.config/nix-darwin#redxiii < /dev/null
```

1. **Evaluate and build.** The flake is evaluated with whatever `flake.lock`
   resolves to right now (the lock file is untracked, so `dru`, a fresh
   clone or a CI run resolves inputs to their latest revisions), and the system closure is built or downloaded
   into the Nix store. Nothing on the machine changes yet.
2. **Activate** (as root, stdin detached so nothing can prompt):

   | Step | Source | What happens |
   |---|---|---|
   | preActivation | `homebrew.nix` | If `/opt/homebrew/bin/brew` is already a Nix-store symlink, run `brew update` as the user. A failure is a warning, never an abort. |
   | preActivation | `defaults.nix` | Check whether every app pinned to the Dock exists; remember if any is missing. |
   | userDefaults (nix-darwin) | `defaults.nix`, `firefox.nix` | Write every `system.defaults.*` key, including the `org.mozilla.firefox` policy domain, then restart the Dock. |
   | homebrew (nix-darwin) | `homebrew.nix` | `brew bundle --force --quiet`: install taps, formulae, casks, VS Code extensions and mas apps; upgrade; `cleanup = "zap"` removes what is not listed. |
   | postActivation | home-manager | Write dotfiles into `~` (pre-existing files are moved aside as `*.before-nix-darwin`), then run the Firefox-backup, default-browser, Safari and Terminal-profile activations. |
   | postActivation | `defaults.nix` | `activateSettings -u`, delete `/Applications/.DS_Store`, restart Finder, and restart the Dock a second time if a pinned app was only just installed. |
   | postActivation | `brew-gc.nix` | Converge for real: uninstall unmanaged leaf formulae iteratively, unmanaged casks (`--zap`), unmanaged VS Code extensions iteratively, then `untap --force` stray taps. |

   The three postActivation rows are fragments of one step; their order
   relative to each other is module-merge order and nothing here depends on
   it. All fragments run in one shell, which is why a variable set in
   preActivation is still visible in postActivation.
3. **Record a generation.** `darwin-rebuild --list-generations` shows them;
   `sudo darwin-rebuild switch --rollback` returns to the previous one.

Why the Dock is restarted twice, why `brew update` is separate from
`brew bundle`, and why `brew-gc.nix` exists at all are recorded in
[DECISIONS.md](DECISIONS.md).

## The capture loop

Declarations in this repo were captured from the Mac first, so that the first
rebuild changed nothing the machine did not already have. The same loop is
how new state gets declared:

```
       macOS Terminal (never a Linux container)
  ┌──────────────────────────────────────────────┐
  │ ./scripts/collect-mac-facts.sh                │ read-only
  │ ./scripts/firefox_facts.py                    │ read-only
  └──────────────────────┬───────────────────────┘
                         ▼
               mac-facts/  (gitignored, review for secrets)
                         │  hand-merge what you want to keep
                         ▼
   modules/darwin/*.nix   modules/home/*.nix
                         │
                         ▼
                        drs
```

Nothing in `mac-facts/` is applied automatically; the modules whose values
came off the machine (`defaults.nix`, `homebrew.nix`, `firefox.nix`,
`vscode.nix`) carry the date of the capture they were pruned from. See [SCRIPTS.md](SCRIPTS.md).

## What stays outside the repo

Machine-local and private state is read from untracked files if they exist
and silently skipped otherwise:

| File | Read by | For |
|---|---|---|
| `~/.zshrc.local` | `zsh.nix` | secrets, work-only aliases |
| `~/.gitconfig.local` | `git.nix` | work identity overrides, signing when the key stays untracked |
| `~/.ssh/allowed_signers` | `git.nix` | public keys `git log --show-signature` trusts |
| `~/.ssh/config.local` | `ssh.nix` | private host blocks |
| `~/.orbstack/ssh/config` | `ssh.nix` | OrbStack's `orb` host |
| `~/.local/bin/env` | `zsh.nix` | uv-installed tools |
| `~/.orbstack/shell/init.zsh` | `zsh.nix` | OrbStack CLI integration |

Private keys are not files at all: SSH authentication goes through the
1Password agent socket and commit signing through 1Password's `op-ssh-sign`.

Note that home-manager writes the git config to `~/.config/git/config`, not
`~/.gitconfig`. Git reads both, and a stray `~/.gitconfig` wins on every
conflict and captures `git config --global` writes, so it should not exist;
move anything found there into `~/.gitconfig.local`.

One thing flows the other way. Firefox's daily bookmark snapshots are written
into Proton Drive through a symlink, so they leave the machine without any
sync account; the Proton Drive folder is found by pattern under
`~/Library/CloudStorage`, so the account name never appears in the repo.

## Continuous integration

`.github/workflows/ci.yml` runs `nix build` of the system closure on a hosted
macOS runner for every push to `main`, every pull request, and on demand. It
catches Nix syntax errors, unknown options and type errors, and, because the
lock file is untracked, proves the inputs still resolve. It never activates:
no `brew bundle`, no `defaults write`, no home-manager switch. Behaviour is
verified by hand in a tart VM (tart is one of the declared brews).
