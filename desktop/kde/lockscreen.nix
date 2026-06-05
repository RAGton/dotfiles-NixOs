# =============================================================================
# desktop/kde/lockscreen.nix — Tela de bloqueio Kryonix (Plasma 6)
#
# O que é:
# - Configura o KScreenLocker do Plasma 6 de forma 100% declarativa via
#   programs.plasma.kscreenlocker.* (plasma-manager), com identidade Kryonix:
#   wallpaper próprio, autolock razoável, relógio sempre visível, sem media.
#
# Por quê:
# - Sem este módulo a lockscreen herda o default do Global Theme (Breeze ou
#   genérico do KDE) — colide visualmente com o BonaFides do desktop.
# - Centraliza políticas de segurança (autolock, lock on resume) ao invés de
#   depender de cliques em System Settings.
#
# Como:
# - plasma-manager (rev pinada — AlexNabokikh/plasma-manager) expõe o módulo
#   modules/kscreenlocker.nix com opções dedicadas (autoLock, timeout,
#   lockOnResume, appearance.wallpaper, alwaysShowClock, etc.). As opções
#   geram kscreenlockerrc nas seções corretas (Greeter/Wallpaper/...,
#   Greeter/LnF/General, Daemon).
#
# Notas:
# - Wallpaper de lock difere do desktop (12.png) para reforçar contexto
#   visual "sessão bloqueada". Ajuste o arquivo se quiser unificar.
# - Não definimos lockOnStartup (deixaria a sessão sempre travada após boot
#   antes do autologin/SDDM concluir — não é o fluxo do Inspiron).
# =============================================================================
{ ... }:
{
  programs.plasma.kscreenlocker = {
    # Comportamento -------------------------------------------------------
    autoLock = true;
    timeout = 10; # minutos sem atividade até travar
    lockOnResume = true; # trava ao acordar de suspend/lid close
    passwordRequired = true;
    passwordRequiredDelay = 0; # senha exigida imediatamente

    # Aparência -----------------------------------------------------------
    appearance = {
      # Wallpaper da lockscreen — assets/wallpaper/01.png (distinto do
      # desktop default 12.png para sinalizar visualmente "trancado").
      wallpaper = ../../assets/wallpaper/01.png;
      alwaysShowClock = true; # relógio mesmo sem campo de senha visível
      showMediaControls = false; # nada de revelar app de mídia atual
    };
  };
}
