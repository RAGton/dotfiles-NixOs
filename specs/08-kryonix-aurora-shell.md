# Spec 08 — Kryonix Aurora Shell (KDE Plasma 6 + Rust + Qt/QML + HM)

> Shell próprio do Kryonix construído **sobre o KDE Plasma 6**: camada de identidade,
> theming, bar, launcher, control center e persistência declarativa via HM, sem
> reescrever o KWin nem forçar fork do Plasma. KDE é o motor; Kryonix vira a experiência.

## Princípio

O usuário quer **domar o KDE**, não abandoná-lo:
- KDE cru tem muita configuração manual que não vira Nix automaticamente.
- Plasma 6 + KWin + Wayland é uma base sólida (Qt/QML nativo, Kirigami, KWin scripting).
- `plasma-manager` já cobre: colorschemes, atalhos, painéis, widgets, KRunner, window rules.
- Falta: identidade visual própria, daemon de métricas, bar com CPU per-core, sync HM.

## Estado atual (verificado)

- `modules/nixos/desktop/kde/default.nix`: SDDM + Plasma 6 + Krohnkite, ativo quando
  `kryonix.desktop.environment = "kde"` (inspiron).
- `desktop/kde/theme.nix` + `kvantum.nix`: BonaFides Dark (default) + Kryonix Dark opt-in.
- `desktop/kde/scheme.nix`: `kryonix.desktop.kde.theme.colorScheme` (`"bonafides"` |
  `"kryonix-dark"`). Já produz `.colors` com tokens do Kryonix.
- `desktop/kde/tiling.nix`: Krohnkite via kwinrc (KWin script).
- `desktop/kde/keybinds.nix`: Meta+HJKL, workspaces, etc.
- `packages/kryonix-bar/`: daemon Rust existente com D-Bus `org.kryonix.Bar` — mesmo
  backend da Fase 7, reutilizar ou unificar.
- `packages/bonafides-theme.nix`: tema base.
- `plasma-manager`: input do flake, já suporta Plasma 6.
- KDE principal no `inspiron`; Hyprland/Caelestia preservados.

## Objetivos

- Kryonix Aurora Shell = camada de experiência sobre KDE Plasma 6.
- Theme Engine com tokens próprios, sem forçar transparência global.
- Bar (Kryonix Bar) com CPU per-core, RAM, GPU, rede, tray — QML ou Plasmoid.
- SDDM Kryonix (QML) com fallback Breeze obrigatório.
- Kryonix Control Center: app Qt/QML/Kirigami que edita settings.toml e sincroniza HM.
- Perfis declarativos: `productive | developer | minimal | gaming | client`.
- `kryonix shell capture/diff/apply/rollback` — sync HM bridge.
- Transparência controlada por classe de app via KWin window rules (não global).
- Tudo opt-in; KDE continua funcionando sem Aurora Shell ativo.

## Não-objetivos

- Reescrever KWin, Plasma shell ou qualquer componente do Qt upstream.
- Forçar transparência global em todos os apps.
- Usar `overrideConfig = true` agressivo no plasma-manager sem backup.
- Remover Hyprland/Caelestia ou Brain.
- Alterar `flake.lock` sem necessidade real.
- Declarar pronto sem validação completa.

---

## Arquitetura

### Visão geral

```
KDE Plasma 6 + KWin/Wayland
        │
Kryonix Aurora Shell Layer
├── kryonix-shell-daemon (Rust)  ← reutiliza / unifica kryonix-bar
│   ├── métricas (sysinfo)
│   ├── Hyprland IPC (se env=hyprland)
│   ├── lê/escreve settings.toml
│   ├── gera kryonix-shell.generated.nix
│   └── API 127.0.0.1
│
├── Kryonix Bar (QML Plasmoid ou standalone)
│   └── CPU/core, RAM, GPU, rede, tray, clock
│
├── kryonix-control-center (Qt/QML + Kirigami)
│   ├── edita settings.toml live
│   ├── preview runtime
│   ├── gera Nix / mostra diff
│   └── aciona kryonix home
│
├── sddm-kryonix-theme (QML)
│   └── fallback Breeze obrigatório
│
├── plasma-manager (HM)
│   ├── colorschemes, atalhos, widgets
│   ├── window rules (transparência por app)
│   └── KRunner, painéis
│
└── Home Manager bridge
    └── home/<user>/generated/kryonix-shell.generated.nix
```

