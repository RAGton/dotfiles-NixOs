{
  writeShellApplication,
  callPackage,
  coreutils,
  curl,
  gitMinimal,
  gnugrep,
  gnused,
  jq,
  libvirt,
  nh,
  nix,
  nvd,
  nixos-install-tools,
  python3,
  util-linux,
  uv,
  stdenv,
  lib,
  libffi,
  openssl,
  zlib,
  openrgb,
  bc,
  kryonixHome,
  kryonix-hardware-probe,
  kryonix-disk-planner,
  kryonix-installer,
  kora,
  installShellFiles,
  symlinkJoin,
}:
let
  runtimeLibPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    zlib
    libffi
    openssl
  ];

  kryonixBase = writeShellApplication {
    name = "kryonix";
    runtimeInputs = [
      coreutils
      curl
      gitMinimal
      gnugrep
      gnused
      jq
      libvirt
      nh
      nix
      nvd
      nixos-install-tools
      python3
      util-linux
      uv
      openrgb
      bc
      kryonixHome
      kryonix-hardware-probe
      kryonix-disk-planner
      kryonix-installer
      kora
    ];
    text =
      # writeShellApplication prepends nix-store paths to PATH; we need
      # /run/wrappers/bin/sudo (setuid) to come first so that nh can escalate.
      "PATH=\"/run/wrappers/bin\${PATH:+:\${PATH}}\"; export PATH\n"
      + "set -euo pipefail\ntrap 'stty sane opost onlcr echo icanon isig 2>/dev/null || true' EXIT INT TERM\n"
      + "runtimeLibPath=\"${runtimeLibPath}\"\n"
      + builtins.readFile ./kryonix-cli/core.sh
      + builtins.readFile ./kryonix-cli/registry.sh
      + builtins.readFile ./kryonix-cli/nixos.sh
      + builtins.readFile ./kryonix-cli/git.sh
      + builtins.readFile ./kryonix-cli/brain.sh
      + builtins.readFile ./kryonix-cli/services.sh
      + builtins.readFile ./kryonix-cli/remote.sh
      + builtins.readFile ./kryonix-cli/home.sh
      + builtins.readFile ./kryonix-cli/installer.sh
      + builtins.readFile ./kryonix-cli/kora.sh
      + builtins.readFile ./kryonix-cli/main.sh;
  };

  koraWrapper = writeShellApplication {
    name = "kora";
    text = "exec ${kora}/bin/kora \"$@\"";
  };
in
symlinkJoin {
  name = "kryonix";
  paths = [
    kryonixBase
    koraWrapper
  ];
  nativeBuildInputs = [ installShellFiles ];
  postBuild = ''
    installShellCompletion --cmd kryonix \
      --bash --name kryonix ${./kryonix-cli/completions/kryonix} \
      --zsh ${./kryonix-cli/completions/_kryonix} \
      --fish ${./kryonix-cli/completions/kryonix.fish}
  '';
  meta = {
    description = "Kryonix Unified CLI — System management, AI, and Home Brain interface";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
