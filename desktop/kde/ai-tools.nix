# =============================================================================
# desktop/kde/ai-tools.nix — Ferramentas de IA nativas e integração Desktop
#
# O que é:
# - Instala ferramentas de IA (Claude, Gemini, Codex, Antigravit) de forma nativa.
# - Cria wrappers blindados e entradas de menu (XDG Desktop Entries).
#
# Por quê:
# - Facilita o acesso a assistentes de IA diretamente pelo launcher do KDE (Albert/Plasma).
# - Mantém o ambiente de IA persistente e integrado ao workflow de desenvolvimento.
# =============================================================================
{ pkgs, ... }:
let
  # Claude Code nativo blindado via npx
  claudeWrapper = pkgs.writeShellScriptBin "claude" ''
    exec ${pkgs.nodejs_22}/bin/npx -y @anthropic-ai/claude-code "$@"
  '';
in
{
  home.packages = [
    pkgs.gemini-cli
    claudeWrapper
    pkgs.antigravity
  ];

  xdg.desktopEntries = {
    claude = {
      name = "Claude Code CLI";
      exec = "kryonix-terminal claude";
      terminal = false;
      categories = [ "Development" "Utility" ];
      icon = "claude";
    };
    gemini = {
      name = "Gemini CLI";
      exec = "kryonix-terminal gemini-cli";
      terminal = false;
      categories = [ "Development" "Utility" ];
      icon = "gemini";
    };
    antigravity = {
      name = "Antigravit AI";
      exec = "kryonix-terminal antigravity";
      terminal = false;
      categories = [ "Development" "Utility" ];
      icon = "antigravit";
    };
  };
}
