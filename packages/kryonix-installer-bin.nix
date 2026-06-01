{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
}:

# Exemplo de uso via override ou input fetchurl
# Este pacote permite usar o binário pré-compilado da release
{
  url,
  sha256,
  version,
}:

stdenv.mkDerivation {
  pname = "kryonix-installer-bin";
  inherit version;

  src = fetchurl {
    inherit url sha256;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/kryonix-installer
    chmod +x $out/bin/kryonix-installer
  '';

  postFixup = ''
    wrapProgram $out/bin/kryonix-installer \
      --set RUST_LOG info
  '';

  meta = with lib; {
    description = "Kryonix installer pre-compiled binary";
    homepage = "https://github.com/RAGton/kryonix";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
