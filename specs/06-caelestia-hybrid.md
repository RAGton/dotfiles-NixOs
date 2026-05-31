# Spec 06 — Caelestia Hybrid Mode

## Estado atual (verificado)

O módulo `desktop/hyprland/rice/caelestia-config.nix` gerencia três arquivos de
configuração via `home.activation.caelestiaMutableState`:

| Arquivo em runtime | Origem no store |
|---|---|
| `~/.config/caelestia/shell.json` | `pkgs.writeText` de `cfg.settings` |
| `~/.config/caelestia/shell-tokens.json` | `pkgs.writeText` de `cfg.tokens` |
| `~/.local/state/caelestia/scheme.json` | `pkgs.writeText` de `cfg.scheme` |

`writeMutableFile` copia store → disco se o conteúdo diferir. Consequência: qualquer
ajuste de cor, espaçamento ou app favorito exige `kryonix switch` completo. A Caelestia
UI pode modificar os arquivos em runtime, mas as mudanças se perdem no próximo switch.

## Problema

```
editar UI → arquivo muda → kryonix switch → arquivo SOBRESCRITO do store
```

O loop é unidirecional. Não existe caminho declarativo para persistir o estado da UI.

## Objetivos

- Edição ao vivo (sem rebuild) para: settings, scheme, tokens.
- Persistência declarativa: mudanças da UI viram commits no downstream kryonixos.
- Reprodutibilidade preservada: um clone fresco do kryonixos recria o estado exato.
- Sem perder tipagem Nix: as opções `kryonix.shell.caelestia.*` continuam existindo
  como fonte de defaults e inicialização.

## Não-objetivos

- Hot-reload do QuickShell (responsabilidade da Caelestia Shell, não deste módulo).
- Substituir o `kryonix switch` para mudanças estruturais (novos módulos, serviços).
- Sincronização multi-host automática (glacier ↔ inspiron).

---

## Arquitetura

### Localização canônica dos arquivos vivos

```
~/kryonixos/                    ← downstream git repo
└── caelestia/
    ├── shell.json              ← settings ao vivo (editável pela UI)
    ├── shell-tokens.json       ← tokens ao vivo
    └── scheme.json             ← scheme ao vivo
```

Estes arquivos **são parte do repositório downstream** — versionados, não gitignored.

### Fase A — `mkOutOfStoreSymlink` no módulo HM

Substituir as três chamadas `writeMutableFile` por symlinks para os arquivos vivos:

```nix
# desktop/hyprland/rice/caelestia-config.nix
config = lib.mkIf ((config.kryonix.shell.backend or null) == "caelestia") {

  # Symlinks apontam para os arquivos vivos no downstream repo.
  # mkOutOfStoreSymlink garante que o link sobrevive ao switch sem recriar.
  xdg.configFile."caelestia/shell.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/kryonixos/caelestia/shell.json";

  xdg.configFile."caelestia/shell-tokens.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/kryonixos/caelestia/shell-tokens.json";

  # Scheme vive em XDG_STATE_HOME, não configHome
  home.file.".local/state/caelestia/scheme.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/kryonixos/caelestia/scheme.json";
```

**Inicialização:** no primeiro switch (arquivo ausente), a activation cria o arquivo
com o conteúdo gerado a partir das opções Nix, e o symlink passa a apontar para ele.
Nos switches seguintes, o arquivo já existe e não é sobrescrito.

```nix
  home.activation.caelestiaHybridInit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    caelestia_dir="${config.home.homeDirectory}/kryonixos/caelestia"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$caelestia_dir"

    # Inicializa apenas se ausente (não sobrescreve mudanças do usuário)
    ${lib.optionalString (shellSettingsFile != null) ''
      if [ ! -e "$caelestia_dir/shell.json" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${shellSettingsFile} \
          "$caelestia_dir/shell.json"
      fi
    ''}
    ${lib.optionalString (shellTokensFile != null) ''
      if [ ! -e "$caelestia_dir/shell-tokens.json" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${shellTokensFile} \
          "$caelestia_dir/shell-tokens.json"
      fi
    ''}
    if [ ! -e "$caelestia_dir/scheme.json" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${shellSchemeFile} \
        "$caelestia_dir/scheme.json"
    fi
  '';
```

### Fase B — `kryonix caelestia save` (novo subcomando do CLI)

Implementado em `packages/kryonix-cli/caelestia.sh` (ou inline em `services.sh`):

```bash
cmd_caelestia_save() {
  local downstream="${KRYONIX_DOWNSTREAM:-${HOME}/kryonixos}"
  local caelestia_dir="${downstream}/caelestia"

  if [[ ! -d "$caelestia_dir" ]]; then
    printf 'kryonix: %s não existe. Execute kryonix switch primeiro.\n' \
      "$caelestia_dir" >&2
    return 1
  fi

  # Valida JSON antes de commitar
  for f in shell.json shell-tokens.json scheme.json; do
    if [[ -e "$caelestia_dir/$f" ]]; then
      jq . "$caelestia_dir/$f" > /dev/null \
        || { printf 'kryonix: %s inválido, abortando.\n' "$f" >&2; return 1; }
    fi
  done

  # Commit no downstream
  local msg="caelestia: save settings $(date '+%Y-%m-%d %H:%M')"
  git -C "$downstream" add caelestia/
  if git -C "$downstream" diff --cached --quiet; then
    printf 'kryonix caelestia save: sem mudanças para commitar.\n'
    return 0
  fi
  git -C "$downstream" commit -m "$msg"
  printf 'kryonix: configuração salva em %s\n' "$downstream"
}
```

