# 04 — Especificação: Windows tiling manager e padronização cross-OS

## Objetivo

Documentar e opcionalmente versionar configs para Windows com fluxo de janelas parecido com o Plasma/KWin/Hyprland do Kryonix.

## Opções

### FancyZones

Uso:

- baixo risco;
- ideal para zonas fixas;
- não é tiling dinâmico real.

### Komorebi

Uso:

- tiling dinâmico real;
- JSON;
- CLI forte;
- bom para usuário técnico;
- depende de hotkey daemon como `whkd`;
- verificar licença conforme uso pessoal/comercial.

### GlazeWM

Uso:

- mais simples;
- configuração YAML;
- estilo i3;
- bom para começar rápido.

## Recomendação para Kryonix

Fornecer configs versionáveis, mas não misturar com NixOS:

```txt
windows/
├── komorebi/komorebi.json
├── komorebi/whkdrc
├── glazewm/config.yaml
└── README.md
```

## Padrão de teclas

Linux/KDE:

```txt
Meta + H/J/K/L          foco
Meta + Shift + H/J/K/L  mover janela
Meta + Ctrl + H/J/K/L   redimensionar
Meta + 1..9             workspace
```

Windows:

```txt
Alt + H/J/K/L           foco
Alt + Shift + H/J/K/L   mover janela
Alt + Ctrl + H/J/K/L    redimensionar
Alt + 1..9              workspace
```

## Entrega esperada

- configs de exemplo;
- README Windows;
- tabela comparativa;
- nenhum binário;
- nenhuma automação que mexa no Windows automaticamente.
