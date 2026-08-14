# =============================================================================
# desktop/kde/ai-tools.nix — Ferramentas de IA nativas e integração Desktop
#
# O que é:
# - Instala ferramentas de IA (Claude, Gemini, Antigravit) de forma nativa.
# - Cria wrappers blindados e entradas de menu (XDG Desktop Entries).
#
# Por quê:
# - Facilita o acesso a assistentes de IA diretamente pelo launcher do KDE (Albert/Plasma).
# - Mantém o ambiente de IA persistente e integrado ao workflow de desenvolvimento.
# =============================================================================
{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Verifica se o Claude já está sendo instalado pelo módulo ai-workstation
  # para evitar conflito de binários ("two given paths contain a conflicting subpath").
  aiWorkstationEnabled = config.kryonix.programs.aiWorkstation.enable or false;

  # Fallback via npx caso o nixpkgs pinado não exponha pkgs.claude-code.
  claudeWrapper = pkgs.writeShellScriptBin "claude" ''
    exec ${pkgs.nodejs_22}/bin/npx -y @anthropic-ai/claude-code "$@"
  '';
  claudePackage = pkgs.claude-code or claudeWrapper;

  minimaxWrapper = pkgs.writeShellScriptBin "minimax" ''
    exec ${pkgs.nodejs_22}/bin/npx -y mmx-cli "$@"
  '';
  minimaxPackage = pkgs.minimax-cli or minimaxWrapper;
  
  agyWrapper = pkgs.writeShellScriptBin "agy" ''
    export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"
    AGY_BIN="$HOME/.local/bin/agy"
    if [ ! -f "$AGY_BIN" ]; then
        echo "Antigravity CLI não encontrado. Instalando..."
        curl -fsSL https://antigravity.google/cli/install.sh | bash
    fi
    exec "$AGY_BIN" "$@"
  '';
  
  # O caminho absoluto para o tema WhiteSur-dark garante que os ícones funcionem 
  # mesmo que o icon-cache do sistema não seja reconstruído a tempo.
  whiteSurPath = "${pkgs.whitesur-icon-theme}/share/icons/WhiteSur-dark";
in
{
  home.packages = [ minimaxPackage agyWrapper ] ++ lib.optional (!aiWorkstationEnabled) claudePackage;

  xdg.desktopEntries = {
    claude = {
      name = "Claude Code CLI";
      exec = "kryonix-terminal claude";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
      icon = "${whiteSurPath}/apps/scalable/claude.svg";
    };
    minimax = {
      name = "MiniMax CLI";
      exec = "kryonix-terminal minimax";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
      # MiniMax não tem ícone nativo no WhiteSur, usando fallback genérico de IA
      icon = "utilities-terminal";
    };
    antigravity-cli = {
      name = "Antigravity CLI";
      exec = "kryonix-terminal agy";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
      icon = "utilities-terminal";
    };
    # NOTE: NÃO criar um desktopEntry "antigravity" aqui. O Antigravity é uma
    # IDE GRÁFICA (não um CLI como claude/gemini), e o pacote antigravity-nix já
    # fornece um antigravity.desktop válido (Exec=antigravity %U, Icon=antigravity,
    # Name=Google Antigravity). O override anterior (Exec=kryonix-terminal
    # antigravity, Icon/Name com typo, Categories sem ';' final) era malformado:
    # mascarava o .desktop nativo e o kbuildsycoca o descartava → o app sumia do
    # menu do KDE. Deixar o entry nativo do pacote prevalecer.
  };
}
