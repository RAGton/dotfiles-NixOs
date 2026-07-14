/*
  Entry point canônico da CLI `knyc`.
  A implementação do pacote fica em `knyc/package.nix`.
*/
{
  pkgs,
  nodeServerIp,
  nodeHttpPort,
  nodeDefaultClientTarget ? "desktop-generic",
}:

import ./package.nix {
  inherit
    pkgs
    nodeServerIp
    nodeHttpPort
    nodeDefaultClientTarget
    ;
}
