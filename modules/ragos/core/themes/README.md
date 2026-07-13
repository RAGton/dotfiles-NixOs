# Themes

Diretorio canonico para assets de branding, splash e tipografia do RAGOS.

- `console-branding.nix`: fonte e identidade visual do console.
- `fonts/`: fontes vendorizadas usadas pelos modulos de tema.
- `plasma/`: Global Themes, Plasma Styles, Color Schemes e wallpapers do desktop Plasma 6.
- `plymouth/`: assets, tema e wiring do splash de boot.
- `sddm/`: tema da tela de login e modulo declarativo do display manager.

Regras de organizacao:

- fontes de terceiros devem ficar em `themes/fonts/<nome>/`;
- bundles upstream devem manter `LICENSE` e `README.md` juntos;
- assets de branding nao devem voltar para a raiz do repositorio;
- arvores legadas como `ragos/` nao devem ser reintroduzidas.
