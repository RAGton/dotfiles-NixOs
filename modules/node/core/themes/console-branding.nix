{
  config,
  lib,
  pkgs,
  ...
}:

let
  hostLabel =
    if config.networking.hostName == "" then "dynamic (DHCP)" else config.networking.hostName;
  profileLabel = "NODE " + config.node.profile.name;
  departureMono = pkgs.stdenvNoCC.mkDerivation {
    pname = "departure-mono";
    version = "1.500";
    src = ./fonts/departure-mono;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm0644 "$src/DepartureMono-Regular.otf" \
        "$out/share/fonts/opentype/DepartureMono-Regular.otf"
      runHook postInstall
    '';
  };
in
{
  fonts.packages = [ departureMono ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts.monospace = [ "Departure Mono" ];
  };

  console = {
    earlySetup = lib.mkDefault true;
    colors = [
      "0b1320"
      "d96c75"
      "8ec07c"
      "d7ba7d"
      "6ca0d6"
      "b48ead"
      "78bfbf"
      "d8dee9"
      "3b4252"
      "e07a84"
      "9fd889"
      "e4cb8a"
      "8ab8ea"
      "c5a3df"
      "8fd1d1"
      "edf2f7"
    ];
    # Departure Mono e OTF e fica disponivel via fontconfig, mas o VT Linux
    # continua precisando de uma fonte PSF/PSFU compativel.
    font = lib.mkDefault "Lat2-Terminus16";
  };

  services.getty.greetingLine = lib.mkDefault "";
  services.getty.helpLine = lib.mkDefault "";

  environment.etc."issue".text = lib.mkDefault ''
    ${profileLabel}
    Host: ${hostLabel}
    TTY:  \l

    Authorized access only.

  '';

  environment.etc."issue.net".text = lib.mkDefault ''
    ${profileLabel}
    Authorized access only.
  '';
}
