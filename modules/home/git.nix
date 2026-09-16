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
      # Signing can live there too, when the public key should stay out of
      # this repo; the block below is the tracked alternative.
      include.path = "~/.gitconfig.local";

      # Local verification (`git log --show-signature`) of SSH-signed commits.
      # The file is untracked: one line per key, `<email> <public key>`.
      # Set here, not under the signing block, so it also covers keys that
      # come from ~/.gitconfig.local. Only read when verifying, so it is
      # harmless when it does not exist.
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
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
