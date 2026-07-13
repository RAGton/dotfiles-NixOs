# Plymouth

Temas do splash de boot do RAGOS.

- `ragos/`: tema canônico do cliente netboot, empacotado via Nix.
- `plymouth.nix`: módulo NixOS que liga o tema ao `boot.plymouth`.

Direção do tema:

- leve o suficiente para initrd e netboot;
- assets pequenos e previsíveis;
- animação sutil via plugin `script`;
- branding forte sem visual exagerado.
