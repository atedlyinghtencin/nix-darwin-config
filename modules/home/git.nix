{ vars, lib, ... }:
{
  programs.git = {
    enable = true;

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "result"
      ".claude/settings.local.json" # per-checkout Claude Code permissions
    ];

    settings = lib.mkMerge [ {
      user = {
        name = vars.fullName;
        email = vars.email;
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      rebase.autoStash = true;
      merge.conflictStyle = "zdiff3";
      diff.algorithm = "histogram";
      rerere.enabled = true;
      core.autocrlf = "input";

      # Drop work-specific identity overrides in ~/.gitconfig.local (untracked).
      include.path = "~/.gitconfig.local";
    } (lib.mkIf (vars.sshSigningKey != "") {
      # Commits signed with an SSH key held in 1Password (no GPG involved).
      # Add the same public key to GitHub as a *signing* key for "Verified".
      gpg.format = "ssh";
      gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      user.signingkey = vars.sshSigningKey;
      commit.gpgsign = true;
      tag.gpgsign = true;
    }) ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true;
    };
  };

  programs.gh.enable = true;
}
