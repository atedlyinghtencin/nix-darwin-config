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

  # Eastern US, fixed. "Set time zone automatically using your current
  # location" is off in defaults.nix; left on, it guessed Pacific and would
  # override this again. `sudo systemsetup -listtimezones` for other values.
  time.timeZone = "America/New_York";

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

  # sudo 1.9.14+ runs every command in a fresh pseudo-terminal, and its
  # credential cache is per terminal, so a cask that calls sudo inside a
  # rebuild found nothing cached and prompted "Password:" seconds after drs
  # itself had authenticated; the prompt also left that pty with echo off.
  # Run commands on the real terminal instead, so the credential drs (or
  # bootstrap.sh's keepalive) cached on it applies. Tradeoff: sudo's pty
  # isolation, which stops a command from injecting keystrokes into the
  # calling terminal, is off.
  security.sudo.extraConfig = "Defaults !use_pty";

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
