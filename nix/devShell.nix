{ pkgs, lib, nox }:

let
  dToolchain = [ pkgs.ldc ];
in
pkgs.mkShell {
  packages = [
    nox.packages.${pkgs.system}.default
    pkgs.git
  ]
  ++ dToolchain;
}