Flags adicionais:
- `--switch` — dispara `kryonix switch` em background após o commit
- `--push` — faz `git push` para o remote configurado (ex: GitHub privado)
- `--dry` — imprime o diff sem commitar

### Fase C — Integração com a Caelestia UI

O QuickShell pode disparar comandos via `Quickshell.io.Process`. O botão
"Salvar Configuração" na UI executa:

```qml
// Em algum componente da Caelestia Shell
Process {
    id: saveProc
    command: ["kryonix", "caelestia", "save", "--switch"]
    onExited: (code) => {
        notif.send(code === 0
            ? "Configuração salva e aplicada"
            : "Erro ao salvar — ver journalctl")
    }
}
Button {
    text: "Salvar Configuração"
    onClicked: saveProc.start()
}
```

O `--switch` roda `kryonix switch` em background (sem bloquear a UI).

### Diagrama do fluxo completo

```
  [Caelestia UI]
       │ ajusta settings
       ▼
  ~/kryonixos/caelestia/shell.json  ←──────── symlink ──── ~/.config/caelestia/shell.json
       │                                        (mkOutOfStoreSymlink)
       │ clique "Salvar"
       ▼
  kryonix caelestia save
       │ jq validate → git add → git commit
       ▼
  ~/kryonixos/ (commit novo)
       │ --switch
       ▼
  kryonix switch (background)
       │ HM ativa symlinks, não sobrescreve arquivos
       ▼
  Sistema atualizado, settings preservadas
```

---

## Plano incremental (1 PR por passo)

1. **PR A — `mkOutOfStoreSymlink`**
   - Substituir `writeMutableFile` pelos três symlinks no módulo HM.
   - Adicionar `caelestiaHybridInit` para primeiro boot.
   - Adicionar `~/kryonixos/caelestia/.gitkeep` ao downstream.
   - Validar: `home-manager switch`, confirmar symlinks; editar shell.json manualmente,
     rodar switch novamente e confirmar que o arquivo NÃO foi sobrescrito.

2. **PR B — `kryonix caelestia save`**
   - Implementar subcomando em `packages/kryonix-cli/`.
   - Registrar no `registry.sh` e completions.
   - Validar: editar `~/kryonixos/caelestia/shell.json`, rodar save, confirmar commit.

3. **PR C — UI integration**
   - Patch na Caelestia Shell (via `overrideAttrs.postPatch` ou overlay) para adicionar
     o botão "Salvar Configuração" e o `Process` QML.
   - Validar: clique no botão → notificação → commit no downstream.

---

## Opção alternativa — `builtins.fromJSON` sem round-trip

Em vez de converter JSON → Nix (frágil), o próprio módulo HM pode ler o arquivo JSON:

```nix
# caelestia-shell.nix (no downstream kryonixos)
{ lib, ... }:
let
  settingsFile = ./caelestia/shell.json;
  settings = if builtins.pathExists settingsFile
    then builtins.fromJSON (builtins.readFile settingsFile)
    else {};
in {
  kryonix.shell.caelestia.settings = lib.mkForce settings;
}
```

Vantagem: sem serializer JSON→Nix. Desvantagem: `kryonix switch` necessário para
aplicar mudanças além do symlink (ex: mudanças que afetam geração de closures).
Para settings puros (scheme, apps favoritos, opacidade), o symlink ao vivo é suficiente.

---

## Validação

- `home-manager switch` cria symlinks e inicializa arquivos se ausentes.
- Editar `shell.json` manualmente → Caelestia relê sem rebuild (hot-reload nativo do QS).
- `kryonix switch` subsequente → symlinks permanecem, arquivos NÃO sobrescritos.
- `kryonix caelestia save` → commit aparece em `git log ~/kryonixos`.
- Clone fresco de kryonixos + `kryonix switch` → `caelestia/` inicializado dos defaults Nix.
- `kryonix caelestia save --dry` → imprime diff sem alterar repositório.

## Segurança

- `~/kryonixos/caelestia/` nunca deve conter secrets (tokens OAuth, chaves API).
  O `.gitignore` do downstream deve excluir `caelestia/*.secret` por precaução.
- `kryonix caelestia save --push` deve ser opt-in; o remote pode ser público por acidente.

## Risco / Rollback

| Risco | Mitigação |
|---|---|
| Switch sobrescreve settings da UI | `caelestiaHybridInit` usa `[ ! -e ]`; rollback: `git checkout caelestia/` |
| JSON corrompido pela UI | `jq validate` antes do commit; save aborta com mensagem clara |
| Symlink quebrado (kryonixos não existe) | Activation detecta ausência de dir e inicializa |
| Conflito git no downstream | `git -C ~/kryonixos stash` antes do switch |
| PR A quebra usuários sem downstream | `lib.mkIf (builtins.pathExists .../kryonixos)` no módulo |
