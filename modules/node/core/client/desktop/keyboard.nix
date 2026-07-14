{ lib, ... }:

{
  services.xserver.xkb.layout = lib.mkDefault "br";
  services.xserver.xkb.model = lib.mkDefault "abnt2";
}
