# Spec 07 — Kryonix Shell (Hyprland + Qt/QML + Rust + Home Manager)

> Shell próprio do Kryonix construído **sobre o Hyprland**: UI em **Qt/QML**
> (Quickshell), daemon em **Rust** (telemetria, IPC, persistência) e
> configuração declarativa via **Home Manager**. Substitui a evolução do KDE
> como desktop principal, sem removê-lo agora.

## Estado atual (verificado)

- `desktop/hyprland/` já é a base ativa: `system.nix` (programs.hyprland, portals,
  UWSM), `core/` (monitors, rules, keybinds), `caelestia/` (shell QML) e
  `user.nix` ainda gigante (alvo da Spec 04).
- `packages/kryonix-bar/` existe com backend Rust (`buildRustPackage`) expondo
  D-Bus `org.kryonix.Bar`. **Ponto de partida** para o `kryonix-shell-daemon`,
  não reescrever do zero.
- Caelestia: shell QML + Quickshell + scheme/tokens já vivos via
  `caelestia-config.nix`. A Spec 06 institui o modo híbrido (symlinks +
  `kryonix caelestia save`); o Kryonix Shell coexiste como **alternativa**,
  selecionável via `kryonix.desktop.shell`.
- KDE: módulo em `modules/nixos/desktop/kde/` — congelado, **não evoluir**;
  não remover nesta spec.
- Lib: `lib/options.nix` já expõe `kryonix.desktop.environment` e
  `kryonix.desktop.shell` (enum). Estender com `kryonix-shell` é aditivo.

## Princípio

O usuário pediu explicitamente:
- WM-first com Hyprland; nada de KDE como WM.
- Qt/QML para UI fluida, Rust para daemon/telemetria/config, HM como persistência.
- Bar minimalista, transparência **sem blur pesado**, CPU per-core.
- SDDM theme próprio **com fallback Breeze**.

## Objetivos

- Shell próprio embarcado no repo upstream, opt-in via opção tipada.
- Persistência híbrida: edição ao vivo via UI + export declarativo HM
  (mesmo modelo da Spec 06, sem reinventar).
- Métricas reais (CPU per-core, RAM, GPU, rede, bateria) com custo baixo.
- IPC Hyprland em tempo real (workspaces, janela ativa) via socket UNIX.
- Tema SDDM `kryonix` com rollback automático para Breeze.
- Compatível com cache Cachix (binários pré-compilados; Inspiron não compila Rust).

## Não-objetivos

- Remover KDE, Caelestia ou Brain agora. KDE fica congelado, Caelestia segue
  como `kryonix.desktop.shell = "caelestia"` (default), Kryonix Shell entra como
  `"kryonix"` (opt-in).
- Reescrever `kryonix-bar` do zero — ele **vira** parte do `kryonix-shell-daemon`.
- Implementar comando-palette com Brain agora (fica para PR F, opcional).
- Hot-reload de novas opções Nix sem `kryonix switch` (limite assumido).
- Multi-host sync automático (glacier ↔ inspiron).

---

## Arquitetura

### Camadas

```
Kryonix Shell
├── Hyprland (compositor — já existe)
│   ├── IPC socket: $HYPRLAND_INSTANCE_SIGNATURE
│   ├── /tmp/hypr/<sig>/.socket.sock   (comandos hyprctl)
│   └── /tmp/hypr/<sig>/.socket2.sock  (eventos)
│
├── kryonix-shell-daemon (Rust)
│   ├── metrics.rs       — sysinfo: CPU/RAM/GPU/rede/bateria
│   ├── hyprland.rs      — escuta .socket2.sock, emite eventos
│   ├── config.rs        — lê/escreve ~/.config/kryonix-shell/settings.toml
│   ├── home_manager.rs  — gera kryonix-shell.generated.nix no downstream
│   ├── api.rs           — Axum bind em 127.0.0.1 (jsonrpc ou REST + SSE)
│   └── dbus.rs          — reaproveita org.kryonix.Bar (kryonix-bar atual)
│
├── kryonix-shell-ui (Qt/QML via Quickshell)
│   ├── Shell.qml         — entrypoint
│   ├── Bar.qml           — top bar minimalista
│   ├── Launcher.qml      — Super+Space
│   ├── ControlCenter.qml — Super+A
│   ├── Settings.qml      — Super+S (edita TOML)
│   └── components/       — widgets reutilizáveis
│
├── Home Manager (camada declarativa)
│   ├── home/<user>/hyprland/shell.nix       — toggle + defaults
│   └── home/<user>/generated/
│       └── kryonix-shell.generated.nix      — gerado pelo daemon
│
└── sddm-kryonix-theme (Qt/QML; pacote separado)
    └── Sempre acompanhado de fallback Breeze no module NixOS
```

