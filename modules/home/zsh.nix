{ vars, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    autocd = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --level=2 --icons";
      cat = "bat --paging=never";
      g = "git";
      ".." = "cd ..";
      "..." = "cd ../..";
      dnsflush = "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder";

      # rebuild this machine from the repo
      # stdin detached so Homebrew can never stop and ask y/n mid-rebuild
      # (its prompts only fire on a TTY); sudo asks via /dev/tty regardless.
      # The configuration is named explicitly (same as bootstrap.sh) so a
      # renamed machine, e.g. a VM that got "-2" from a LAN name clash, still
      # builds instead of looking up a configuration by its current hostname.
      drs = "sudo -H darwin-rebuild switch --flake ~/.config/nix-darwin#${vars.hostname} < /dev/null";
      dru = "nix flake update --flake ~/.config/nix-darwin && drs";
    };

    # ~/.zshenv, read before /etc/zshrc. Apple's /etc/zshrc would otherwise
    # start Terminal.app's per-window session files (~/.zsh_sessions), which
    # fight the shared history above. nix-darwin's /etc/zshrc doesn't source
    # that hook, so this is belt and braces for any shell that isn't started
    # through it.
    envExtra = ''
      export SHELL_SESSIONS_DISABLE=1
    '';

    initContent = ''
      setopt HIST_REDUCE_BLANKS
      setopt INTERACTIVE_COMMENTS
      bindkey -e
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward

      # make a directory and cd into it
      mkcd() { mkdir -p "$1" && cd "$1"; }

      # listening TCP ports with their owning process; `ports 3000` filters
      ports() { lsof -nP -iTCP''${1:+":$1"} -sTCP:LISTEN; }

      # Homebrew on Apple Silicon (was in ~/.zprofile)
      [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

      # OrbStack CLI tools + integration (was in ~/.zprofile)
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :

      # uv-installed tools (was in ~/.zshrc)
      [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

      # machine-local, untracked extras (secrets, work-only aliases)
      [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
    '';
  };
}
