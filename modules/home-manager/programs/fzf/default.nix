# =============================================================================
# Autor: rag
#
# O que é:
# - Módulo Home Manager para habilitar e configurar o `fzf`.
#
# Por quê:
# - Padroniza a UX (preview, bindings e layout) entre máquinas.
# - Integra ações comuns: abrir seleção no Neovim e copiar para clipboard.
#
# Como:
# - Ajusta `defaultCommand` e `defaultOptions`.
# - Usa `pbcopy` no macOS e `wl-copy` no Linux/Wayland.
#
# Riscos:
# - `wl-copy` exige um ambiente Wayland com `wl-clipboard` disponível.
# - O preview usa `bat/tree/less`; se não estiverem presentes, pode degradar a experiência.
# =============================================================================
{ pkgs, ... }:
let
  copyCmd = if pkgs.stdenv.isDarwin then "pbcopy" else "wl-copy";
in
{
  # Instala e configura o fzf via Home Manager.
  programs.fzf = {
    enable = true;

    defaultCommand = "find .";
    defaultOptions = [
      "--bind '?:toggle-preview'"
      "--bind 'ctrl-a:select-all'"
      "--bind 'ctrl-e:execute(echo {+} | xargs -o nvim)'"
      "--bind 'ctrl-y:execute-silent(echo {+} | ${copyCmd})'"
      "--color='hl:148,hl+:154,pointer:032,marker:010,bg+:237,gutter:008'"
      "--height=40%"
      "--info=inline"
      "--layout=reverse"
      "--multi"
      "--preview '([[ -f {}  ]] && (bat --color=always --style=numbers,changes {} || cat {})) || ([[ -d {}  ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'"
      "--preview-window=:hidden"
      "--prompt='~ ' --pointer='▶' --marker='✓'"
    ];

    # Atuin owns Ctrl-R (history manager com SQLite sync).
    # Desabilitar o widget de history do fzf remove a colisão de atalho.
    # Binário continua disponível para uso via pipe (e.g. `find | fzf`).
    historyWidget.command = "";
  };
}