### Persistência híbrida (mesmo padrão da Spec 06)

```
[UI Settings] → settings.toml (XDG_CONFIG_HOME, mutável)
       │ aplica live (daemon relê via inotify)
       ▼
~/.config/kryonix-shell/settings.toml
       │  kryonix shell save (subcomando novo)
       ▼
~/kryonixos/kryonix-shell/settings.toml  (commitado)
       │ + gera kryonix-shell.generated.nix
       ▼
home.file via mkOutOfStoreSymlink
```

Regra: **salvar = persistir TOML + gerar `.generated.nix`**; aplicar HM é botão
separado para evitar travar a UX a cada mudança de cor.

### Opções públicas (`lib/options.nix`)

```nix
kryonix.desktop.shell = mkOption {
  type = enum [ "caelestia" "kryonix" "dms" "none" ];
  default = "caelestia";  # mantido como default seguro
};

kryonix.home.shell = {
  enable = mkEnableOption "Kryonix Shell (Hyprland + Qt/QML)";
  theme = { name, accent, transparency, blur, radius, borderWidth };
  bar = { enable, position, showCpuPerCore, showRam, showGpu, showNetwork };
  keybinds.profile = mkOption { type = str; default = "kryonix-default"; };
};

kryonix.desktop.sddm.theme = mkOption {
  type = enum [ "breeze" "kryonix" ];
  default = "breeze";  # fallback seguro
};
```

---

## Plano incremental (1 PR por passo, build dos 2 hosts entre cada)

### PR A — opções + scaffold do daemon (sem efeito visível)
- `lib/options.nix`: adicionar `kryonix.desktop.shell = "kryonix"`,
  `kryonix.home.shell.*`, `kryonix.desktop.sddm.theme`. Defaults preservam
  comportamento atual (caelestia + breeze).
- Renomear/expandir `packages/kryonix-bar/` → `packages/kryonix-shell-daemon/`
  (manter compat: produzir binário `kryonix-bar` como alias durante transição).
- Crates: `tokio`, `serde`, `serde_json`, `toml`, `sysinfo`, `zbus`, `axum`,
  `notify`, `tracing`, `anyhow`, `clap`. Cargo.lock fixo.
- API local 127.0.0.1: `GET /status`, `GET /metrics`, `GET /theme`.
- Sem injeção em host ainda. **Validação:** `nix build .#kryonix-shell-daemon`.

### PR B — IPC Hyprland + persistência TOML
- `hyprland.rs`: conecta em `.socket2.sock`, parseia eventos (workspace, activewindow,
  openwindow, closewindow). Emite via API.
- `config.rs`: lê/escreve `~/.config/kryonix-shell/settings.toml`; usa `notify`
  para hot-reload (UI edita → daemon aplica).
- Validação: `cargo test`, daemon roda em foreground e mostra eventos quando
  você muda de workspace.

### PR C — `kryonix-shell-ui` (Quickshell + QML) mínimo
- `packages/kryonix-shell-ui/`: derivação `stdenv.mkDerivation` que instala QMLs
  em `$out/share/kryonix-shell/qml/`. Quickshell entra via `propagatedBuildInputs`.
- QML mínimo: `Bar.qml` com workspaces + CPU% + RAM% + clock. Consome a API
  do daemon via `Quickshell.io.Process` ou `XMLHttpRequest` em `127.0.0.1`.
- Estética: bg `rgba(11,15,20,0.72)`, accent `#38BDF8`, **sem blur**.
- Validação: build hermético via Nix; arquivos copiados sem precisar de sessão gráfica.

### PR D — módulo HM `kryonix.home.shell`
- `home/<user>/hyprland/shell.nix`: ativa via `kryonix.desktop.shell == "kryonix"`,
  instala daemon + UI, gera `~/.config/kryonix-shell/settings.toml` (defaults
  iniciais — só se ausente, `lib.hm.dag.entryBefore [ "linkGeneration" ]`).
- Hyprland: `exec-once` para daemon e Quickshell apontando para QMLs do pacote.
- Validação:
  `nix build .#homeConfigurations."rocha@inspiron".activationPackage`;
  `kryonix test`; ativar `kryonix.desktop.shell = "kryonix"` em host de teste
  (NÃO `inspiron` no merge — usar nina-style branch).

