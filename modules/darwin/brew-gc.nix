{ config, lib, ... }:
let
  cfg = config.homebrew;

  entryName = e: if builtins.isString e then e else e.name;
  keepFormulae = map entryName cfg.brews;
  keepCasks = map entryName cfg.casks;

  # A fully-qualified name like "openai/tools/tart" implies its tap is kept.
  impliedTaps = lib.filter (t: t != null) (
    map (
      n:
      let
        parts = lib.splitString "/" n;
      in
      if builtins.length parts >= 3 then lib.concatStringsSep "/" (lib.take 2 parts) else null
    ) (keepFormulae ++ keepCasks)
  );
  keepTaps = map entryName cfg.taps ++ impliedTaps;
  # `code --list-extensions` prints publisher IDs in their own case
  # (e.g. GitHub.copilot); compare lower-cased on both sides.
  keepExtensions = map lib.toLower cfg.vscode;

  zapFlag = lib.optionalString (cfg.onActivation.cleanup == "zap") "--zap ";
in
{
  # `brew bundle --force-cleanup` uninstalls everything unmanaged in ONE batch.
  # A single protected shared dependency in that batch ("Error: Refusing to
  # uninstall X because it is required by Y") aborts the whole batch, so on a
  # machine with pre-existing Homebrew packages nothing actually gets removed
  # (bundle's "Uninstalled N formulae" line is the list size, not reality),
  # and the `brew untap` that follows can stop and prompt y/n about a tap
  # whose formulae are still installed.
  #
  # This pass runs right after the homebrew activation step and converges for
  # real: peel unmanaged leaf formulae one at a time (dependencies that kept
  # packages genuinely need are refused individually by brew and correctly
  # survive), then remove unmanaged casks, then `untap --force` stray taps —
  # which uninstalls their remaining packages and never prompts, TTY or not.
  system.activationScripts.postActivation.text =
    lib.mkIf (cfg.enable && cfg.onActivation.cleanup != "none")
      ''
        echo "collecting Homebrew garbage..."
        (
          set +e
          export PATH="${cfg.prefix}/bin:$PATH"

          # run a command as the Homebrew user (brew itself, or the `code` CLI)
          as_user() {
            sudo --preserve-env=PATH --user=${lib.escapeShellArg cfg.user} --set-home env "$@"
          }
          brew_gc() { as_user HOMEBREW_NO_AUTO_UPDATE=1 brew "$@"; }

          # kept <name> <keep-list...>: exact or basename match (brew may print
          # "openai/tools/tart" where the Brewfile says "tart", or vice versa)
          brew_gc_kept() {
            local name=$1 k
            shift
            for k in "$@"; do
              [[ $name == "$k" || ''${name##*/} == "''${k##*/}" ]] && return 0
            done
            return 1
          }

          keep_formulae=(${lib.escapeShellArgs keepFormulae})
          keep_casks=(${lib.escapeShellArgs keepCasks})
          keep_taps=(${lib.escapeShellArgs keepTaps})

          # Formulae: each removed leaf can orphan its deps into new leaves,
          # so iterate until a full pass removes nothing (capped for safety).
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            changed=0
            for f in $(brew_gc leaves 2>/dev/null); do
              brew_gc_kept "$f" "''${keep_formulae[@]}" && continue
              if brew_gc uninstall --formula "$f" >/dev/null 2>&1; then
                echo "brew-gc: uninstalled formula $f"
                changed=1
              fi
            done
            [[ $changed == 1 ]] || break
          done

          for c in $(brew_gc list --cask 2>/dev/null); do
            brew_gc_kept "$c" "''${keep_casks[@]}" && continue
            if brew_gc uninstall --cask ${zapFlag}--force "$c" >/dev/null 2>&1; then
              echo "brew-gc: uninstalled cask $c"
            fi
          done

          # VS Code extensions: bundle's cleanup takes them alphabetically in
          # one pass, so an extension another one depends on ("Docker" needs
          # "Container Tools") survives until the next rebuild. Iterate here
          # like formulae. `code` is the cask's link in the Homebrew prefix;
          # the extensions live in the user's home, hence the user switch.
          keep_extensions=(${lib.escapeShellArgs keepExtensions})
          code_cli=${lib.escapeShellArg "${cfg.prefix}/bin/code"}
          if [[ -x $code_cli ]]; then
            for _ in 1 2 3 4 5 6 7 8 9 10; do
              changed=0
              for e in $(as_user "$code_cli" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]'); do
                brew_gc_kept "$e" "''${keep_extensions[@]}" && continue
                if as_user "$code_cli" --uninstall-extension "$e" >/dev/null 2>&1; then
                  echo "brew-gc: uninstalled VS Code extension $e"
                  changed=1
                fi
              done
              [[ $changed == 1 ]] || break
            done
          fi

          for t in $(brew_gc tap 2>/dev/null); do
            [[ $t == homebrew/* ]] && continue
            brew_gc_kept "$t" "''${keep_taps[@]}" && continue
            if brew_gc untap --force "$t" >/dev/null 2>&1; then
              echo "brew-gc: untapped $t"
            fi
          done
          exit 0
        )
      '';
}
