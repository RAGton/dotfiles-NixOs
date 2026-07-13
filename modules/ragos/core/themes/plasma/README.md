# Plasma Themes

Arvore canonica dos componentes visuais do Plasma 6 do RAGOS.

Componentes mantidos aqui:

- `look-and-feel/`: Global Themes do Plasma
- `plasma-style/`: Plasma Styles (desktoptheme)
- `colors/`: Color Schemes
- `wallpapers/`: pacotes de wallpaper do Plasma
- `default.nix`: empacotamento Nix dos componentes e bundles para KDE Store / KDE Look
- `KDE-STORE.md`: nomes, descricoes e checklist de publicacao

Guardrails:

- sem symlinks dentro dos pacotes do Plasma
- `metadata.json` obrigatorio para Look and Feel, Plasma Style e Wallpaper
- os assets do desktop devem nascer aqui, nao em `/etc/ragos`
- coerencia visual com `themes/sddm/` e `themes/plymouth/` sem reabrir essas superficies como tarefa principal
