# Prompt: Corrigir hyprland.conf — erro de parsing + atalhos não funcionam

> Situação: SDDM + Caelestia + Hyprland UWSM sobem OK (black screen resolvido).
> Mas o hyprland.conf tem erro e NENHUM atalho funciona.
> Causa provável: erro de parsing no config faz o Hyprland parar de ler os binds.
> Objetivo: deixar a config 100% declarativa e correta, sem erro de escrita.

---

## Princípio do diagnóstico

Quando o Hyprland encontra uma linha inválida no config, ele registra o erro e
**pode parar de processar o resto do arquivo**. Se os `bind` vêm depois do erro,
nenhum atalho funciona. Precisamos achar a PRIMEIRA linha com erro.

"Erro de escrita" = o arquivo é symlink read-only do Nix store (gerenciado pelo HM)
e algo tenta escrever nele em runtime. Tudo deve ser declarativo.

---

## FASE 1 — Capturar o erro exato

```bash
# Ver os erros de config que o Hyprland reportou
hyprctl configerrors

# Log do Hyprland — procurar a primeira linha de erro de parsing
cat ~/.local/share/hyprland/hyprland.log 2>/dev/null | grep -iE 'error|invalid|failed|config|line' | head -30

# Ver se os binds estão registrados (se vazio ou poucos = parsing parou cedo)
hyprctl binds | head -40
hyprctl binds | wc -l
```

`hyprctl configerrors` é o mais direto — ele lista exatamente quais linhas
do config estão inválidas. **Reportar a saída completa antes de editar.**

---

## FASE 2 — Entender a estrutura atual do config

```bash
# Como o config é montado? Raw conf, settings declarativo, ou misto?
grep -rn 'extraConfig\|settings\|readFile\|hyprland.conf' \
  /etc/kryonix/desktop/hyprland --include='*.nix' | head -20

# Ver o arquivo conf raw, se existir
wc -l /etc/kryonix/desktop/hyprland/hyprland.conf 2>/dev/null
grep -n 'bind\|\$mainMod\|monitor=\|exec-once' /etc/kryonix/desktop/hyprland/hyprland.conf 2>/dev/null | head -40
```

Identificar:
- O config é raw (`hyprland.conf` via `readFile`) ou declarativo (`settings`)?
- Onde os binds de multi-monitor foram adicionados?
- Há conflito entre `$mainMod` definido no raw e binds em `settings` (que não veem `$mainMod`)?
- Há duplicação de binds entre raw e declarativo?

---

## FASE 3 — Causas mais prováveis (verificar cada uma)

### Causa A — `$mainMod` não definido onde os binds foram adicionados

Se os binds de multi-monitor foram adicionados via `settings.bind` mas usam
`$mainMod`, e `$mainMod` só existe no raw `hyprland.conf` → os binds com `$mainMod`
falham porque a variável não está no escopo daquele bloco.

```bash
grep -rn '\$mainMod\|mainMod' /etc/kryonix/desktop/hyprland --include='*.nix' \
  --include='*.conf' | head -20
```

### Causa B — sintaxe inválida nos binds de multi-monitor

Verificar os binds adicionados. Sintaxe correta do Hyprland:
```
bind = $mainMod, P, exec, kryonix-monitors menu          # OK
bind = $mainMod, period, focusmonitor, +1                # OK
bind = $mainMod SHIFT, period, movewindow, mon:+1        # OK
bind = $mainMod CTRL, period, movecurrentworkspacetomonitor, +1   # OK
```

Erros comuns:
- vírgula a mais/a menos nos campos
- `focusmonitor, +1` com espaço errado
- usar nome de tecla inválido

### Causa C — diretiva `monitor=` ou `exec-once` inválida antes dos binds

Se o bloco de monitor (do monitors.nix) tem uma linha inválida E é carregado
ANTES dos binds → o parsing para antes de chegar nos binds.

```bash
grep -rn 'monitor=\|workspace=\|exec-once' /etc/kryonix/desktop/hyprland \
  --include='*.nix' --include='*.conf'
```

### Causa D — algo escrevendo no config read-only

```bash
# Verificar se o hyprland.conf é symlink do store (read-only)
ls -la ~/.config/hypr/hyprland.conf
# Se for symlink para /nix/store → read-only → qualquer escrita falha
```

Se o `kryonix-monitors` ou o Hyprland tentam persistir layout no arquivo →
falha. A solução é o estado ir para `~/.local/state/`, NUNCA para o config.

---

## FASE 4 — Correção: tornar tudo declarativo e correto

### Estratégia recomendada: binds declarativos em um único lugar

Se o projeto usa raw `hyprland.conf`, **manter os binds no raw conf** (não misturar).
Se usa `settings`, manter tudo em `settings.bind`. NÃO misturar os dois.

#### Opção 1 — tudo no raw hyprland.conf (se já é o padrão)

