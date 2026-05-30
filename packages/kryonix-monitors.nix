# =============================================================================
# Pacote: kryonix-monitors
# Autor: Gabriel Rocha (rag)
#
# O que é:
# - Script de controle multi-monitor para Hyprland.
# - Empacotado via writeShellApplication para ter PATH controlado.
#
# Dependências de runtime:
# - hyprland  → hyprctl
# - jq        → parse de JSON do hyprctl
# - libnotify → notify-send
# - rofi      → menu interativo
# =============================================================================
{
  writeShellApplication,
  hyprland,
  jq,
  libnotify,
  rofi,
  ...
}:

writeShellApplication {
  name = "kryonix-monitors";

  runtimeInputs = [
    hyprland
    jq
    libnotify
    rofi
  ];

  # Script em arquivo externo — não inline — para melhor manutenibilidade.
  text = builtins.readFile ../scripts/kryonix-monitors.sh;

  # Verificação mínima de sintaxe via shellcheck (automático no writeShellApplication)
  meta = {
    description = "Controle de multi-monitor para Hyprland/Kryonix";
    longDescription = ''
      Script de controle de monitores para Hyprland com suporte a:
      - Modos: estender, duplicar/espelhar, só interno, só externo, ciclo
      - Mudança de resolução, escala e posição em runtime
      - Menu interativo via rofi
      - Persistência de estado entre sessões
      - Restauração automática ao iniciar Hyprland
    '';
    mainProgram = "kryonix-monitors";
  };
}
