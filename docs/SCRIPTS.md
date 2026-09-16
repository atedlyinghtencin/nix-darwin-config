# Scripts

Both capture scripts are read-only and must be run in macOS Terminal on the
machine being described. They write into `mac-facts/` at the repo root, which
is gitignored: review the output for anything private, merge what you want
to keep into the modules by hand, then run `drs`.

## scripts/collect-mac-facts.sh

```sh
./scripts/collect-mac-facts.sh
```

| Output in `mac-facts/` | Contents | Feeds |
|---|---|---|
| `identity.txt` | username, LocalHostName, ComputerName, full name, arch, macOS version, shell, global git identity | `vars` in `flake.nix` |
| `Brewfile`, `brew-leaves.txt`, `brew-casks.txt` | `brew bundle dump --describe`, leaf formulae, casks | `modules/darwin/homebrew.nix` |
| `mas-apps.txt` | `mas list` (or a note that mas is missing) | `masApps` |
| `applications.txt`, `applications-user.txt` | `/Applications` and `~/Applications` | casks installed outside Homebrew |
| `dock-apps.txt` | pinned Dock apps, in order | `dockApps` in `defaults.nix` |
| `defaults.txt` | `defaults read` of dock, finder, NSGlobalDomain, trackpad, screencapture, desktopservices, menu bar clock, spaces, screensaver, loginwindow. Finder's two recent-folder arrays are redacted (personal history) | `defaults.nix` |
| `wallpaper-index.plist` | the wallpaper store as XML (reference only; nothing declares it) | — |
| `vscode/settings.json`, `vscode/keybindings.json`, `vscode/snippets/` | VS Code user files | `modules/home/vscode.nix` |
| `home-dotfiles.txt`, `config-dir.txt`, `dotfile-contents.txt` | names and sizes of `~/.*` and `~/.config`, then the contents of `.zshrc`, `.zprofile`, `.zshenv`, `.gitconfig`, `.config/git/config`, `.gitignore_global`, `.ssh/config` | `zsh.nix`, `git.nix`, `ssh.nix` |
| `tools.txt` | where common tools resolve on `PATH`, plus `code --list-extensions` | `homebrew.vscode` |
| `fonts.txt` | user-installed fonts | `fonts.packages` |

`dotfile-contents.txt` can contain secrets. The script ends by printing a
`grep` for `token|secret|password|key` to run over it before sharing
anything.

## scripts/firefox_facts.py

```sh
./scripts/firefox_facts.py [--out DIR] [--profile DIR] [--root DIR]
```

| Flag | Default |
|---|---|
| `--out` | `mac-facts/` at the repo root, whatever the current directory |
| `--profile` | the default profile from `profiles.ini` (an `[Install*]` section wins over a `Default=1` flag) |
| `--root` | `~/Library/Application Support/Firefox` |

Reads only `profiles.ini`, `prefs.js`, `user.js` and `extensions.json`
(`user.js` overrides `prefs.js`, as Firefox does). Sessions, history, cookies
and logins are never opened. It also records the policies already in effect
from the user and system `org.mozilla.firefox` domains and from
`distribution/policies.json` inside Firefox.app.

| Output in `mac-facts/` | Contents |
|---|---|
| `firefox-addons.txt` | user-installed extensions: id, name, version, source URL, on/off |
| `firefox-prefs.txt` | every changed pref in four groups: settable via the `Preferences` policy, refused by it, blocked by Firefox, or Firefox-managed noise |
| `firefox-policies.txt` | what Firefox is already being told |
| `firefox.nix` | a ready-to-merge `"org.mozilla.firefox" = { ... }` block |

How prefs are classified:

- **Noise** (`NOISE` regex): timestamps, counters, ids, migration marks and
  UI state that Firefox writes for itself. Listed in the report, never
  rendered into Nix.
- **Allowed**: name starts with one of `ALLOWED_PREFIXES` or is in
  `ALLOWED_SECURITY`, copied from Firefox's `Policies.sys.mjs` (2026-09).
  Rendered as `{ Value = ...; Status = "user"; }`.
- **Blocked** (`BLOCKED`) or **not allowed**: rendered commented out. Where a
  dedicated policy exists (`POLICY_FOR`), the comment names it, for example
  `datareporting.healthreport.uploadEnabled` → `DisableTelemetry`.

Add-ons from addons.mozilla.org get the `latest.xpi` URL for their id; any
other source is pinned to the file that was installed. Disabled add-ons are
rendered commented out.

Merging: compare `mac-facts/firefox.nix` with `modules/darwin/firefox.nix`,
copy over the entries you want, keep the pruning notes in the module header
up to date, then `drs` and check `about:policies` in Firefox.

## scripts/test_firefox_facts.py

Unit tests for the parser, classifier, renderers, profile lookup and policy
collector. They run anywhere with Python 3, no Firefox needed:

```sh
python3 -m unittest discover -s scripts
```

18 tests as of 2026-09-13. Extend `ClassifyPrefs.test_noise_detection` when a
real profile turns up a bookkeeping pref that leaked into `firefox.nix`, or a
real setting that the noise regex swallowed.
