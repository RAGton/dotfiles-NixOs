# Rollback por tag e por geração NixOS

Procedimentos seguros para reverter o Kryonix sem perder dados,
sem `git reset --hard` e sem force-push.

Skill: [`.claude/skills/git-dev-prod/SKILL.md`](../../.claude/skills/git-dev-prod/SKILL.md).
Política de release: [`RELEASE_ISO.md`](RELEASE_ISO.md).
Política de update: [`KRYONIX_UPDATE_POLICY.md`](KRYONIX_UPDATE_POLICY.md).

## 1. Quando usar qual rollback

| Cenário                                                | Método preferido                     |
|--------------------------------------------------------|--------------------------------------|
| Sistema bootou mas serviço crítico quebrou             | Rollback de geração NixOS            |
| Sistema **não** bootou                                  | Selecionar geração anterior no GRUB  |
| Quero voltar **código** para uma tag conhecida boa     | Rollback por tag git + boot/test     |
| Mudança experimental em DEV deu errado, não foi pushada| `git restore` / `git switch` em DEV  |
| Tag já em produção precisa ser invalidada              | Publicar nova tag corrigida; **nunca** sobrescrever a antiga |

## 2. Rollback por geração NixOS (rápido, sem git)

Não exige git. Funciona quando o `switch` recém-aplicado quebrou algo.

### 2.1 Sistema vivo (consegue logar)

```bash
sudo nixos-rebuild --rollback switch
# ou listar e escolher:
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --switch-generation <N> --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### 2.2 Sistema não boota

Reiniciar e escolher a geração anterior no menu do bootloader
(GRUB/systemd-boot). Cada geração antiga continua referenciada até ser
limpa via `nix-collect-garbage`.

Depois disso, alinhar o git para o estado correspondente
(`§3` ou `§4`).

## 3. Rollback por tag (preferido para reverter código)

Usa uma tag anotada já publicada (ver `RELEASE_ISO.md`).

```bash
# em PROD
cd /etc/kryonix
sudo git status --short          # tem que estar limpo
sudo git fetch --all --prune --tags

# inspecionar tags disponíveis
git tag --list 'v*' --sort=-v:refname | head

# checkout em detached HEAD na tag
sudo git checkout v0.1.0

# validações antes de qualquer ativação
kryonix check
kryonix diff

# preparar para o próximo boot — não dar switch direto
kryonix boot
# reiniciar e validar boot/serviços
```

Se a validação passar e o sistema ficar estável após reboot, considerar
o estado oficial:

```bash
# voltar para branch (sem mexer no working tree)
sudo git checkout main
sudo git pull --ff-only
```

Se a tag tiver de virar a nova "stable de produção", o caminho
recomendado é **outra tag** (`v0.1.1-revert`) com cherry-picks
explícitos, não force-push em `main`.

## 4. Rollback por reverter commits (em DEV)

Quando o problema veio de um commit específico e ainda é razoável
desfazer no histórico aberto:

```bash
cd /home/rocha/kryonix/kryonix
git fetch --all --prune
git switch main
git pull --ff-only

git log --oneline -20
git revert <sha>          # cria commit que desfaz <sha>
git push origin main
```

PROD então usa o fluxo normal (`KRYONIX_UPDATE_POLICY.md` §4).

## 5. O que **nunca** fazer

- `git reset --hard <sha>` sem aprovação explícita do usuário.
- `git push --force` em `main`.
- Recriar/movimentar tag publicada (`git tag -fa vX.Y.Z`).
- `git clean -fdx` em `/etc/*` (apaga estado real).
- `kryonix switch` imediato após rollback sem `check` + `diff` + `boot`.
- Editar `flake.lock` em `/etc/kryonix` para "forçar" um estado antigo.

## 6. Estado atual da CLI

Hoje existe rollback nativo do NixOS (`nixos-rebuild --rollback switch`),
mas o `kryonix` não expõe atalho para rollback por tag.

Pendência declarada (não escopo desta entrega):

```bash
kryonix rollback tag v0.1.0
kryonix rollback generation       # alias para nixos-rebuild --rollback switch
```

Deve:

1. Recusar se `PWD` não for `/etc/kryonix*` (PROD).
2. Recusar se o repo estiver dirty.
3. Fazer `fetch --tags`, conferir que a tag existe.
4. `git checkout <tag>` em detached HEAD.
5. Rodar `kryonix check` e `kryonix diff`.
6. Pedir confirmação antes de `kryonix boot` (nunca `switch` automático).

Implementar em PR separado, com mocks de geração e testes em VM.

## 7. Higiene após rollback

- Abrir issue rastreando a causa raiz do rollback.
- Anexar evidência: logs `journalctl`, output de `kryonix diff`,
  saída de `kryonix doctor full`.
- Decidir se a versão precisa ser yanked do GitHub Release
  (`gh release edit vX.Y.Z --draft=true` ou mover para pre-release com
  aviso).
- Atualizar `docs/CURRENT_STATE.md` se o status real do projeto mudou.
