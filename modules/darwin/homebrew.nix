{ config, lib, ... }:
let
  cfg = config.homebrew;
in
{
  # Generated from `brew bundle dump` on 2026-08-20, plus apps found in
  # /Applications that were installed outside Homebrew.
  homebrew = {
    enable = true;

    onActivation = {
      # Off on purpose; the index is refreshed by the explicit `brew update`
      # in preActivation below. When `brew bundle` auto-updates it re-execs
      # itself, and nix-homebrew's generated launcher then records the
      # launcher's own reduced PATH as the "original" one (upstream bin/brew
      # restores it from HOMEBREW_PATH on that second pass; nix-homebrew's
      # copy of that script omits the block). The second pass can no longer
      # find `code` or `mas`, so VS Code extensions fail with "VSCode is not
      # installed" and App Store apps would fail the same way.
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap"; # uninstall anything Homebrew-managed that isn't listed here
      # --force lets casks adopt/overwrite existing apps and syncs the tap
      # trust store to this Brewfile. `brew bundle` is otherwise already
      # non-interactive (it sets HOMEBREW_NO_ASK=1 itself), with one known
      # exception: the `brew untap` it spawns during cleanup still prompts
      # y/n if a tap's formulae couldn't be uninstalled first, because
      # cmd/untap.rb ignores HOMEBREW_NO_ASK (Homebrew bug as of 6.x).
      # Only leftover taps with stuck formulae hit this (e.g. CI taps in
      # the tart VM base image); clear them with `brew untap --force <tap>`.
      # --quiet drops the one "Using <name>" line per already-installed entry
      # (48 of them on a converged machine) so the bundle output is just what
      # changed, in green, plus the summary. Errors are unaffected.
      extraFlags = [ "--force" "--quiet" ];
    };

    # tart + softnet (Cirrus Labs joined OpenAI 2026-04). trusted = true
    # satisfies Homebrew 6.0's tap-trust gate without an interactive prompt.
    taps = [
      {
        name = "openai/tools";
        trusted = true;
      }
    ];

    # Kept in Homebrew rather than nixpkgs where macOS integration matters
    # (cloudflared launchd service, ffmpeg codecs).
    brews = [
      "ansible"
      "ansible-lint"
      "cloudflared"
      "f3"
      "ffmpeg"
      "mas"
      "nmap"
      "node"
      "node@22"
      "poppler"
      "qrencode"
      "openai/tools/tart" # VM tooling; pulls in softnet
      "tcpdump"
      "yamllint"
      "yt-dlp"
    ];

    casks = [
      "1password" # SSH agent (modules/home/ssh.nix) + commit signing (modules/home/git.nix)
      "1password-cli" # `op`: passwords in the terminal
      "adobe-creative-cloud"
      "appcleaner"
      "claude"
      "google-chrome"
      "itsytv"
      "kdenlive"
      "libreoffice"
      "orbstack"
      "proton-drive"
      "proton-mail"
      "proton-pass"
      "protonvpn"
      "royal-tsx"
      "visual-studio-code"
      "vlc"
      "wireshark-app"

      # previously installed by hand; now managed here
      "discord"
      "dropbox"
      "firefox"
      # "adobe-acrobat-reader" # currently Acrobat DC via Creative Cloud
    ];

    # VS Code extensions, installed through the `code` CLI by `brew bundle`
    # and removed by its cleanup when dropped from this list. IDs come from
    # `code --list-extensions` (captured in mac-facts/tools.txt).
    vscode = [
      "mechatroner.rainbow-csv"
      "ms-python.debugpy"
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.vscode-python-envs"
      "ms-vscode-remote.remote-containers"
      "ms-vscode.makefile-tools"
      "yzhang.markdown-all-in-one"
    ];

    # `mas search <name>` for IDs. Requires App Store sign-in.
    masApps = {
      # "Keynote" = 409183694;
      # "Numbers" = 409203825;
      # "Pages" = 409201541;
    };
  };

  # Refresh Homebrew's formula and cask index before the bundle step, in place
  # of the auto-update disabled above. Only once nix-homebrew owns the install
  # (its bin/brew is a symlink into the Nix store): that skips the first
  # bootstrap, and on a Mac with a pre-nix Homebrew it avoids running the old
  # self-updating brew right before nix-homebrew replaces it in this same
  # activation. A failed refresh never aborts the rebuild.
  system.activationScripts.preActivation.text = ''
    case "$(readlink ${lib.escapeShellArg "${cfg.prefix}/bin/brew"} 2>/dev/null)" in
    ${builtins.storeDir}/*)
      echo >&2 "updating Homebrew..."
      sudo --user=${lib.escapeShellArg cfg.user} --set-home \
        env HOMEBREW_NO_ENV_HINTS=1 ${lib.escapeShellArg "${cfg.prefix}/bin/brew"} update --quiet \
        || echo >&2 "warning: brew update failed; continuing with the current index"
      ;;
    esac
  '';
}
