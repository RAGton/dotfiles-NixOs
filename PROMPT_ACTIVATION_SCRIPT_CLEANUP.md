# Prompts: Limpeza do Activation Script

Três correções independentes. Executar em ordem — cada uma é um commit separado.

---

## CORREÇÃO 1 — `ragosGitRepoPermissions`: `/etc/ragos` → `/etc/kryonix`

### Diagnóstico

```bash
# Encontrar onde esse snippet é definido
grep -rn 'ragosGitRepoPermissions\|/etc/ragos\|ragos' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'
```

### Correção

Localizar o arquivo que define o activation script `ragosGitRepoPermissions`.
Pode ser em `modules/nixos/common/default.nix` ou num módulo de branding/git.

Trocar todas as referências de `/etc/ragos` por `/etc/kryonix` e renomear
o snippet para `kryonixGitRepoPermissions`:

```nix
# Antes:
system.activationScripts.ragosGitRepoPermissions = { ... /etc/ragos ... };

# Depois:
system.activationScripts.kryonixGitRepoPermissions = {
  text = ''
    if [ -L /etc/kryonix ]; then
      ${pkgs.coreutils}/bin/chgrp -h kryonix /etc/kryonix || true
    elif [ -d /etc/kryonix ]; then
      ${pkgs.coreutils}/bin/chown -R rocha:kryonix /etc/kryonix || true
      ${pkgs.findutils}/bin/find /etc/kryonix -type d -exec \
        ${pkgs.coreutils}/bin/chmod 2775 {} +
      ${pkgs.findutils}/bin/find /etc/kryonix -type f -exec \
        ${pkgs.coreutils}/bin/chmod g+rw {} +
    fi
  '';
};
```

> Verificar também se o grupo `kryonix` existe ou se é `ragos` ainda.
> Se o grupo ainda se chama `ragos`, criar migration ou renomear via `users.groups`.

### Validação

```bash
nix flake check /etc/kryonix --keep-going 2>&1 | grep '^error' | head -5
nixos-rebuild build --flake /etc/kryonix#inspiron

# Confirmar que o snippet novo aparece na ativação
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.system.activationScripts \
  --apply 'scripts: builtins.attrNames scripts' | tr ',' '\n' | grep -i 'kryonix\|ragos'
```

### Commit

```bash
git -C /etc/kryonix commit -m "fix: renomeia ragosGitRepoPermissions → kryonixGitRepoPermissions

- /etc/ragos substituído por /etc/kryonix em todo o activation script
- Nome do snippet atualizado para refletir o projeto atual"
```

---

## CORREÇÃO 2 — `rustupBootstrap`: substituir por abordagem Nix correta

### Problema

`rustup toolchain install stable` num activation script:
- Exige internet em cada rebuild
- Não é reproduzível (versão do toolchain varia)
- Pode falhar em ambientes offline
- É o oposto da filosofia NixOS

### Diagnóstico

```bash
# Encontrar onde está definido
grep -rn 'rustupBootstrap\|rustup toolchain\|rustup show' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'

# Ver se rust já está declarado via Nix
grep -rn 'programs.rust\|rust-overlay\|fenix\|rustup' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#' | head -20

# Ver a versão do flake.lock para rust-overlay (se existir)
cat /etc/kryonix/flake.lock | grep -A3 'rust-overlay\|fenix'
```

### Opção A — via `rust-overlay` (já no flake.lock do projeto)

Se `rust-overlay` já está nos inputs:

```nix
# Em modules/nixos/common/default.nix ou home-manager
environment.systemPackages = with pkgs; [
  # Rust toolchain declarativo via rust-overlay
  (rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" "clippy" "rustfmt" ];
  })
];
```

### Opção B — via Home Manager (mais adequado para ferramentas de dev)

```nix
# Em modules/home-manager/common/default.nix
home.packages = with pkgs; [
  rustc
  cargo
  rustfmt
  clippy
  rust-analyzer
];
```

### O que fazer com o activation script

**Remover completamente** o snippet `rustupBootstrap` do activation script.
O toolchain Rust estará disponível via Nix — não precisa de bootstrap em runtime.

