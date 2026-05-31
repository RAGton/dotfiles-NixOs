# Conflitos de mkForce no NixOS

## O problema

No NixOS, quando a mesma opção é definida com `lib.mkForce` em dois ou mais
arquivos importados, o comportamento depende da **prioridade** — e nem sempre
é o que você espera. O erro silencioso mais comum é: a opção que você editou
não tem efeito porque outro arquivo a sobrescreve com mkForce de prioridade igual.

## Como detectar

```bash
# Buscar todas as definições de uma opção antes de editá-la
grep -rn 'sddm\|gdm\|greetd' /etc/kryonix --include='*.nix' \
  --exclude-dir='.git' | grep 'enable\|mkForce' | grep -v '#'
```

Se a mesma opção (ex: `sddm.enable`) aparecer em mais de um arquivo com `mkForce`,
há risco de conflito.

## Prioridades do NixOS (ordem crescente)

```
mkDefault (1000) < sem modificador (1500) < mkForce (50)
```

Quando dois `mkForce` colidem na mesma opção → **erro de avaliação** (bom, falha cedo).
Quando um `mkForce` e um valor normal colidem → mkForce vence silenciosamente (perigoso).

## Padrão seguro: um único ponto de verdade

```nix
# ❌ PERIGOSO — definido em 2 lugares
# desktop/hyprland/system.nix:
services.displayManager.sddm.enable = lib.mkForce false;

# modules/nixos/desktop/default.nix:
services.displayManager.sddm.enable = lib.mkForce true;

# → Resultado: erro de build "conflict" (neste caso é bom — detecta cedo)
# Mas se um usar mkForce e outro não:
# system.nix:   services.displayManager.sddm.enable = lib.mkForce false;
# default.nix:  services.displayManager.sddm.enable = true;  # sem mkForce
# → sddm fica desabilitado silenciosamente — bug difícil de encontrar
```

```nix
# ✅ SEGURO — um único arquivo define, outros não tocam
# modules/nixos/desktop/default.nix (o "gerente" de DM):
(lib.mkIf (env == "hyprland") {
  services.displayManager.gdm.enable  = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce true;
  services.displayManager.sddm.wayland.enable = true;
  services.greetd.enable = lib.mkForce false;
})

# desktop/hyprland/system.nix (só config específica do Hyprland, sem tocar no DM):
programs.hyprland = {
  enable = true;
  withUWSM = true;
};
# NÃO repete sddm.enable aqui
```

## Checklist anti-conflito antes de commitar

```bash
# Para cada opção que você mudou, verificar onde mais ela aparece
OPCAO="displayManager.sddm"
grep -rn "$OPCAO" /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'

# Verificar o valor real que o Nix vai usar
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.$OPCAO 2>&1
```

## Opções com conflito histórico no Kryonix

| Opção | Arquivos que já definiram | Ação |
|-------|--------------------------|------|
| `services.displayManager.gdm.enable` | `system.nix`, `desktop/default.nix` | Centralizar em `desktop/default.nix` |
| `services.displayManager.sddm.enable` | `system.nix`, `desktop/default.nix` | Centralizar em `desktop/default.nix` |
| `services.greetd.enable` | múltiplos | Centralizar em `desktop/default.nix` |
| `services.desktopManager.plasma6.enable` | `desktop/default.nix` | OK — único lugar |
