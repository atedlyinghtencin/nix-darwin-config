{ pkgs, ... }:
{
  # Things you already use, moved to nixpkgs (pinned by flake.lock).
  # Node and ffmpeg stay in Homebrew (see modules/darwin/homebrew.nix).
  home.packages = with pkgs; [
    git
    wget
    uv

    # quality-of-life additions (delete any you don't want)
    ripgrep
    fd
    bat
    eza
    jq
    tree
    htop
    gh

    # nix tooling
    nixfmt
    nil
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
}