### PR E — `kryonix shell save` (subcomando CLI)
- Em `packages/kryonix-cli/lib/shell.sh` (segue o padrão de `caelestia.sh`).
- `kryonix shell save [--switch] [--push] [--dry]`:
  - valida TOML com `toml-cli` (ou parser puro no daemon via flag `--validate`),
  - copia `~/.config/kryonix-shell/settings.toml` → `~/kryonixos/kryonix-shell/`,
  - regenera `kryonix-shell.generated.nix` no downstream,
  - `git add` + `git commit` no downstream,
  - `--switch` dispara `kryonix switch` em background.
- Registrar em `registry.sh` e completions.

### PR F — `sddm-kryonix-theme` (opt-in, com fallback)
- `packages/sddm-kryonix-theme/` com `theme/` (Main.qml, theme.conf,
  metadata.desktop, assets/, components/).
- Módulo NixOS: `services.displayManager.sddm.theme =
  config.kryonix.desktop.sddm.theme;`. Sempre instalar `libsForQt5.breeze-qt5`
  junto. Rollback documentado.
- **Não trocar greeter em host vivo sem booting prévio em VM/USB.**

### PR G — (opcional) Command palette + Brain
- `Super+X` abre palette; consome `127.0.0.1` do Brain (já existe via Tailscale
  em `glacier`). Cada comando sugerido pela IA é **explicável** antes de
  executar (mostra a string final). Off-by-default.

---

## Validação (DoD por PR)

```bash
nix fmt
nix flake check --keep-going --impure
nix build .#kryonix-shell-daemon --no-link -L
nix build .#kryonix-shell-ui --no-link -L           # após PR C
nix build .#homeConfigurations."rocha@inspiron".activationPackage --no-link -L
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L
kryonix test                                         # antes do switch
```

Smoke manual (em host de teste, **não** `inspiron` produtivo de cara):
- Daemon roda como service do usuário, sem traceback em `journalctl --user`.
- Bar aparece, mostra workspace correto ao alternar.
- Editar `settings.toml` muda accent em &lt; 1 s (inotify).
- `kryonix shell save` commita em `~/kryonixos/`.

## Segurança

- API daemon **somente em 127.0.0.1**; nunca abrir socket TCP externo.
- Nenhum secret (token GitHub, KRYONIX_BRAIN_KEY) trafega pela UI; configs do
  Brain ficam em `/etc/kryonix/brain.env` como hoje.
- `kryonix-shell.generated.nix` no downstream é **público por padrão** — proibir
  campos sensíveis (whitelist no gerador, não blacklist).
- Tema SDDM nunca é aplicado sem `breeze-qt5` instalado junto (`assertion`).

## Risco / Rollback

| Risco | Mitigação |
|---|---|
| Daemon trava → bar some | `Restart=on-failure`, `RestartSec=2s`; bar usa último cache em arquivo |
| TOML corrompido | Daemon valida antes de gravar; UI mostra erro inline; arquivo `.bak` por rotação |
| SDDM theme quebra login | Sempre coinstalar Breeze; `nixos-rebuild boot` antes de `switch`; rollback `services.displayManager.sddm.theme = "breeze";` + `nixos-rebuild --rollback` |
| Coexistência Caelestia × Kryonix Shell | Apenas um ativo por sessão (enforce via `assertion` no módulo HM) |
| Cache Cachix sem o pacote | CI da Spec 03 builda `kryonix-shell-daemon` e empurra; Inspiron nunca compila Rust local |
| Hyprland muda formato IPC | Wrap do parser atrás de trait; testes unitários com fixtures de evento |
| Quickshell quebra entre versões | Pinar versão no overlay; documentar bump em CHANGELOG |

Rollback global: `kryonix.desktop.shell = "caelestia"` + `nixos-rebuild --rollback`
restaura o estado anterior; binários do Kryonix Shell continuam instalados mas
inertes.

## Pendências / decisões abertas

- Nome do binário: `kryonix-shell-daemon` vs renomear o atual `kryonix-bar`.
  Proposta: PR A produz **ambos** (`kryonix-bar` como alias) por uma geração,
  depois remove o alias.
- Quickshell vs Qt6 puro: **Quickshell** vence (já provê SystemTray, PipeWire,
  UPower, layer-shell prontos; menos código novo).
- Tema cores em arquivo único `.colors` (como `kryonix.desktop.kde.theme`) vs
  campos individuais no TOML. Manter consistência com KDE Kryonix Dark.
