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
# - PreviewImage: plasma-manager NÃO declara essa chave (só Image). Sem
#   override fica o leftover do último clique manual em System Settings (no
#   nosso caso, um path em ~/Downloads), o que dá mismatch entre miniatura
#   exibida no painel de Lock & Login e o wallpaper real. Forçamos via
#   configFile para casar com o Image.
# =============================================================================
{ ... }:
let
  lockWallpaper = ../../assets/wallpaper/landscape.png;
in
{
  programs.plasma.kscreenlocker = {
    # Comportamento -------------------------------------------------------
    autoLock = true;
    timeout = 15; # minutos sem atividade até travar
    lockOnResume = true; # trava ao acordar de suspend/lid close
    passwordRequired = true;
    passwordRequiredDelay = 0; # senha exigida imediatamente

    # Aparência -----------------------------------------------------------
    appearance = {
      # Wallpaper da lockscreen
      wallpaper = lockWallpaper;
      alwaysShowClock = false; # relógio mesmo sem campo de senha visível
      showMediaControls = true; # revelar app de mídia atual
    };
  };

  # Casa o PreviewImage com o Image para evitar leftover de path antigo
  # (ex.: ~/Downloads). plasma-manager faz mkMerge no kscreenlockerrc, então
  # esta seção combina com Image gerado pelo module de plasma-manager.
  programs.plasma.configFile.kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General".PreviewImage =
    builtins.toString lockWallpaper;
}
