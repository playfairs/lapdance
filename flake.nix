{
  description = "Lapdance development environment and Nox-driven build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnsupportedSystem = true;
        };
      };
      src = ./.;
    in {
      packages.${system}.lapdance = import ./nix/buildPackage.nix {
        inherit pkgs src;
        lib = pkgs.lib;
        version = "0.1.0";
      };

      defaultPackage.${system} = self.packages.${system}.lapdance;

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.lapdance}/bin/lapdance";
      };

      devShells.${system}.default = import ./nix/devShell.nix {
        inherit pkgs;
        lib = pkgs.lib;
      };
    };
}
