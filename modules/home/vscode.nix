{ pkgs, ... }:
{
  # VS Code user settings, captured from the Mac on 2026-09-13. The file is a
  # read-only symlink into the Nix store, so the Settings UI can no longer
  # save: change a value here and rebuild. Extensions are installed by
  # Homebrew (homebrew.vscode in modules/darwin/homebrew.nix), not here.
  home.file."Library/Application Support/Code/User/settings.json".source =
    (pkgs.formats.json { }).generate "vscode-settings.json" {
      "workbench.colorTheme" = "Solarized Dark";
      "git.autofetch" = true;
      "git.enableSmartCommit" = true;
      "window.restoreWindows" = "none";

      # First-launch and startup noise. The theme picker on a fresh install
      # is part of the "Get Started" walkthrough, so turning that off skips
      # it; the theme is already set above.
      "workbench.startupEditor" = "none";
      "workbench.welcomePage.walkthroughs.openOnInstall" = false;
      "update.showReleaseNotes" = false;
      "extensions.ignoreRecommendations" = true;

      # GitHub Copilot is built into VS Code now (chat view, title-bar button,
      # inline suggestions, "set up Copilot" prompts). This one switch hides
      # and disables all of it; the Copilot extensions are not installed.
      "chat.disableAIFeatures" = true;

      # Started from the Dock, VS Code reads the login shell's environment,
      # which now waits on a keychain approval for GH_TOKEN (zsh.nix). The
      # default 10 s is short for typing a password.
      "application.shellEnvironmentResolutionTimeout" = 30;
    };
}
