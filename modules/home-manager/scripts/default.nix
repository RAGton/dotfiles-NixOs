# Home Manager: Scripts (binários do usuário)
# Autor: rag
#
# O que é
# - Publica scripts versionados do repo em `~/.local/bin`.
#
# Por quê
# - Scripts são parte do ambiente (day-2 ops, atalhos, automações) e devem ser reprodutíveis.
#
# Como
# - `home.file.".local/bin"` com `recursive = true` copia o diretório `./bin`.
# - Adiciona `~/.local/bin` ao PATH da sessão para que os wrappers locais
#   ganhem precedência sobre binários globais quando necessário.
#
# Riscos
# - Scripts precisam ter dependências disponíveis (via Nix) e não devem assumir paths fixos.
{
  pkgs,
  lib,
  ...
}:
{
  # Publica scripts a partir do store do Home Manager.
  home.file = {
    ".local/bin" = {
      recursive = true;
      source = ./bin;
    };
  };

  # Configuração condicional para sistemas Darwin.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Runtime dos entrypoints publicados em ~/.local/bin.
  # Os scripts continuam versionados como arquivos reais, mas suas dependências
  # vêm do perfil declarativo do Home Manager.
  home.packages = lib.optionals pkgs.stdenv.isLinux (
    with pkgs;
    [
      bluez
      blueman
      cliphist
      coreutils
      findutils
      fuzzel
      fzf
      gawk
      gnugrep
      gnused
      gtk3
      hyprland
      jq
      libnotify
      libqalculate
      networkmanagerapplet
      pamixer
      playerctl
      procps
      slurp
      systemd
      uwsm
      wf-recorder
      wl-clipboard
    ]
  );
}
