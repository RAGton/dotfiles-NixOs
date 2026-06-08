# Kryonix — Pacote de Especificação para Claude

Data: 2026-06-05

Objetivo: entregar uma especificação completa para um agente Claude/Codex/Antigravity fechar a parte de **KDE Plasma/KWin declarativo no NixOS**, **tiling**, **tema visual**, **barra/painéis**, **Home Manager** e **padronização opcional com Windows tiling manager**.

Este pacote foi escrito para ser usado dentro do repositório `/etc/kryonix`.

## Como usar

1. Abra `00_PROMPT_CLAUDE.md`.
2. Cole o conteúdo inteiro no Claude.
3. Anexe este ZIP ou copie o diretório `spec/` para o contexto do Claude.
4. Exija que ele leia o repositório real antes de editar qualquer coisa.
5. Exija commits pequenos e validação.

## Arquivos

```txt
00_PROMPT_CLAUDE.md                  Prompt mestre para o Claude
01_PROJECT_CONTEXT.md                Contexto Kryonix e regras operacionais
02_DESKTOP_SPEC.md                   Especificação Plasma/KWin/Home Manager
03_THEME_AND_BAR_SPEC.md             Tema, barra, painéis, SDDM/Plasma visual
04_WINDOWS_TILING_SPEC.md            Komorebi/GlazeWM/FancyZones
05_IMPLEMENTATION_PLAN.md            Plano de execução por fases
06_VALIDATION_AND_ROLLBACK.md        Testes, validação e rollback
07_ACCEPTANCE_CRITERIA.md            Critérios de pronto
08_AGENT_REPORT_TEMPLATE.md          Modelo de relatório final
templates/
  nix/
    plasma-module-skeleton.nix
    home-plasma-tiling-skeleton.nix
    home-plasma-theme-skeleton.nix
  kde/
    kwinrc.example
    kdeglobals.example
    kglobalshortcutsrc.notes
  windows/
    komorebi.json
    whkdrc
    glazewm-config.yaml
```

## Regra central

Não substituir o desktop atual do Kryonix sem opção explícita. O projeto usa Hyprland/Caelestia como stack desktop atual; Plasma deve entrar como perfil/módulo opt-in, seguro, declarativo e testável.
