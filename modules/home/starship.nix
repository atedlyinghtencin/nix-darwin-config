{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status.style = "bold yellow";

      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
