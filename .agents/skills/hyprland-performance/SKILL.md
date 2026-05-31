---
name: hyprland-performance
description: Diagnostica e reduz lentidão percebida em Hyprland/Caelestia no kryonix — launches lentos, animações excessivas, custo de blur/transparência e problemas de shell. Use quando o usuário reportar lentidão visual, animações pesadas, blur caro, travadas no Caelestia ou dúvida entre bug de launcher e custo gráfico do rice no glacier ou inspiron.
---

  # Skill: Hyprland Performance

## Objetivo

Reduzir lentidão percebida em Hyprland/Caelestia sem quebrar a operação diária do host.

## Quando usar

- shell lento
- animações excessivas
- custo alto de blur/transparência
- dúvida entre bug de launcher e custo visual do rice

## Entradas

- host afetado
- sintoma
- superfícies lentas: launch, redraw, input, blur, wallpapers

## Passos

1. separar lentidão de launch da lentidão visual
2. revisar `desktop/hyprland/hyprland.conf` e `home/**/caelestia-shell.nix`
3. confirmar se o shell depende de helper errado ou de efeito gráfico caro
4. reduzir custo no menor ponto possível
5. validar no host afetado

## Comandos de validação

```bash
hyprctl monitors
hyprctl clients -j | jq
systemctl --user status caelestia --no-pager
journalctl --user -u caelestia --since '10 minutes ago' --no-pager
nix build 'path:$PWD#nixosConfigurations.<host>.config.system.build.toplevel'
```

## Critérios de saída

- causa de custo identificada
- mudança reversível
- validação real no host alvo ou build do host afetado

## Riscos

- otimizar blur/animação quando o problema é launch incorreto
- mexer em binds e shell ao mesmo tempo sem necessidade
