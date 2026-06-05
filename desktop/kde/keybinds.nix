{ lib, pkgs, ... }:
let
  range = lib.range 1 10;
  digit = i: if i == 10 then "0" else toString i;

  # Comandos com operadores de shell / aspas NÃO podem ir direto no Exec de um
  # .desktop (caracteres reservados: '&', aspas, etc.). Por isso usamos wrappers
  # writeShellScript e referenciamos o caminho do script no hotkey.
  moveFollow = pkgs.writeShellScript "kryonix-move-follow" ''
    d="$1"
    qdbus6 org.kde.kglobalaccel /component/kwin invokeShortcut "Window to Desktop $d"
    qdbus6 org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Desktop $d"
  '';

  # Terminal default Kryonix em KDE = Warp. O wrapper kryonix-terminal vem
  # antes (porque já injeta env/zellij quando disponível e cai em Warp por
  # baixo); konsole é o último fallback de emergência para nunca deixar o
  # usuário sem terminal por atalho. Não chamar konsole primeiro — política
  # 2026-06: Warp é o terminal padrão SEMPRE.
  kdeTerminal = pkgs.writeShellScript "kryonix-kde-terminal" ''
    set -euo pipefail

    if command -v kryonix-terminal >/dev/null 2>&1; then
      exec kryonix-terminal "$@"
    fi

    if [ -x "${pkgs.warp-terminal}/bin/warp-terminal" ]; then
      exec "${pkgs.warp-terminal}/bin/warp-terminal" "$@"
    fi

    if [ -x "${pkgs.kdePackages.konsole}/bin/konsole" ]; then
      exec "${pkgs.kdePackages.konsole}/bin/konsole" --workdir "$HOME" "$@"
    fi

    echo "kryonix-kde-terminal: nenhum terminal encontrado" >&2
    exit 127
  '';

  # Meta+1..0 → trocar de desktop; Meta+Shift+1..0 → mover janela p/ desktop.
  switchTo = lib.listToAttrs (
    map (i: {
      name = "Switch to Desktop ${toString i}";
      # Desktop 10 (Scratchpad) ganha também Meta+S.
      value =
        if i == 10 then
          [
            "Meta+0"
            "Meta+S"
          ]
        else
          "Meta+${digit i}";
    }) range
  );

  windowTo = lib.listToAttrs (
    map (i: {
      name = "Window to Desktop ${toString i}";
      value =
        if i == 10 then
          [
            "Meta+Shift+0"
            "Meta+Shift+S"
          ]
        else
          "Meta+Shift+${digit i}";
    }) range
  );

  # Limpa os atalhos default do task manager (Meta+1..0 ativam entradas por padrão).
  clearTaskEntries = lib.listToAttrs (
    map (i: {
      name = "Activate Task Manager Entry ${toString i}";
      value = [ ];
    }) range
  );

  # Meta+Ctrl+1..0 → mover janela para o desktop N e segui-la (via wrapper).
  moveFollowCommands = lib.listToAttrs (
    map (i: {
      name = "kryonix-move-follow-${toString i}";
      value = {
        name = "Mover janela e seguir → desktop ${toString i}";
        key = "Meta+Ctrl+${digit i}";
        command = "${moveFollow} ${toString i}";
      };
    }) range
  );
