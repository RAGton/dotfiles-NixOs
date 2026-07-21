/*
  Entry point canônico do cliente NODE.
  Este arquivo expõe o caminho público estável `client/client.nix`
  e delega a composição principal para `client/default.nix`.
*/
{ ... }:

{
  imports = [
    ./default.nix
  ];
}
