{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
  openssl,
  gcc-unwrapped,
}:

stdenv.mkDerivation rec {
  pname = "codex-bin";
  version = "latest";

  # ATENÇÃO: Substitua a URL e o SHA256 pelos valores corretos do release binário
  # do Codex CLI para Linux x86_64. O valor abaixo é um placeholder.
  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/v${version}/codex-linux-x86_64";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    zlib
    openssl
    stdenv.cc.cc.lib
    gcc-unwrapped
  ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/codex
    chmod +x $out/bin/codex
  '';

  meta = {
    description = "OpenAI Codex CLI (Binary version to skip compilation)";
    platforms = [ "x86_64-linux" ];
  };
}
