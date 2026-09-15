{ vars, ... }:
{
  imports = [
    ./packages.nix
    ./zsh.nix
    ./starship.nix
    ./git.nix
    ./ssh.nix
    ./wallpaper.nix
    ./vscode.nix
    ./firefox-backups.nix
    ./default-browser.nix
    ./safari.nix
  ];

  home.username = vars.username;
  home.homeDirectory = "/Users/${vars.username}";

  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "code --wait";
    PAGER = "less -R";
  };

  # macOS silently falls back to the Desktop if the declared screenshot folder
  # (system.defaults.screencapture.location) doesn't exist, so make sure it does.
  home.file."Pictures/Screenshots/.keep".text = "";

  # Let home-manager manage itself.
  programs.home-manager.enable = true;

  # Don't change after first install; see home-manager release notes.
  home.stateVersion = "25.05";
}
