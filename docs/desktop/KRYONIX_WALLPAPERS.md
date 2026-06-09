# Kryonix Wallpapers

Este documento descreve o pack oficial de wallpapers do Kryonix (`kryonix-aurora`), gerados proceduralmente (AI) para garantir licença livre (CC0-1.0) e coesão visual com a identidade do sistema (dark navy, accent verde/azul).

## Conteúdo do Pack (`kryonix-aurora`)

O pack está empacotado no flake via `packages/kryonix-wallpapers.nix` e contém duas séries de imagens:

### 1. Série Anime / Concept Art (com logo KRYONIX)
* `kryonix-anime-city-01.png` — **(Recomendado)** Cidade futurista verde ao pôr do sol.
* `kryonix-anime-char-01.png` — Guerreiro em falésia sobre cidade mágica verde.
* `kryonix-anime-landscape-01.png` — Ilha flutuante estilo Ghibli.
* `kryonix-anime-night-city.png` — Rua chuvosa cyberpunk com luzes neon verdes.
* `kryonix-anime-forest-mech.png` — Mech robô guardião na floresta bioluminescente.
* `kryonix-anime-01.png` — Cidade cyberpunk verde (aérea, noturna).
* `kryonix-anime-02.png` — Personagem em telhado sob lua cheia.

### 2. Série Space / Abstract (sem logo)
* `kryonix-aurora-01.png` — Nebulosa espiral azul (partículas e raios elétricos).
* `kryonix-aurora-02.png` — Grid hexagonal tech (azul elétrico sobre preto).
* `kryonix-aurora-03.png` — Aurora boreal sobre montanhas.
* `kryonix-aurora-04.png` — Ondas fluidas azuis (arte abstrata).
* `kryonix-aurora-05.png` — Glow minimalista azul (ideal para transparência total).
* `kryonix-aurora-06.png` — Galáxia espiral no espaço profundo.
* `kryonix-aurora-07.png` — Rede de partículas / constelações.

## Licença e Fontes

Todas as imagens neste diretório foram geradas via IA (Gemini 3.1) a pedido do usuário e são distribuídas sob licença CC0-1.0 (Domínio Público). Nenhuma imagem contém copyright de terceiros, assets pagos ou fotografias de pessoas reais.
O logo (Águia) em `logos/` foi gerado via SVG procedural.
O manifesto de fontes pode ser encontrado em `sources/manifest.json`.

## Como aplicar

O Kryonix gerencia o wallpaper declarativamente via `plasma-manager`.
No arquivo `desktop/kde/wallpaper.nix` (ou no profile correspondente), ajuste a propriedade `programs.plasma.workspace.wallpaper`:

```nix
programs.plasma.workspace.wallpaper = "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-anime-city-01.png";
```

Depois ative com `kryonix switch all`.

## Pendências (Slideshow)

Para suportar rotação automática (slideshow) declarativa no KDE Plasma via Nix, seria necessário configurar o plugin de imagem do plasma-manager ou injetar via `xdg.configFile."plasma-org.kde.plasma.desktop-appletsrc"`. No momento, apenas imagem estática é oficialmente suportada pelo módulo atual.
