{ pkgs, lib }:

let
  dToolchain = lib.optionals (pkgs.stdenv.hostPlatform.isLinux) [ pkgs.dmd pkgs.dub ];
in
pkgs.mkShell {
  packages = [ pkgs.nox pkgs.git ] ++ dToolchain;

  shellHook = ''
    if ! command -v dmd >/dev/null 2>&1; then
      echo "warning: D compiler not available in this shell; install dmd from the official D installer or use a Linux host." >&2
    fi
  '';
}