in
{
  programs.plasma = {
    # =====================================================================
    # Atalhos de componentes (kglobalshortcutsrc)
    # =====================================================================
    shortcuts = {
      # ---- KWin: janelas, navegação de desktops, Krohnkite ----
      kwin =
        switchTo
        // windowTo
        // {
          # Janelas
          "Window Close" = "Meta+Q";
          "Window Fullscreen" = "Meta+F";
          "Walk Through Windows" = [
            "Meta+Tab"
            "Alt+Tab"
          ];
          "Overview" = "Meta+W";
          "Grid View" = "Meta+G";

          # --- Krohnkite: foco (defaults batem, fixados explicitamente) ---
          "KrohnkiteFocusLeft" = "Meta+H";
          "KrohnkiteFocusDown" = "Meta+J";
          "KrohnkiteFocusUp" = "Meta+K";
          "KrohnkiteFocusRight" = "Meta+L";
          # --- Krohnkite: mover janela ---
          "KrohnkiteShiftLeft" = "Meta+Shift+H";
          "KrohnkiteShiftDown" = "Meta+Shift+J";
          "KrohnkiteShiftUp" = "Meta+Shift+K";
          "KrohnkiteShiftRight" = "Meta+Shift+L";
          # --- Krohnkite: redimensionar ---
          "KrohnkiteShrinkWidth" = "Meta+Ctrl+H";
          "KrohnkitegrowWidth" = "Meta+Ctrl+L"; # (nome com 'g' minúsculo no QML)
          "KrohnkiteGrowHeight" = "Meta+Ctrl+J";
          "KrohnkiteShrinkHeight" = "Meta+Ctrl+K";
          # --- Krohnkite: layouts ---
          "KrohnkiteNextLayout" = "Meta+Space";
          "KrohnkiteSpiralLayout" = "Meta+D";
          "KrohnkiteBTreeLayout" = "Meta+B";
          "KrohnkiteMonocleLayout" = "Meta+M";
          "KrohnkiteColumnsLayout" = "Meta+C";
          "KrohnkiteToggleFloat" = "Meta+Shift+F";

          # --- Krohnkite: defaults conflitantes → limpos (none) ---
          "KrohnkiteFocusNext" = [ ]; # default Meta+. (= Próxima faixa)
          "KrohnkiteFocusPrev" = [ ]; # default Meta+, (= Faixa anterior)
          "KrohnkiteIncrease" = [ ]; # default Meta+I (= Kora)
          "KrohnkiteDecrease" = [ ]; # default Meta+D (= Spiral)
          "KrohnkiteRotate" = [ ]; # default Meta+R (= VSCode)
          "KrohnkiteRotatePart" = [ ]; # default Meta+Shift+R
          "KrohnkiteSetMaster" = [ ]; # default Meta+Return (= Terminal)
          "KrohnkiteTileLayout" = [ ]; # default Meta+T (= Toggle Float)
          "KrohnkiteFloatAll" = [ ]; # default Meta+Shift+F
          "KrohnkitePreviousLayout" = [ ]; # default Meta+|

          # --- Efeitos de visão geral/exposição que ATRAPALHAM o tiling ----
          # Limpos por não estarem no keymap Kryonix (eram defaults residuais do
          # Plasma). NÃO mexer em "Overview" (Meta+W) nem "Grid View" (Meta+G):
          # são bindings intencionais do keymap.
          "Expose" = "none"; # default Meta+F9 / Ctrl+F9
          "ExposeAll" = "none"; # default Meta+F10 / Ctrl+F10
          "ExposeClass" = "none"; # default Meta+F7 / Ctrl+F7
          "ExposeClassCurrentDesktop" = "none";
          "Cycle Overview" = "none";
          "Cycle Overview Opposite" = "none";
          "Suspend Compositor" = "none"; # evita desligar o compositor por engano
        };

      # ---- ksmserver: sessão ----
      # "Lock Session" realocado p/ Meta+Escape (libera o default Meta+L p/ Krohnkite).
      ksmserver = {
        "Lock Session" = "Meta+Escape";
        "Log Out" = "Shift+Escape";
      };

      # ---- plasmashell: limpa Meta+1..0 (task manager) e conflitos ----
      plasmashell = clearTaskEntries // {
        "next activity" = "none";
        "manage activities" = "none";
      };
    };

    # =====================================================================
    # Comandos disparados por atalho (hotkeys.commands)
    # =====================================================================
    hotkeys.commands = moveFollowCommands // {
      # --- Wofi (launcher de aplicativos, estilo Hyprland/Waybar) ---
      # Meta+A: Abre o wofi em modo drun (aplicativos). As antigas buscas de
      #         arquivos/energia eram plugins específicos do Albert (sem equivalente
      #         direto no Wofi); foram removidas. Se quiser, dá pra recriar um
      #         power-menu em wofi-dmenu.
      "wofi-drun" = {
        name = "Wofi Application Launcher";
        key = "Meta+A";
        command = "${pkgs.wofi}/bin/wofi --show drun --allow-images --no-colors";
      };

      # Atalhos da Kora removidos (assistente legada → Aura).
      # Meta+I / Meta+Shift+I / Meta+Ctrl+I ficaram livres para a futura UI da Aura.

      # --- Ajuda: Kryonix Keybind Helper (Meta+/ e Meta+F1) ---
      "kryonix-keybind-helper" = {
        name = "Kryonix Keybind Helper";
        key = "Meta+/";
        keys = [ "Meta+F1" ];
        command = "kryonix-keybind-helper";
      };

      # --- Janelas / Apps ---
      "terminal" = {
        name = "Terminal";
        key = "Meta+T";
        keys = [ "Meta+Return" ];
        command = "${kdeTerminal}";
      };
      # Terminal flutuante: lança o terminal; o comportamento "flutuante" é
      # tratado por regra do KWin (ver nota). Funcionalmente abre o terminal.
      "terminal-float" = {
        name = "Terminal flutuante";
        key = "Meta+Shift+T";
        keys = [ "Meta+Shift+Return" ];
        command = "${kdeTerminal}";
      };
      "dolphin" = {
        name = "Dolphin";
        key = "Meta+O";
        command = "dolphin";
      };
      "zen" = {
        name = "Zen Browser";
        key = "Meta+N";
        command = "flatpak run app.zen_browser.zen";
      };
      "zen-new" = {
        name = "Zen Browser (nova janela)";
        key = "Meta+Shift+N";
        command = "flatpak run app.zen_browser.zen --new-window";
      };
      "vscode" = {
        name = "VSCode";
        key = "Meta+R";
        command = "code-insiders";
      };

      # --- Sessão: reiniciar com diálogo de confirmação ---
      "reboot" = {
        name = "Reiniciar sistema";
        key = "Meta+Ctrl+Escape";
        command = "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot";
      };

      # --- Mídia (playerctl) ---
      "media-prev" = {
        name = "Faixa anterior";
        key = "Meta+,";
        command = "playerctl previous";
      };
      "media-next" = {
        name = "Próxima faixa";
        key = "Meta+.";
        command = "playerctl next";
      };
      "media-playpause" = {
        name = "Play/Pause";
        key = "XF86AudioPlay";
        command = "playerctl play-pause";
      };
    };

    # =====================================================================
    # Capturas de tela (Spectacle)
    # =====================================================================
    spectacle.shortcuts = {
      captureEntireDesktop = "Print";
      captureRectangularRegion = "Shift+Print";
    };
  };

  # NOTA (limitação documentada — Fase 7): Meta+Roda do mouse para trocar de
  # desktop não é expressável declarativamente como atalho global no
  # plasma-manager desta revisão (kglobalshortcutsrc não vincula modificador+roda).
  # Fica como atalho reservado no keymap; pode ser configurado posteriormente via
  # "rolagem sobre o fundo da área de trabalho" no Plasma, se desejado.
}
