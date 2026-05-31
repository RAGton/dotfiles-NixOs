---
name: launcher-diagnosis
description: Encontra e corrige a causa real de apps abrindo errado, lentos ou não abrindo pelo launcher Caelestia no kryonix — problemas com desktop entries, uwsm, app2unit, wrappers e cache. Use quando o usuário reportar regressão no launcher, app abrindo pelo binário errado, falha em uwsm app --, ou dúvida entre desktop entry, wrapper e cache no glacier ou inspiron.
---

# Skill: Launcher Diagnosis

## Objetivo

Encontrar e corrigir a causa real de apps abrindo errado, lentos ou não abrindo pelo launcher do Caelestia.

## Quando usar

- regressão no launcher
- app abre pelo binário errado
- `uwsm app --` falha para entradas do launcher
- dúvida entre desktop entry, wrapper, cache, `app2unit` e `uwsm`

## Entradas

- host afetado
- apps de prova
- sintoma observado

## Passos

1. localizar o caminho real do launcher no código
2. confirmar se o app é gráfico ou `runInTerminal`
3. inspecionar o desktop entry publicado
4. comparar `uwsm app -- <id>` com `uwsm app -- <id>.desktop` e, se necessário, com caminho absoluto
5. observar processo, unit e janela
6. aplicar o menor patch robusto

## Comandos de validação

```bash
rg -n "kryonix-launch|rag-launch-desktop-entry|Apps.qml|uwsm app --" /home/rocha/src/caelestia-shell desktop modules
systemctl --user status caelestia --no-pager
find ~/.local/share ~/.nix-profile/share /run/current-system/sw/share -type f | rg '<app>\\.desktop$'
pgrep -af '<app>'
systemctl --user list-units 'app-*<app>*' --all --no-pager
hyprctl clients -j | jq
```

## Critérios de saída

- causa raiz identificada
- patch pequeno aplicado
- pelo menos um app crítico provado no caminho corrigido
- erro antigo separado de erro novo

## Riscos

- confundir bind explícito com o caminho do launcher
- tratar bug de runtime do app como bug do launcher
- trocar o launcher inteiro em vez de corrigir o helper mínimo
