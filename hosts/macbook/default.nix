{ pkgs, vars, ... }:
{
  imports = [
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/brew-gc.nix
    ../../modules/darwin/firefox.nix
  ];

  networking.hostName = vars.hostname;
  networking.computerName = vars.computerName;

  # nix-darwin needs to know which user owns user-scoped settings
  # (Homebrew, system.defaults, etc.).
  system.primaryUser = vars.username;

  users.users.${vars.username} = {
    name = vars.username;
    home = "/Users/${vars.username}";
    shell = pkgs.zsh;
  };

  # bootstrap.sh installs Nix via the Determinate installer, which manages the
  # daemon and /etc/nix/nix.conf itself. Tell nix-darwin to leave it alone.
  # If you used the official installer instead, set this to true.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = vars.system;

  # System-wide CLI tools available to every user.
  environment.systemPackages = with pkgs; [
    git
    curl
    coreutils
  ];

  # zsh must be enabled system-wide for /etc/zshrc to source the Nix env.
  programs.zsh.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  # Application Firewall on, and don't answer probes (ping, port scans).
  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Backwards-compat marker; bump only after reading release notes.
  system.stateVersion = 6;
}
