# =============================================================================
# Autor: rag
#
# O que é:
# - Módulo Home Manager para habilitar `cliphist` (histórico da área de transferência).
#
# Por quê:
# - Mantém histórico de clipboard no Wayland para recuperar itens copiados.
#
# Como:
# - Habilita `services.cliphist`.
#
# Riscos:
# - Histórico pode conter dados sensíveis; avalie limpeza/regras conforme seu uso.
# =============================================================================
{ ... }:
{
  # O shell Wayland e o menu declarativo usam este backend de histórico.
  services.cliphist.enable = true;
}
