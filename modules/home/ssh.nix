{ config, ... }:
let
  # 1Password 8's group container (team ID + bundle ID); the same on every Mac.
  onePasswordAgent = "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # OrbStack's `orb` host, then machine-local, untracked hosts (private
    # servers, work). Host blocks go in those files, not here; a missing file
    # is skipped silently.
    includes = [
      "~/.orbstack/ssh/config"
      "~/.ssh/config.local"
    ];

    # Generic settings for every host. ssh keeps the first value it finds, so
    # a host block in config.local can still override any of these. The
    # includes above are written before this block for the same reason.
    #
    # Private keys live in 1Password, not in ~/.ssh: its agent answers every
    # connection once "Use the SSH agent" is on in 1Password → Settings →
    # Developer. Host blocks in config.local need no IdentityFile; to pin a
    # key per host, point IdentityFile at a public .pub file instead.
    settings."*" = {
      IdentityAgent = ''"${onePasswordAgent}"''; # quoted: path has spaces
    };
  };

  # For tools that talk to the agent directly (ssh-add -l, git over ssh in
  # editors) rather than through ssh_config.
  home.sessionVariables.SSH_AUTH_SOCK = onePasswordAgent;
}
