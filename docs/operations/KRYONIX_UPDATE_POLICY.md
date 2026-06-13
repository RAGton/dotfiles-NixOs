# Política de `kryonix update`

Contrato canônico para o comando `kryonix update`. DEV e PROD se comportam
de formas diferentes — confundi-los é a forma mais comum de quebrar boot
do Kryonix em produção.

Skill ligada: [`.claude/skills/git-dev-prod/SKILL.md`](../../.claude/skills/git-dev-prod/SKILL.md).

## 1. Princípio

`flake.lock` é o registro reprodutível do sistema. Em PROD ele é
**resultado** de um pull, não objeto de escrita local. Em DEV ele é
material de trabalho.

Portanto:

- **DEV**: `kryonix update` pode atualizar `flake.lock`.
- **PROD**: `kryonix update` **nunca** atualiza `flake.lock`; apenas
  verifica se há commits/tags remotos novos e sincroniza via `git`.

## 2. Algoritmo

Pseudo-código que a CLI deve implementar:

```bash
kryonix_update() {
  env="$(detect_env)"
  repo="$(detect_repo_root)"

  git -C "$repo" fetch --all --prune --tags

  ahead="$(git -C "$repo" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)"

  case "$env" in
    DEV-MOTOR|DEV-SITE)
      [[ "$ahead" -gt 0 ]] && git -C "$repo" pull --ff-only

      if [[ "$env" == "DEV-MOTOR" ]]; then
        nix flake update --flake "$repo"
        if changed_flake_lock "$repo"; then
          kryonix fmt
          kryonix check
          kryonix test --host "$(hostname)"
          git -C "$repo" diff --stat
          echo "Sugestão: commit pequeno com a mudança de flake.lock"
        fi
      fi
      ;;

    PROD-MOTOR|PROD-SITE)
      if [[ "$ahead" -gt 0 ]]; then
        echo "INFO: $ahead commit(s) novos no GitHub."
        sudo git -C "$repo" pull --ff-only origin main
        if [[ "$env" == "PROD-MOTOR" ]]; then
          kryonix check
          kryonix diff
          echo "Aviso: kryonix switch NÃO será chamado automaticamente."
        fi
      else
        echo "OK: nenhum update remoto."
      fi
      # nunca: nix flake update
      ;;

    UNKNOWN)
      echo "ERRO: ambiente não reconhecido em $PWD." >&2
      return 1
      ;;
  esac
}
```

## 3. DEV — comportamento detalhado

1. `git fetch --all --prune --tags`.
2. Se `HEAD..@{u}` > 0 → `git pull --ff-only`.
3. `nix flake update`.
4. Se `flake.lock` mudou:
   - `kryonix fmt`
   - `kryonix check`
   - `kryonix test --host <hostname>` (não exigido para `kryonixos`)
   - `git diff --stat`
   - Imprimir sugestão de commit (mas **não** commitar
     automaticamente). Exemplo de mensagem aceitável:
     `chore(flake): bump inputs (YYYY-MM-DD)`.
5. Nunca empurrar push automático. Push é decisão humana.

## 4. PROD — comportamento detalhado

1. `git fetch --all --prune --tags`.
2. Se `HEAD..@{u}` > 0:
   - `sudo git pull --ff-only origin main`.
   - Se falhar com "not possible to fast-forward": **parar**, reportar
     divergência local; humano decide.
3. **Nunca** `nix flake update`.
4. **Nunca** escrever em `flake.lock` localmente.
5. Após pull:
   - `kryonix check`
   - `kryonix diff`
   - Reportar tags novas (`git tag --list 'v*' --sort=-v:refname | head`).
6. **Nunca** chamar `kryonix switch` automaticamente. Switch é decisão
   humana, sempre precedida de `kryonix test` ou `kryonix boot`.

## 5. Casos de borda

- **Repo dirty**: `git status` não vazio → abortar com erro claro.
- **Branch != main em PROD**: abortar. PROD só roda `main`.
- **Rebase/merge em andamento**: abortar (`MERGE_HEAD`, `rebase-apply`,
  `rebase-merge`, `CHERRY_PICK_HEAD` presentes).
- **Sem remote `origin`**: abortar.
- **`@{u}` não configurado**: warn e seguir; ainda assim não rodar
  `flake update` em PROD.

## 6. Estado atual vs alvo

Hoje (junho/2026), `kryonix update` está implementado em
[`packages/kryonix-cli/nixos.sh`](../../packages/kryonix-cli/nixos.sh)
(`update_flake_lock`, linha ~416) e:

- Roda `nix flake update` **sem** distinguir DEV/PROD.
- Bloqueia silenciosamente se hash do `flake.lock` não mudar.
- Não faz `git fetch` antes.
- Não decide com base em `PWD`.

Patch direcional (não aplicar nesta entrega — escopo é documentação):

```diff
 update_flake_lock() {
+  env="$(detect_env)"
+  case "$env" in
+    PROD-*)
+      echo "INFO: PROD detectado — pulando 'nix flake update'."
+      sync_prod_git
+      return 0
+      ;;
+  esac
   # …código atual permanece para DEV…
 }
```

Esse patch fica como pendência ligada a esta política. Implementar em
PR próprio, com testes de `kryonix-cli`.

## 7. Validação manual da política

Em DEV-MOTOR, simulando o ciclo:

```bash
cd /home/rocha/kryonix/kryonix
git status --short
kryonix update           # deve atualizar lock se houver
git diff --stat flake.lock
```

Em PROD-MOTOR, simulando:

```bash
cd /etc/kryonix
sudo git status --short
kryonix update           # NÃO pode tocar em flake.lock
git diff --stat flake.lock      # esperado: vazio
```

Se alguma dessas asserções falhar, abrir issue com label
`severity:critical` — política violada.
