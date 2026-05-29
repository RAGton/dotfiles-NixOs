# Prompt: ISO Installer — Kiosk Cage + Chromium

> Corrigir o ambiente gráfico do instalador na ISO.
> O Cage não está subindo porque conflita com o getty/TTY1.
> Fix: substituir o shell do autologin pelo Cage em vez de serviço separado.

---

## FASE 1 — Diagnóstico

```bash
# Ver o web-kiosk.nix atual
cat /etc/kryonix/modules/nixos/installer/web-kiosk.nix

# Ver o que o host iso importa
cat /etc/kryonix/hosts/iso/default.nix | head -60

# Ver se existe conflito com getty
grep -rn 'getty\|autologin\|cage\|installer' \
  /etc/kryonix/modules/nixos/installer/ \
  /etc/kryonix/hosts/iso/ --include='*.nix' | grep -v '#'

# Build atual da ISO (sem rodar)
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  --dry-run 2>&1 | tail -10
```

---

## FASE 2 — Corrigir web-kiosk.nix

Substituir a abordagem de serviço systemd separado pelo autologin com shell:

```nix
# modules/nixos/installer/web-kiosk.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.installer.kiosk;
in
{
  options.kryonix.installer.kiosk = {
    enable  = lib.mkEnableOption "Kiosk web do instalador (Cage + Chromium)";
    port    = lib.mkOption { type = lib.types.port; default = 8080; };
    url     = lib.mkOption {
      type    = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
    };
  };

  config = lib.mkIf cfg.enable {
    # Usuário do kiosk com permissões de vídeo/input
    users.users.installer = {
      isNormalUser = true;
      extraGroups  = [ "video" "input" "drm" ];
      # Shell substitui o bash pelo Cage — sem conflito com TTY
      shell = pkgs.writeShellScriptBin "start-kiosk" ''
        # Esperar o backend subir (máx 30s)
        for i in $(seq 1 30); do
          if curl -sf http://localhost:${toString cfg.port}/health >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        # Iniciar kiosk
        exec ${pkgs.cage}/bin/cage -- \
          ${pkgs.chromium}/bin/chromium \
            --kiosk \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu-sandbox \
            --no-first-run \
            --disable-translate \
            --disable-extensions \
            --disable-background-networking \
            --disable-sync \
            "${cfg.url}"
      '';
    };

    # Autologin direto no TTY1 — não briga com getty
    services.getty.autologinUser = lib.mkForce "installer";

    # Backend do instalador como serviço
    systemd.services.kryonix-installer-backend = {
      description   = "Kryonix Installer Backend";
      wantedBy      = [ "multi-user.target" ];
      before        = [ "getty@tty1.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.kryonix-installer}/bin/kryonix-installer --port ${toString cfg.port}";
        Restart   = "on-failure";
        User      = "root";  # precisa para probe de hardware
      };
    };

    # Cage e Chromium disponíveis no sistema
    environment.systemPackages = with pkgs; [ cage chromium ];

    # Wayland necessário para Cage
    hardware.opengl.enable = lib.mkDefault true;
  };
}
```

---

## FASE 3 — Integrar no host iso

```nix
# hosts/iso/default.nix — verificar se está importando e habilitando
{ config, pkgs, lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/nixos/installer/web-kiosk.nix
    ../../modules/nixos/installer/backend.nix  # se existir
    ../../modules/nixos/branding/kryonix/default.nix
  ];

  kryonix.installer.kiosk = {
    enable = true;
    port   = 8080;
  };

  kryonix.branding.enable = true;

  # Plymouth desabilitado na ISO — não faz sentido
  boot.plymouth.enable = lib.mkForce false;

  networking.hostName = "kryonix-installer";
}
```

---

## FASE 4 — Build e teste em VM

```bash
# Build da ISO
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  -o /tmp/result-iso -L 2>&1 | tail -20

# Confirmar que gerou
ls -lh /tmp/result-iso/iso/*.iso

# Testar em VM (qemu direto, sem precisar do virt-manager)
qemu-system-x86_64 \
  -m 2048 \
  -cpu host \
  -enable-kvm \
  -vga virtio \
  -display gtk \
  -cdrom /tmp/result-iso/iso/*.iso \
  -boot d \
  2>/dev/null &

# Ou via virt-manager se preferir GUI
```

### Checklist pós-VM

```
[ ] ISO inicia sem erro de boot
[ ] Cage sobe no TTY1 automaticamente (sem prompt de login)
[ ] Chromium abre em modo kiosk na URL do instalador
[ ] Backend está respondendo (health check)
[ ] Sem erro "cannot take TTY" nos logs
[ ] systemctl status kryonix-installer-backend → active
```

---

## FASE 5 — Debug se Cage ainda não subir

```bash
# Dentro da VM, checar logs
journalctl -u getty@tty1 --no-pager | tail -20
journalctl -u kryonix-installer-backend --no-pager | tail -20

# Ver se cage está disponível
which cage
cage --version

# Teste manual do cage (dentro da VM)
cage -- chromium --kiosk http://localhost:8080
```

Erros comuns:
- `DRM device not found` → adicionar `hardware.opengl.enable = true`
- `Cannot open display` → Cage precisa estar no TTY, não em SSH
- `Permission denied /dev/dri` → usuário precisa estar no grupo `video` e `drm`
- Backend não respondeu → verificar `systemctl status kryonix-installer-backend`

---

## Commit

```bash
git -C /etc/kryonix add \
  modules/nixos/installer/web-kiosk.nix \
  hosts/iso/default.nix

git -C /etc/kryonix commit -m "fix: ISO kiosk Cage+Chromium via autologin shell

- Remove serviço systemd separado brigando com TTY1
- Cage inicia via shell do autologin (sem conflito)
- Usuário installer: grupos video/input/drm
- Backend espera health check antes de abrir Chromium
- Build ISO validado"

git -C /etc/kryonix push
```

---

## Regras

1. Não rodar qemu sem `-enable-kvm` — muito lento sem virtualização
2. Cage só funciona em TTY real ou KVM com vídeo — não em SSH puro
3. Chromium `--no-sandbox` é necessário em ISO (sem perfil de usuário persistente)
4. Backend NÃO deve escutar em 0.0.0.0 — somente 127.0.0.1 por segurança
5. Build da ISO demora — não cancelar antes de 5 minutos
6. Reportar `journalctl` completo se o Cage não subir
