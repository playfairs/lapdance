{
  pkgs,
  lib,
  src,
  nox,
  version ? "0.1.0",
}:

let
  dToolchain = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.dmd
    pkgs.dub
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "lapdance";
  inherit version src;

  nativeBuildInputs = [ nox.packages.${pkgs.system}.default ] ++ dToolchain;

  buildPhase = ''
    if command -v dmd >/dev/null 2>&1; then
      nox build
    else
      echo "error: D compiler not available; install dmd before building Lapdance." >&2
      exit 1
    fi
  '';

  installPhase = ''
    mkdir -p $out/bin
    install -m755 build/lapdance $out/bin/lapdance
  '';

  meta = {
    description = "A D code formatter";
    homepage = "https://github.com/playfairs/lapdance";
    license = lib.licenses.unlicense;
    platforms = lib.platforms.unix;
  };
}