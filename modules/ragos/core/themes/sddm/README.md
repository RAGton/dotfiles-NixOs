# SDDM

Temas e wiring do display manager do cliente RAGOS.

- `ragos-control/`: tema canônico dark do cliente RAGOS, com card sólido e foco em operação.
- `ragos-sugar-light/`: legado mantido apenas como referência histórica de transição.
- `sddm.nix`: módulo NixOS que injeta o tema no sistema de forma declarativa.

Regra:

- preferir tema próprio quando o upstream não sustenta a linguagem visual do produto;
- evitar drift entre assets, wiring e captura do BrandLab;
- manter assets de branding dentro desta árvore.