Se o usuário tiver projetos que usam `rustup` diretamente (para múltiplos
toolchains), pode manter o `rustup` como pacote mas NÃO como activation script:

```nix
home.packages = [ pkgs.rustup ];
# O usuário roda 'rustup toolchain install stable' manualmente uma vez
# — não em cada nixos-rebuild
```

### Validação

```bash
# Após remover o snippet, confirmar que rust ainda funciona
which rustc && rustc --version
which cargo && cargo --version

nixos-rebuild build --flake /etc/kryonix#inspiron
```

### Commit

```bash
git -C /etc/kryonix commit -m "fix: remove rustupBootstrap do activation script

- Rustup/rust declarado via Nix (rust-overlay ou home.packages)
- Activation script não deve instalar toolchains em runtime
- Elimina dependência de internet durante nixos-rebuild"
```

---

## CORREÇÃO 3 — `ragton.jpeg`: renomear avatar para nome correto

### Diagnóstico

```bash
# Encontrar onde o arquivo é referenciado
grep -rn 'ragton\|AccountsService\|avatar\|icons/rocha' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'

# Ver o arquivo atual
find /etc/kryonix/files -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" \
  | grep -iE 'avatar|ragton|rocha|face' | head -10

# Ver o arquivo no nix store (da geração atual)
ls /var/lib/AccountsService/icons/
```

### Correção

**Passo 1 — Renomear o arquivo de asset:**

```bash
# Se o arquivo é files/ragton.jpeg ou similar
mv /etc/kryonix/files/ragton.jpeg /etc/kryonix/files/rocha-avatar.jpeg
# ou
mv /etc/kryonix/files/avatar/ragton.jpeg /etc/kryonix/files/avatar/rocha.jpeg
git -C /etc/kryonix add -A
```

**Passo 2 — Atualizar a referência no .nix:**

```nix
# Localizar o activation script que faz o cp
# Trocar:
system.activationScripts.script.text = ''
  cp ${./files/ragton.jpeg} /var/lib/AccountsService/icons/rocha
  ...
'';

# Por:
system.activationScripts.accountsServiceAvatar.text = ''
  mkdir -p /var/lib/AccountsService/{icons,users}
  cp ${./files/rocha-avatar.jpeg} /var/lib/AccountsService/icons/rocha

  touch /var/lib/AccountsService/users/rocha
  if ! grep -q "^Icon=" /var/lib/AccountsService/users/rocha; then
    if ! grep -q "^\[User\]" /var/lib/AccountsService/users/rocha; then
      echo "[User]" >> /var/lib/AccountsService/users/rocha
    fi
    echo "Icon=/var/lib/AccountsService/icons/rocha" >> /var/lib/AccountsService/users/rocha
  fi
'';
```

> Renomear também o snippet de `script` para `accountsServiceAvatar`
> para ser descritivo sobre o que faz.

### Validação

```bash
nixos-rebuild build --flake /etc/kryonix#inspiron -L 2>&1 | grep -i 'ragton\|avatar'
# → não deve aparecer ragton

# Após switch, confirmar
ls -la /var/lib/AccountsService/icons/rocha
# → arquivo deve existir
```

### Commit

```bash
git -C /etc/kryonix commit -m "fix: renomeia ragton.jpeg → rocha-avatar.jpeg

- Nome do asset atualizado para refletir o projeto Kryonix
- Snippet 'script' renomeado para 'accountsServiceAvatar'
- Sem mudança funcional — apenas nomenclatura"
```

---

## Ordem de execução recomendada

```
1. Correção 3 (cosmética, zero risco)    → commit → push
2. Correção 1 (renomear paths, baixo risco) → nixos-rebuild build → commit → push
3. Correção 2 (remover rustup, validar rust ainda funciona) → commit → push
```

## Regras gerais

1. Cada correção é um commit separado — nunca juntar as 3
2. `nixos-rebuild build` antes de `switch` em cada uma
3. Na Correção 2: confirmar que `rustc --version` funciona ANTES de remover o snippet
4. Na Correção 1: verificar se o grupo `kryonix` existe (`getent group kryonix`)
5. Reportar o conteúdo do arquivo fonte de cada snippet antes de editar
