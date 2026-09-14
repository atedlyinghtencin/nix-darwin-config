{
  description = "Declarative macOS configuration (nix-darwin + home-manager + Homebrew)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs and pins Homebrew itself declaratively.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }:
    let
      # ---------------------------------------------------------------
      # EDIT THESE. `whoami` and `scutil --get LocalHostName` on the Mac.
      # ---------------------------------------------------------------
      vars = {
        username = "redxiii";
        hostname = "redxiii";
        computerName = "redxiii"; # `scutil --get ComputerName`
        fullName = "atedlyinghtencin";
        email = "15335331+atedlyinghtencin@users.noreply.github.com";
        system = "aarch64-darwin"; # Apple Silicon
        # Public half of the SSH key 1Password signs commits with, e.g.
        # "ssh-ed25519 AAAA... comment" (1Password: key → Public key → Copy).
        # Empty = don't sign commits.
        sshSigningKey = "";
      };
    in
    {
      darwinConfigurations.${vars.hostname} = nix-darwin.lib.darwinSystem {
        system = vars.system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/macbook

          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true; # Intel-only casks on Apple Silicon
              user = vars.username;
              autoMigrate = true; # adopt an existing /opt/homebrew install
            };
          }

          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # Existing dotfiles (e.g. ~/.zprofile from a pre-nix setup) are
              # moved aside as *.before-nix-darwin instead of aborting activation.
              backupFileExtension = "before-nix-darwin";
              extraSpecialArgs = { inherit inputs vars; };
              users.${vars.username} = import ./modules/home;
            };
          }
        ];
      };

      # Convenience: `nix fmt`
      formatter.${vars.system} = nixpkgs.legacyPackages.${vars.system}.nixfmt;
    };
}
