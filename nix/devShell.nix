{ pkgs, lib }:

let
  dToolchain = [ pkgs.ldc ];
in
pkgs.mkShell {
  packages = [ pkgs.nox pkgs.git ] ++ dToolchain;
}
