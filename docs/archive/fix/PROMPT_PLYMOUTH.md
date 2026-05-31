# Prompt: Plymouth — Boot Splash Funcionando

> Problema: Plymouth não exibe splash e o verbose do init não some.
> Host: inspiron. Bootloader: verificar (systemd-boot ou GRUB).

---

## FASE 1 — Diagnóstico

```bash
# Ver config atual do Plymouth
grep -rn 'plymouth\|quiet\|splash\|consoleLogLevel\|initrd.verbose' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'

# Ver bootloader usado
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.loader.systemd-boot.enable
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.loader.grub.enable

# Ver se Plymouth está habilitado agora
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.plymouth.enable

# Ver kernelParams atuais
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.kernelParams

# Ver se está no initrd
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.initrd.systemd.enable

# Tema atual
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.plymouth.theme 2>/dev/null

# Ver temas disponíveis no sistema
ls /run/current-system/sw/share/plymouth/themes/ 2>/dev/null
```

Reportar tudo antes de editar.

---

## FASE 2 — Configuração correta do Plymouth

Localizar onde `boot.*` é configurado no projeto (provavelmente em
`hosts/inspiron/default.nix` ou `modules/nixos/common/default.nix`).

Aplicar a configuração completa:

```nix
# Suprimir verbose do boot — ESSENCIAL para Plymouth aparecer
boot.consoleLogLevel = 0;
boot.initrd.verbose  = false;

boot.kernelParams = [
  "quiet"           # suprime mensagens do kernel no console
  "splash"          # ativa Plymouth
  "rd.udev.log_level=3"   # suprime logs do udev no initrd
  "udev.log_priority=3"
];

boot.plymouth = {
  enable = true;
  theme  = "spinner";   # tema padrão confiável — ver FASE 3 para customizar
};
```

> `boot.initrd.verbose = false` é a linha que mais importa — sem ela o
> verbose do init aparece por cima do Plymouth e não some.

### Se o sistema usa systemd-boot

```nix
boot.loader.systemd-boot.editor = false;  # boa prática de segurança
```

O `quiet splash` nos `kernelParams` já é suficiente para suprimir.

### Se o sistema usa GRUB

```nix
boot.loader.grub = {
  # ...config existente...
  splashImage = null;  # evita conflito com Plymouth
};
```

---

## FASE 3 — Tema sci-fi para o Plymouth

Verificar quais temas estão disponíveis em nixpkgs:

```bash
nix search nixpkgs plymouth 2>/dev/null | grep theme | head -20
```

Opções boas para estética HUD:
- `spinner` — minimalista, confiável (padrão, sempre funciona)
- `tribar` — três barras animadas
- `bgrt` — usa logo do fabricante (Dell no seu caso)
- Temas do pacote `plymouth-themes` — incluem opções mais elaboradas

Para um tema personalizado com a paleta HUD (`#00d4ff`), a opção mais
simples é o `spinner` com cor customizada via override:

```nix
boot.plymouth = {
  enable = true;
  theme  = "spinner";

  # Opcional — forçar cor do spinner para o ciano HUD
  themePackages = with pkgs; [
    (ply-image.override { /* se suportado */ })
  ];
};
```

Se quiser explorar tema customizado depois, reportar os temas disponíveis
e decidir. Por agora, `spinner` garante que funciona.

---

## FASE 4 — Validação

```bash
# Build — Plymouth exige nixos-rebuild (não só home-manager)
nixos-rebuild build --flake /etc/kryonix#inspiron

# Confirmar que as opções foram aplicadas
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.plymouth.enable
# → true

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.kernelParams
# → deve conter "quiet" e "splash"

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.initrd.verbose
# → false

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.consoleLogLevel
# → 0

# Aplicar e reiniciar — Plymouth só é visível no boot real
sudo nixos-rebuild switch --flake /etc/kryonix#inspiron
sudo reboot
```

### Checklist pós-reboot

```
[ ] Verbose do kernel não aparece durante boot
[ ] Plymouth exibe animação de splash
[ ] Boot segue normalmente até o SDDM
[ ] SDDM abre corretamente após Plymouth
[ ] Em caso de erro no boot, Plymouth não oculta mensagens críticas
    (se travar, pressionar ESC para ver verbose)
```

---

## Commit

```bash
git -C /etc/kryonix add hosts/inspiron/default.nix  # ou onde ficou a config
git -C /etc/kryonix commit -m "feat: Plymouth boot splash

- boot.plymouth.enable = true, theme = spinner
- boot.initrd.verbose = false (suprime verbose que não sumia)
- boot.consoleLogLevel = 0
- kernelParams: quiet splash rd.udev.log_level=3
- Validado: boot sem verbose, Plymouth animado, SDDM abre normal"
git -C /etc/kryonix push
```

---

## Regras

1. `boot.initrd.verbose = false` é obrigatório — sem isso o verbose não some
2. Testar com `nixos-rebuild build` ANTES do switch (mudança de boot é arriscada)
3. O Plymouth só é visível em reboot real — `nixos-rebuild test` não testa
4. Se o boot travar após o switch, pressionar ESC no Plymouth mostra o verbose
5. Não misturar com mudanças de HM no mesmo commit
6. Se usar GRUB: remover `splashImage` para não conflitar
7. Reportar o bootloader usado e os `kernelParams` atuais antes de editar
