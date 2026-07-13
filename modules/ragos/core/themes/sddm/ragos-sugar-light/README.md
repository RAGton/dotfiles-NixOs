# RAGOS Sugar Light

Variante declarativa do tema upstream `MarianArlt/sddm-sugar-light`.

Objetivo:

- preservar o `Main.qml` e os componentes upstream;
- sobrescrever apenas branding, metadata e background;
- empacotar tudo via Nix em `/share/sddm/themes/ragos-sugar-light`.

Arquivos customizados no RAGOS:

- `Background.png`
- `theme.conf`
- `metadata.desktop`

Base upstream fixada em:

- repo: `https://github.com/MarianArlt/sddm-sugar-light`
- rev: `19bac00e7bd99e0388d289bdde41bf6644b88772`
