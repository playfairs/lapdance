{
  description = "Lapdance development environment and Nox-driven build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nox.url = "github:playfairs/nox";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      nox,
    }:
    let
      system = "aarch64-darwin";
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnsupportedSystem = true;
        };
      };
      formatterFor =
        targetSystem:
        let
          targetPkgs = nixpkgs.legacyPackages.${targetSystem};
        in
        import ./nix/formatter.nix {
          pkgs = targetPkgs;
          inherit self treefmt-nix;
        };
      src = ./.;
    in
    {
      packages.${system}.lapdance = import ./nix/buildPackage.nix {
        inherit pkgs src nox;
        lib = pkgs.lib;
        version = "0.1.0";
      };

      defaultPackage.${system} = self.packages.${system}.lapdance;

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.lapdance}/bin/lapdance";
      };

      devShells.${system}.default = import ./nix/devShell.nix {
        inherit pkgs nox;
        lib = pkgs.lib;
      };

      formatter = nixpkgs.lib.genAttrs systems (targetSystem: (formatterFor targetSystem).wrapper);
    };
}
