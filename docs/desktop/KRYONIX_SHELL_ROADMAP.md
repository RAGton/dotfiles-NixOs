# Kryonix Shell — Roadmap

Este documento consolida o plano de desenvolvimento dos dois sabores do Kryonix Shell.
Para detalhes de cada PR, consulte as specs correspondentes.

Pré-requisito: build limpo dos dois hosts + Hermes removido (concluído 2026-06-06).

---

## Visão geral das fases

```
Fase 7 — Kryonix Shell WM (Hyprland puro)
  spec: specs/07-kryonix-shell.md
  skill: phase7-kryonix-shell

Fase 8 — Kryonix Aurora Shell (KDE Plasma 6)
  spec: specs/08-kryonix-aurora-shell.md
  skill: phase8-kryonix-aurora
```

As fases podem correr em paralelo se feitas em branches separadas.
O `kryonix-shell-daemon` é compartilhado — decidir unificação antes do PR D de cada fase.

---

## Fase 7 — Kryonix Shell WM

| PR | Entregável | Depende de | Status |
|---|---|---|---|
| 7A | Opções `kryonix.desktop.shell="kryonix"` + scaffold daemon | — | Pendente |
| 7B | IPC Hyprland socket2 + persistência TOML + inotify | 7A | Pendente |
| 7C | Bar QML mínima (workspaces + CPU/core + RAM + clock) | 7B | Pendente |
| 7D | Módulo HM ativa daemon + Quickshell via exec-once | 7C | Pendente |
| 7E | `kryonix shell save` CLI | 7D | Pendente |
| 7F | `sddm-kryonix-theme` opt-in | 7E | Pendente |
| 7G | Command palette + Brain (opt-in) | 7F | Opcional |

### MVP mínimo (7A → 7D)

```
daemon Rust coleta CPU/RAM
bar QML: workspaces + CPU% + RAM% + clock
settings.toml live
HM instala + Hyprland autostart
```

---

## Fase 8 — Kryonix Aurora Shell (KDE)

| PR | Entregável | Depende de | Status |
|---|---|---|---|
| 8A | `kryonix.aurora.*` em `lib/options.nix` + módulo vazio | — | Pendente |
| 8B | `aurora-theme.nix` + `transparency.nix` (window rules) | 8A | Pendente |
| 8C | Kryonix Bar como Plasmoid QML MVP | 8B | Pendente |
| 8D | Daemon unificado (feature flags kde-dbus + hyprland-ipc) | 8C + 7A | Pendente |
| 8E | `kryonix aurora save|diff|apply|rollback` CLI | 8D | Pendente |
| 8F | `sddm-kryonix-theme` (VM-first; fallback Breeze) | 8E | Pendente |
| 8G | `kryonix-control-center` MVP (Kirigami) | 8F | Pendente |
| 8H | `profiles/aurora/*` declarativos | 8G | Pendente |

### MVP mínimo (8A → 8C)

```
kryonix.aurora.enable = true
tokens Kryonix Dark aplicados
transparência Konsole + Dolphin + launcher
bar com CPU/core + RAM + clock (Plasmoid)
```

---

## Decisões pendentes (bloqueadores de PR D)

1. **Daemon unificado ou separado?**
   - Unificado (feature flags): menos binários, mais testável.
   - Separado: menor risco de regressão, deploy independente.
   - Recomendado: **unificado com feature flags** + compat D-Bus.

2. **Bar KDE: Plasmoid ou Quickshell standalone?**
   - Plasmoid: integrado ao painel, mais natural no KDE.
   - Quickshell: mesmo framework da Fase 7, reutiliza componentes.
   - Recomendado: **Plasmoid MVP**, depois opcional migrar para Quickshell.

3. **`breeze-qt5` vs `kdePackages.breeze` para SDDM fallback?**
   - Verificar qual está disponível no channel antes do PR F/8F.

---

## Cronologia sugerida (não bloqueante)

```
Jun–Jul 2026:  7A, 7B, 8A, 8B  (fundações; baixo risco)
Jul–Ago 2026:  7C, 7D, 8C      (UI MVP)
Ago–Set 2026:  8D (daemon), 7E, 8E (CLI bridges)
Set–Out 2026:  7F, 8F (SDDM; VM-first obrigatório)
Out–Nov 2026:  8G (control center), 8H (perfis)
Sob demanda:   7G (Brain palette)
```

---

## Critérios de conclusão (DoD compartilhado)

Para qualquer PR ser considerado pronto:

- [ ] `nix flake check --keep-going` passa nos dois hosts.
- [ ] Build dos dois toplevels (`inspiron`, `glacier`) sem erro.
- [ ] Build do `activationPackage` HM sem erro.
- [ ] `kryonix test` passa antes de qualquer switch.
- [ ] Smoke manual em host de teste (não inspiron produtivo).
- [ ] Rollback documentado e testado no mesmo PR.
- [ ] Bloco VIBECODE no PR: Plano / Diff / Teste / Risco / Rollback.

---

## Relacionado

- `docs/desktop/KRYONIX_SHELL_ARCHITECTURE.md` — arquitetura detalhada
- `docs/desktop/KRYONIX_AURORA_SHELL.md` — UX e design do Aurora Shell
- `specs/07-kryonix-shell.md` — spec técnica Fase 7
- `specs/08-kryonix-aurora-shell.md` — spec técnica Fase 8
- `specs/06-caelestia-hybrid.md` — padrão de persistência híbrida (base)
