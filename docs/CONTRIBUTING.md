# Contributing

This is a one-machine, one-owner configuration, so "contributing" mostly
means future-you making a change without breaking the Mac. The same rules
apply to anyone sending a pull request.

## Prerequisites

- To **edit and format**: Nix anywhere (`nix fmt` uses `nixfmt`), or just
  `nixfmt` from `modules/home/packages.nix`.
- To **build**: a Mac with Nix. The configuration is `aarch64-darwin` and
  cannot be built on Linux; CI does it on a hosted macOS runner.
- To **run the script tests**: Python 3, nothing else.

## Workflow

1. Edit the module that owns the setting (the table in
   [RUNBOOK.md](RUNBOOK.md#where-a-change-goes) says which).
2. `nix fmt`.
3. Build without activating, on a Mac:

   ```sh
   nix build .#darwinConfigurations.redxiii.system --no-link --print-build-logs
   ```

   Anywhere else, push a branch and let CI do the same.
4. If you touched `scripts/firefox_facts.py`, run its tests:

   ```sh
   python3 -m unittest discover -s scripts
   ```

   Add a case first when fixing a classification bug (a bookkeeping pref
   that leaked through, or a real setting the noise regex swallowed).
5. Apply with `drs` and check the result on the machine. Anything that
   touches Homebrew cleanup, Dock, Finder, Firefox policy or the wallpaper
   is worth trying in a tart VM first.
6. Update the docs that describe what you changed (table below).
7. Commit.

## Commit messages

Conventional-commit style:

```
<type>: <imperative, lower-case description>

<optional body: why, and anything a future reader would need>
```

Types in use so far: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`,
`revert`; use `test` for test-only changes. A decision that future changes should respect goes into the body
and into [DECISIONS.md](DECISIONS.md).

## What never gets committed

| Thing | Where it lives instead |
|---|---|
| `flake.lock` | nowhere; inputs roll (see DECISIONS.md) |
| `mac-facts/` | local capture output, review and merge by hand |
| `result`, `result-*`, `.direnv/`, `.reports/`, `__pycache__/`, `.DS_Store` | build and tool artefacts |
| secrets, work identities, private hosts | `~/.zshrc.local`, `~/.gitconfig.local`, `~/.ssh/config.local` |
| private keys | 1Password |

`scripts/collect-mac-facts.sh` prints a `grep` for secrets over its own
output; run it before pasting anything from `mac-facts/` into a module.

## Adding a module

- System-level: create `modules/darwin/<name>.nix` and add it to the
  `imports` in `hosts/macbook/default.nix`.
- User-level: create `modules/home/<name>.nix` and add it to the `imports`
  in `modules/home/default.nix`.
- Take `vars`, `lib`, `pkgs` or `config` from the module arguments as
  needed; `vars` is passed to both layers.
- Put the "why" in a header comment and the capture date if the values came
  off the machine.

## Keeping the docs true

| If you change… | Update |
|---|---|
| a module's purpose, options or captured date | `docs/MODULES.md` |
| the module graph, activation hooks or flake inputs | `docs/ARCHITECTURE.md`, `docs/CODEMAPS/architecture.md`, `docs/CODEMAPS/dependencies.md` |
| a Homebrew, cask, extension or package list | `docs/CODEMAPS/dependencies.md`, the counts in `docs/MODULES.md` |
| a script's flags or outputs | `docs/SCRIPTS.md` |
| an alias, a workflow, or a failure mode you had to debug | `docs/RUNBOOK.md` |
| a settled choice | `docs/DECISIONS.md` and the summary table in `README.md` |
| the file layout | the layout block in `README.md` |

## CI

`.github/workflows/ci.yml` runs on every push to `main`, every pull request
and on manual dispatch. It evaluates and builds the system closure with a
45-minute timeout and read-only permissions; it never activates. A red run
usually means a Nix error in the change or an upstream input that moved
under it (the lock file is untracked); the runbook covers both.