Garantir que os binds de multi-monitor estão no `hyprland.conf` com `$mainMod`
definido no topo do mesmo arquivo, e SEM erro de sintaxe:

```
# No topo do hyprland.conf (deve já existir)
$mainMod = SUPER

# Binds multi-monitor (verificar sintaxe exata)
bind = $mainMod, P, exec, kryonix-monitors menu
bind = $mainMod ALT, P, exec, kryonix-monitors mode toggle
bind = $mainMod, period, focusmonitor, +1
bind = $mainMod, comma, focusmonitor, -1
bind = $mainMod SHIFT, period, movewindow, mon:+1
bind = $mainMod SHIFT, comma, movewindow, mon:-1
bind = $mainMod CTRL, period, movecurrentworkspacetomonitor, +1
bind = $mainMod CTRL, comma, movecurrentworkspacetomonitor, -1
bind = $mainMod ALT, S, exec, kryonix-monitors swap
```

#### Opção 2 — tudo declarativo em settings.bind (mais limpo)

Migrar TODOS os binds para `settings.bind` como lista declarativa. Aqui `$mainMod`
é definido via `settings."$mainMod"`:

```nix
wayland.windowManager.hyprland.settings = {
  "$mainMod" = "SUPER";

  bind = [
    # ... binds existentes migrados ...

    # Multi-monitor
    "$mainMod, P, exec, kryonix-monitors menu"
    "$mainMod ALT, P, exec, kryonix-monitors mode toggle"
    "$mainMod, period, focusmonitor, +1"
    "$mainMod, comma, focusmonitor, -1"
    "$mainMod SHIFT, period, movewindow, mon:+1"
    "$mainMod SHIFT, comma, movewindow, mon:-1"
    "$mainMod CTRL, period, movecurrentworkspacetomonitor, +1"
    "$mainMod CTRL, comma, movecurrentworkspacetomonitor, -1"
    "$mainMod ALT, S, exec, kryonix-monitors swap"
  ];
};
```

**Escolher a opção que combina com o que o projeto JÁ usa.** Não introduzir um
segundo sistema de binds em paralelo — isso causa duplicação e conflito.

### Garantir que kryonix-monitors usa path absoluto

No `exec-once` e nos binds que chamam `kryonix-monitors`, se o binário não está
no PATH do Hyprland, o bind "funciona" mas não faz nada. Verificar:

```bash
which kryonix-monitors
# Se não estiver no PATH, usar path absoluto nos binds:
# bind = $mainMod, P, exec, ${pkgs.kryonix-monitors}/bin/kryonix-monitors menu
```

---

## FASE 5 — Validação

```bash
# 1. Avaliar o flake
nix flake check /etc/kryonix --keep-going 2>&1 | grep '^error' | head -10

# 2. Build + switch do home (binds são config de usuário)
home-manager switch --flake /etc/kryonix#rocha@inspiron
# ou: kryonix switch (se os binds forem no nível de sistema)

# 3. Recarregar o Hyprland sem deslogar
hyprctl reload

# 4. CRÍTICO: verificar que não há mais erros
hyprctl configerrors
# → deve retornar vazio ou "no errors"

# 5. Verificar que os binds foram registrados
hyprctl binds | wc -l
# → deve ter MUITOS binds agora (não poucos)

# 6. Testar na prática
# Super+T → terminal abre
# Super+P → menu de monitor abre
```

`hyprctl reload` aplica o config sem precisar deslogar — se der certo, os atalhos
voltam na hora. Se `hyprctl configerrors` ainda mostrar erro, a linha problemática
ainda está lá.

---

## FASE 6 — Commit (após hyprctl configerrors limpo)

```bash
git -C /etc/kryonix add desktop/hyprland/
git -C /etc/kryonix commit -m "fix: corrige parsing do hyprland.conf — atalhos voltam a funcionar

- Erro de config fazia o Hyprland parar de ler os binds (nenhum atalho funcionava)
- [descrever a causa exata encontrada na FASE 1]
- Binds consolidados em [raw conf | settings.bind] — sem mistura
- kryonix-monitors com path absoluto nos binds/exec-once
- Validado: hyprctl configerrors limpo, hyprctl binds registra todos"
git -C /etc/kryonix push
```

---

## Regras

1. Rodar `hyprctl configerrors` PRIMEIRO — ele aponta a linha exata do erro
2. NÃO misturar binds raw (.conf) com declarativos (settings.bind) — escolher um
3. Usar `hyprctl reload` para testar sem deslogar (rápido e seguro)
4. Nada deve escrever no hyprland.conf em runtime — estado vai para ~/.local/state/
5. Reportar a saída de `hyprctl configerrors` e `hyprctl binds | wc -l` antes e depois
6. Se o erro estiver no bloco de monitor, corrigir lá — é o que trava o parsing dos binds
```