### Opções públicas (`lib/options.nix`)

Extensão aditiva — nada muda nos defaults existentes:

```nix
kryonix.aurora = {
  enable = lib.mkEnableOption "Kryonix Aurora Shell layer";

  theme = {
    name    = lib.mkOption { type = str; default = "kryonix-dark"; };
    accent  = lib.mkOption { type = str; default = "#38BDF8"; };
    transparency.enable   = lib.mkOption { type = bool; default = false; };
    transparency.blur     = lib.mkOption { type = bool; default = false; };
    transparency.terminal = lib.mkOption { type = float; default = 0.84; };
    transparency.panel    = lib.mkOption { type = float; default = 0.78; };
  };

  bar = {
    enable         = lib.mkEnableOption "Kryonix Bar";
    showCpuPerCore = lib.mkOption { type = bool; default = true; };
    showRam        = lib.mkOption { type = bool; default = true; };
    showGpu        = lib.mkOption { type = bool; default = false; };
    showNetwork    = lib.mkOption { type = bool; default = true; };
  };

  profile = lib.mkOption {
    type    = enum [ "minimal" "productive" "developer" "gaming" "client" ];
    default = "productive";
  };

  sddm.theme = lib.mkOption {
    type    = enum [ "breeze" "kryonix" ];
    default = "breeze";  # fallback seguro
  };

  controlCenter.enable = lib.mkEnableOption "Kryonix Control Center";
};
```

### Transparência por classe (sem forçar global)

Via `plasma-manager` / kwinrc window rules:

```nix
# desktop/kde/transparency.nix
programs.plasma.window-rules = [
  { description = "Terminal opacity";
    match.window-class = { value = "konsole"; type = "substring"; };
    apply.opacity = { value = 84; type = "force"; }; }
  { description = "Dolphin opacity";
    match.window-class = { value = "dolphin"; type = "substring"; };
    apply.opacity = { value = 92; type = "force"; }; }
];
```

Browsers e IDEs ficam com `opacity = 100` (opacos) — padrão seguro.

### Persistência híbrida (padrão Spec 06)

```
UI edita → settings.toml (XDG_CONFIG_HOME, mutável)
         ↓ inotify (daemon relê < 1s)
         ↓ kryonix aurora save
~/kryonixos/kryonix-aurora/settings.toml  (commitado no downstream)
         ↓ + gera kryonix-shell.generated.nix
         ↓ mkOutOfStoreSymlink ← HM
Declarativo + vivo preservados
```

---

## Plano incremental (1 PR por passo)

### PR A — opções + scaffold (sem efeito visível)
- Adicionar bloco `kryonix.aurora.*` em `lib/options.nix` (defaults seguros).
- Criar `modules/nixos/desktop/kde/aurora.nix` (vazio, só estrutura).
- `nix flake check --keep-going` deve passar nos dois hosts.

### PR B — theme engine e transparência controlada
- `desktop/kde/aurora-theme.nix`: consolidar tokens Kryonix Dark + regras de
  transparência por classe via window rules (`plasma-manager`).
- Sem forçar opacidade global — apenas apps listados explicitamente.
- Garantir que `kryonix.desktop.kde.theme.colorScheme = "kryonix-dark"` continua
  funcionando como antes.
- Validar: `nix build .#homeConfigurations."rocha@inspiron".activationPackage`.

### PR C — Kryonix Bar KDE
- Decidir entre: **Plasmoid QML** (integrado ao painel Plasma) vs **janela
  standalone** via layer-shell (Quickshell).
- Recomendado MVP: Plasmoid QML simples (menos deps), consumindo API do daemon.
- `packages/kryonix-bar/` expande para servir também o frontend Plasmoid.
- Módulos: workspaces (via KWin DBus), CPU/core, RAM, clock, tray.
- Validação: build hermético; `plasmapkg2 -i` não requerido no CI.

### PR D — kryonix-shell-daemon unificado
- Unificar `packages/kryonix-bar/` e o daemon da Fase 7 num único crate
  (feature flags: `hyprland-ipc`, `kde-dbus`) ou manter separados via
  `kryonix.desktop.environment`.
