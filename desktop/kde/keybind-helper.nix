# =============================================================================
# desktop/kde/keybind-helper.nix — Kryonix Keybind Helper
#
# O que é:
# - Helper visual funcional que lê a fonte única de verdade (keymap.nix) e
#   renderiza uma cheat-sheet com TODOS os atalhos (inclusive os reservados),
#   exibida numa janela via kdialog.
#
# Por quê:
# - Atende ao requisito de "ajuda visual de atalhos" sem deixar atalhos
#   reservados sem documentação. Vinculado a Meta+/ e Meta+F1 (em keybinds.nix).
#
# Como:
# - Gera um arquivo de texto no /nix/store a partir de keymap.nix e o abre com
#   `kdialog --textbox`. Como a fonte é compartilhada com keybinds.nix, a
#   cheat-sheet reflete os atalhos efetivamente configurados.
# =============================================================================
{ lib, pkgs, ... }:
let
  keymap = import ./keymap.nix;

  groups = lib.unique (map (e: e.group) keymap);

  renderEntry =
    e: "  ${e.keys}  →  ${e.desc}" + (lib.optionalString (e.reserved or false) "   [reservado]");

  renderGroup =
    g:
    let
      entries = lib.filter (e: e.group == g) keymap;
    in
    "▸ ${g}\n" + lib.concatStringsSep "\n" (map renderEntry entries);

  cheatText = ''
    Kryonix KDE Keymap v1 — atalhos configurados
    ============================================

  '' + lib.concatStringsSep "\n\n" (map renderGroup groups) + "\n";

  cheatFile = pkgs.writeText "kryonix-keybinds.txt" cheatText;

  helper = pkgs.writeShellApplication {
    name = "kryonix-keybind-helper";
    runtimeInputs = [ pkgs.kdePackages.kdialog ];
    text = ''
      exec kdialog --title "Kryonix Keybind Helper" --textbox ${cheatFile} 760 640
    '';
  };
in
{
  home.packages = [ helper ];
}
