# ADR-0003: Menus Auxiliares via `kryonix-menu`

Data: 2026-04-25

## Estado

Aceita.

## Contexto

O menu grafico legado era usado para fluxos auxiliares do desktop,
principalmente clipboard, janelas, power, audio, rede, gravacao de tela,
calculadora e acoes rapidas. Remover esse menu sem substituir esses fluxos
reduz a usabilidade real do Hyprland + Caelestia.

## Decisao

Centralizar menus auxiliares no wrapper declarativo `kryonix-menu`.

- Caminho grafico Wayland: `fuzzel --dmenu`
- Fallback nao-grafico/TTY: `fzf`
- Entry points versionados: `modules/home-manager/scripts/bin/kryonix-menu`,
  `kryonix-launcher`, `kryonix-clipboard-menu` e `kryonix-runner`
- Launchers de aplicativos continuam resolvendo `.desktop` e abrindo via
  `gtk-launch`
- Clipboard continua usando `cliphist` + `wl-clipboard`

## Consequencias

- Os launchers graficos antigos nao voltam como dependencias do desktop.
- Os fluxos que antes dependiam de menu grafico seguem acessiveis.
- A implementacao fica em um unico wrapper, reduzindo duplicacao em scripts
  Home Manager.
- `fzf` permanece apenas como fallback e ferramenta de terminal, nao como
  launcher grafico principal.
