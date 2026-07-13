# RAGOS Plymouth Theme

Tema Plymouth autoral do RAGOS para o cliente netboot.

Base técnica escolhida:

- plugin `script` do Plymouth;
- empacotamento declarativo em Nix;
- assets raster leves e sem dependências externas.

Arquivos principais:

- `ragos.plymouth`: manifesto do tema;
- `ragos.script`: layout, animação, mensagens e barra de progresso;
- `background.png`: fundo escuro, geométrico e leve para boot;
- `logo.png`: marca principal com transparência;
- `progress-track.png` e `progress-fill.png`: barra de progresso;
- `frames/`: fluxo animado discreto em doze frames.

Regeneração de assets:

```bash
bash themes/plymouth/ragos/scripts/generate-assets.sh
```

Fontes atuais dos assets:

- `themes/plymouth/ragos/source-background.jpg`
- `installer/installer-ui/shared/public/imgs/ragton.png`
