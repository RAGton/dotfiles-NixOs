# Display Manager + Hyprland + UWSM — Configuração Canônica

## Stack suportada no Kryonix

```
SDDM (DM) → UWSM (session manager) → Hyprland (compositor)
```

SDDM é o DM recomendado para Hyprland no NixOS. GDM funciona mas tem
dependências GNOME pesadas. greetd funciona mas exige configuração PAM manual.

---

## Configuração mínima correta (SDDM + Hyprland + UWSM)

```nix
# desktop/hyprland/system.nix
{ config, lib, pkgs, ... }:
{
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # NÃO definir wayland.compositor sem plasma6 instalado
    # "kwin" é o compositor do KDE — sem plasma6, o SDDM não sobe
  };

  services.displayManager.defaultSession = "hyprland-uwsm";

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # XDG portals necessários para screensharing, file picker
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
```

### O que cada opção faz

| Opção | Por que é necessária |
|-------|----------------------|
| `services.xserver.enable` | SDDM precisa mesmo em Wayland no NixOS atual |
| `sddm.wayland.enable` | Faz o SDDM rodar em Wayland (sem isso, roda em X11) |
| `defaultSession = "hyprland-uwsm"` | Seleciona a sessão padrão no greeter |
| `withUWSM = true` | Instala `hyprland-uwsm.desktop` e o UWSM como wrapper |
| `portalPackage` | Portal Wayland específico do Hyprland |

---

## Por que `withUWSM = true` exige cuidado

Com `withUWSM = true`, o Hyprland **não é lançado diretamente** — é lançado via UWSM.
O UWSM requer que a sessão logind já tenha:

```
XDG_SESSION_TYPE=wayland
XDG_SEAT=seat0
class=user (não "manager")
```

O SDDM com `wayland.enable = true` cria essa sessão corretamente.
O GDM também criava, mas a opção `gdm.wayland` foi removida no nixpkgs-unstable atual.
O greetd **não cria automaticamente** — precisa de PAM manual (ver abaixo).

---

## Configuração com GDM (legado, evitar em unstable)

```nix
# Só use se sddm não funcionar por alguma razão específica
services.displayManager.gdm = {
  enable = true;
  # gdm.wayland foi REMOVIDA no nixpkgs-unstable com GNOME 50
  # Não use essa opção — vai dar erro de avaliação
};
services.displayManager.defaultSession = "hyprland-uwsm";
```

**Atenção:** GDM em nixpkgs-unstable após GNOME 50 não tem mais a opção
`services.displayManager.gdm.wayland`. Usar GDM com Hyprland nessa versão
é instável. Prefira SDDM.

---

## Configuração com greetd (avançado, requer PAM manual)

Se usar greetd, a configuração PAM é **obrigatória**:

```nix
services.greetd = {
  enable = true;
  settings.default_session = {
    command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
    user = "greeter";
  };
};

# PAM obrigatório — sem isso, logind cria sessão "manager" sem seat
# e o UWSM não consegue iniciar o Hyprland
security.pam.services.greetd = {
  text = lib.mkForce ''
    auth     required pam_unix.so nullok try_first_pass
    account  required pam_unix.so
    password required pam_unix.so nullok yescrypt
    session  required pam_unix.so
    session  required pam_env.so conffile=/etc/pam/environment
    session  optional pam_keyinit.so revoke
    session  required pam_limits.so
    session  required pam_systemd.so class=user type=wayland
    session  optional pam_permit.so
  '';
};
```

---

## Validação da sessão após login

```bash
# Deve mostrar Type: wayland, Seat: seat0, Class: user
loginctl session-status

# Deve ser "wayland"
echo $XDG_SESSION_TYPE

# Processo Hyprland deve estar rodando
pgrep -a Hyprland
```

---

## Conflitos comuns e soluções

### "black screen após login"

Causa mais comum: SDDM com `wayland.compositor = "kwin"` sem plasma6 instalado.

```bash
# Verificar se kwin está disponível
which kwin_wayland 2>/dev/null || echo "kwin não instalado"

# Solução: remover wayland.compositor
```

### "hyprland-uwsm.desktop não encontrado"

```bash
# Verificar se o arquivo .desktop foi gerado
ls /run/current-system/sw/share/wayland-sessions/

# Se não aparecer "hyprland-uwsm.desktop":
nix eval .#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM
# Deve ser true
```

### "defaultSession ignorado, entra em sessão errada"

```bash
# Verificar o valor real
nix eval .#nixosConfigurations.inspiron.config.services.displayManager.defaultSession
# Deve ser "hyprland-uwsm" (com o sufixo -uwsm)
```
