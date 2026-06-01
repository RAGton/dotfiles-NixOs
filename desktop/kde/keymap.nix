# =============================================================================
# desktop/kde/keymap.nix — Kryonix KDE Keymap v1 (FONTE ÚNICA DE VERDADE)
#
# Lista declarativa de TODOS os atalhos do ambiente KDE, usada pelo
# Kryonix Keybind Helper (desktop/kde/keybind-helper.nix) para gerar a
# cheat-sheet visual. Os atalhos efetivos são injetados em keybinds.nix —
# mantenha os dois em sincronia (este arquivo é o contrato de documentação).
#
# Campos: { keys; desc; group; reserved ? false; }
#   reserved = true  → atalho documentado porém ainda NÃO vinculado (sem comando
#                      real); aparece no helper marcado como "reservado".
# =============================================================================
[
  # ---------------- Launchers & IA ----------------
  {
    group = "Launchers & IA";
    keys = "Meta+A";
    desc = "Albert Launcher";
  }
  {
    group = "Launchers & IA";
    keys = "Meta+Shift+A";
    desc = "Albert: busca de arquivos";
  }
  {
    group = "Launchers & IA";
    keys = "Meta+Ctrl+A";
    desc = "Albert: menu de energia";
  }
  {
    group = "Launchers & IA";
    keys = "Meta+I";
    desc = "Abrir Kora (UI web)";
  }
  {
    group = "Launchers & IA";
    keys = "Meta+Shift+I";
    desc = "Kora: chat rápido";
  }
  {
    group = "Launchers & IA";
    keys = "Meta+Ctrl+I";
    desc = "Kora: painel de agentes";
  }

  # ---------------- Ajuda ----------------
  {
    group = "Ajuda";
    keys = "Meta+/";
    desc = "Kryonix Keybind Helper";
  }
  {
    group = "Ajuda";
    keys = "Meta+F1";
    desc = "Kryonix Keybind Helper (overlay)";
  }
  {
    group = "Ajuda";
    keys = "Meta+Shift+F1";
    desc = "Documentação completa de atalhos";
    reserved = true;
  }

  # ---------------- Workspaces ----------------
  {
    group = "Workspaces";
    keys = "Meta+1..0";
    desc = "Ir para workspace 1..10";
  }
  {
    group = "Workspaces";
    keys = "Meta+Shift+1..0";
    desc = "Mover janela para workspace 1..10";
  }
  {
    group = "Workspaces";
    keys = "Meta+Ctrl+1..0";
    desc = "Mover janela e seguir → workspace 1..10";
  }
  {
    group = "Workspaces";
    keys = "Meta+Roda ↑";
    desc = "Workspace anterior (limitação: ver nota)";
    reserved = true;
  }
  {
    group = "Workspaces";
    keys = "Meta+Roda ↓";
    desc = "Próximo workspace (limitação: ver nota)";
    reserved = true;
  }

  # ---------------- Navegação Krohnkite ----------------
  {
    group = "Krohnkite";
    keys = "Meta+H/J/K/L";
    desc = "Foco: esquerda/baixo/cima/direita";
  }
  {
    group = "Krohnkite";
    keys = "Meta+Shift+H/J/K/L";
    desc = "Mover janela";
  }
  {
    group = "Krohnkite";
    keys = "Meta+Ctrl+H / Meta+Ctrl+L";
    desc = "Largura: diminuir / aumentar";
  }
  {
    group = "Krohnkite";
    keys = "Meta+Ctrl+J / Meta+Ctrl+K";
    desc = "Altura: aumentar / diminuir";
  }
  {
    group = "Krohnkite";
    keys = "Meta+Space";
    desc = "Próximo layout";
  }
  {
    group = "Krohnkite";
    keys = "Meta+D";
    desc = "Layout Spiral (Dwindle)";
  }
  {
    group = "Krohnkite";
    keys = "Meta+B";
    desc = "Layout BinaryTree (BSP)";
  }
  {
    group = "Krohnkite";
    keys = "Meta+M";
    desc = "Layout Monocle";
  }
  {
    group = "Krohnkite";
    keys = "Meta+C";
    desc = "Layout Columns";
  }

  # ---------------- Janelas & Scratchpad ----------------
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+Return";
    desc = "Terminal (kryonix-terminal)";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+Shift+Return";
    desc = "Terminal flutuante";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+Q";
    desc = "Fechar janela";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+F";
    desc = "Tela cheia (fullscreen)";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+T";
    desc = "Toggle floating";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+Tab";
    desc = "Alternar janelas (Walk Through)";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+S";
    desc = "Ir para Scratchpad (workspace 10)";
  }
  {
    group = "Janelas & Scratchpad";
    keys = "Meta+Shift+S";
    desc = "Enviar janela para Scratchpad (ws 10)";
  }

  # ---------------- Sistema & Apps ----------------
  {
    group = "Sistema & Apps";
    keys = "Meta+W";
    desc = "Overview";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+G";
    desc = "Desktop Grid";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+O";
    desc = "Dolphin (gerenciador de arquivos)";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+N";
    desc = "Zen Browser";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+Shift+N";
    desc = "Zen Browser (nova janela)";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+R";
    desc = "VSCode (code-insiders)";
  }
  {
    group = "Sistema & Apps";
    keys = "Print";
    desc = "Screenshot: tela inteira";
  }
  {
    group = "Sistema & Apps";
    keys = "Shift+Print";
    desc = "Screenshot: região";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+Escape";
    desc = "Bloquear sessão";
  }
  {
    group = "Sistema & Apps";
    keys = "Shift+Escape";
    desc = "Logout";
  }
  {
    group = "Sistema & Apps";
    keys = "Meta+Ctrl+Escape";
    desc = "Reiniciar sistema";
  }

  # ---------------- Mídia ----------------
  {
    group = "Mídia";
    keys = "Meta+,";
    desc = "Faixa anterior";
  }
  {
    group = "Mídia";
    keys = "Meta+.";
    desc = "Próxima faixa";
  }
  {
    group = "Mídia";
    keys = "XF86AudioPlay";
    desc = "Play/Pause";
  }

  # ---------------- Reservados (documentados, sem comando real ainda) ------
  {
    group = "Reservados";
    keys = "Meta+Ctrl+R";
    desc = "Rebuild Kryonix";
    reserved = true;
  }
  {
    group = "Reservados";
    keys = "Meta+Alt+Backspace";
    desc = "Diagnóstico Kryonix";
    reserved = true;
  }
  {
    group = "Reservados";
    keys = "Meta+Shift+Backspace";
    desc = "Reiniciar KWin (inseguro no Wayland)";
    reserved = true;
  }
]
