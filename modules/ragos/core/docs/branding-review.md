# Branding Review

Status: canonical
Scope: criterios objetivos e prova minima para branding real do RAGOS
Last reviewed: 2026-04-08

## Objetivo

Este documento existe para evitar duas falhas comuns:

- tratar wiring de tema no repositorio como se ja fosse prova visual;
- confundir screenshot de fallback, console ou framebuffer inativo com sucesso do branding.

## Estado atual implementado

Superficies com wiring declarativo real neste repositorio:

- Plymouth em `themes/plymouth/plymouth.nix` com tema `ragos`;
- SDDM em `themes/sddm/sddm.nix` com tema `ragos-control`;
- Plasma 6 em `themes/plasma/` com Global Themes, Plasma Styles, Color Schemes e wallpapers proprios;
- Integracao do desktop em `client/desktop/branding.nix`, importado pelos perfis oficiais de desktop.

Limites que precisam permanecer explicitos:

- GTK nao possui tema declarativo proprio no estado atual do repositorio.
- Nenhuma conclusao visual deve ser declarada como sucesso sem screenshot real ou checklist preenchido.
- Tela de console, journal, firmware, PXE ou framebuffer inativo nao conta como prova visual.

## Criterios objetivos

- O SDDM precisa deixar de parecer tema padrao de fallback.
- Hostname, perfil e area de autenticacao precisam continuar legiveis sobre o fundo.
- O wallpaper de login e o logo devem permanecer coerentes com Plymouth e Plasma.
- O desktop precisa permanecer coerente em dark e light, sem parecer tema generico de upstream.
- Clareza operacional tem precedencia sobre animacao, blur ou efeito.

## Prova minima para mudanca de branding

Sempre que `themes/sddm/`, `themes/plasma/` ou `client/desktop/branding.nix` mudar:

```bash
nix build --no-link --print-out-paths .#ragos-sddm-theme
nix build --no-link --print-out-paths .#ragos-plasma-theme
nix build --no-link --print-out-paths .#ragos-plasma-kde-store-bundles
nix eval --raw .#nixosConfigurations.ragos-client-dev-desktop-lab.config.services.displayManager.sddm.theme
```

Depois da validacao local:

```bash
sudo ragc switch --channel lab
ragc doctor
`ragos branding doctor`
```

A prova forte exige:

- screenshot real do cliente publicado parado no greeter;
- screenshot real do desktop publicado em dark;
- screenshot real do desktop publicado em light;
- evidencia de runtime com `ragos branding doctor` quando o host publicado estiver acessivel;
- evidencia no guest de `Current=ragos-control`;
- evidencia no guest de `sddm-greeter-qt6 --theme .../ragos-control`.
- evidencia no guest com `ragos-plasma-report` mostrando variante, Look and Feel, Plasma Style e Color Scheme ativos.

Antes de release oficial, repetir a mesma prova em `generic`.

## Guardrails

- nao tratar overlay efemero no guest como entrega final;
- nao tratar ajuste manual em `/etc/ragos` como fonte de verdade;
- nao promover release se `lab` ou `generic` ainda estiverem em fallback;
- nao declarar sucesso visual sem citar a captura e a prova no guest.