- Rotas: `GET /status`, `GET /metrics`, `POST /theme`, `POST /aurora/save`.
- systemd user service; `Restart=on-failure`.
- Sem mudança na API pública da D-Bus `org.kryonix.Bar`.

### PR E — `kryonix aurora save` (CLI)
- `packages/kryonix-cli/lib/aurora.sh`: valida TOML, copia ao downstream,
  gera `kryonix-shell.generated.nix`, commita, `--switch` opcional.
- Subcomandos: `save | diff | apply | rollback`.
- Registrar em `registry.sh`.

### PR F — SDDM Kryonix Aurora
- `packages/sddm-kryonix-theme/` com `Main.qml`, assets Kryonix, fallback Breeze.
- `modules/nixos/desktop/kde/sddm.nix`: sempre coinstalar `libsForQt5.breeze-qt5`;
  assertion se `theme == "kryonix"` e `breeze-qt5` ausente.
- Documentar rollback: `kryonix.aurora.sddm.theme = "breeze"` + `nixos-rebuild --rollback`.
- **Nunca** aplicar em host vivo sem teste prévio em VM/ISO.

### PR G — Kryonix Control Center (MVP)
- `packages/kryonix-control-center/`: app Kirigami com abas Aparência, Bar, Atalhos, Perfis.
- Edita `~/.config/kryonix-shell/settings.toml` live.
- Botões: "Preview runtime" / "Exportar HM" / "Aplicar HM".
- Não substitui `kryonix aurora save` — é frontend para o mesmo fluxo.

### PR H — Perfis declarativos
- `profiles/aurora/productive.nix`, `developer.nix`, `minimal.nix`, etc.
- Cada perfil define subset de opções `kryonix.aurora.*`.
- Selecionado por `kryonix.aurora.profile`.

---

## Validação (DoD por PR)

```bash
nix fmt
nix flake check --keep-going --impure
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L
nix build .#homeConfigurations."rocha@inspiron".activationPackage --no-link -L
# a partir do PR D:
nix build .#kryonix-shell-daemon --no-link -L
cargo test --manifest-path packages/kryonix-shell-daemon/Cargo.toml
kryonix test
```

Smoke (host de teste, nunca inspiron produtivo de cara):
- KDE abre normalmente com `kryonix.aurora.enable = false` (default).
- Com `enable = true`: tema aplica, daemon roda, bar aparece.
- SDDM: testar com `sddm-greeter --theme kryonix` antes de ativar.
- `kryonix aurora save` commita no downstream.

## Segurança

- API daemon somente `127.0.0.1`; nenhum socket externo.
- Nenhum secret em `settings.toml` ou `.generated.nix` (whitelist no gerador).
- `plasma-manager overrideConfig` = false por padrão (não sobrescrever configs manuais).
- Tema SDDM nunca ativo sem `breeze-qt5` + `assertion`.

## Risco / Rollback

| Risco | Mitigação |
|---|---|
| Aurora theme sobrescreve BonaFides | `lib.mkIf cfg.enable` estrito; BonaFides permanece default |
| overrideConfig plasma-manager apaga configs manuais | `overrideConfig = false` default; doc clara |
| SDDM theme quebra login | Breeze sempre coinstalado; rollback `theme = "breeze"` + `--rollback` |
| Daemon D-Bus conflita com kryonix-bar atual | Feature flag ou alias; teste antes de remover |
| Plasmoid quebra entre versões Plasma | Pinar plasma-manager + validar no CI após bumps |
| `kryonix aurora save` corrompe downstream | Validação TOML antes de commit; `.bak` rotação |

Rollback global: `kryonix.aurora.enable = false` + `nixos-rebuild --rollback` restaura
estado anterior completo.

## Pendências / decisões abertas

- Bar: Plasmoid (integrado) vs Quickshell standalone. MVP = Plasmoid para menor risco.
- Daemon: unificar com Fase 7 ou manter separado por `environment`. Decisão no PR D.
- SDDM: `libsForQt5.breeze-qt5` vs `kdePackages.breeze` (KDE 6 usa `kdePackages`).
  Verificar qual está disponível no channel ativo antes do PR F.
- `overrideConfig`: decidir per-módulo ou global no PR A.
