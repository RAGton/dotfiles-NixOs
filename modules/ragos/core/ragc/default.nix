/*
  Entry point canônico da CLI `ragc`.
  A implementação do pacote fica em `ragc/package.nix`.
*/
{
  pkgs,
  ragosServerIp,
  ragosHttpPort,
  ragosDefaultClientTarget ? "desktop-generic",
}:

import ./package.nix {
  inherit
    pkgs
    ragosServerIp
    ragosHttpPort
    ragosDefaultClientTarget
    ;
}
