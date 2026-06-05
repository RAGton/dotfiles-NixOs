# Kryonix Project

Kryonix é uma arquitetura de sistema operacional baseada em NixOS, projetada para ser hiper-declarativa, modular e orientada por agentes de Inteligência Artificial.

## O Que É Kryonix

Kryonix não é apenas um repositório NixOS. É um **engine** (motor) para construir sistemas. Ele define a infraestrutura base:
- Módulos e features reutilizáveis.
- Infraestrutura de IA (LightRAG, Ollama, Neo4j) via `kryonix-brain`.
- Perfis de uso (Workstation, Server, Gamer).
- Experiência de desktop (Caelestia / Hyprland).
- Um instalador TUI e ISO autônomos.

## O Que o Kryonix NÃO É

O Kryonix (este repositório, em `/etc/kryonix`) **não contém configurações de máquinas físicas específicas do usuário** (ex: seu laptop pessoal ou seu servidor caseiro). Ele fornece a fundação; as configurações de hardware e partições de máquinas reais vivem no repositório **Downstream**.

## Arquitetura Dual-Flake

O projeto segue um modelo estrito de "Dual-Flake":

1. **Upstream (O Motor)**
   - **Localização:** `/etc/kryonix`
   - **Repositório:** `github:RAGton/kryonix`
   - **Função:** Contém a lógica universal. Módulos, packages, perfis, features e a definição da imagem ISO.
   - **Hosts contidos aqui:** Apenas `common`, `inspiron` (como referência abstrata) e `iso`.

2. **Downstream (A Instância / Superflake)**
   - **Localização:** `/etc/kryonixos`
   - **Repositório:** `github:RAGton/Kryonixos`
   - **Função:** Materializa os hosts reais e as configurações de usuário.
   - **Hosts contidos lá:** `glacier` (Server/Brain), `inspiron` (Workstation/Client), `inspiron-nina`.
   - **Integração:** O `flake.nix` do downstream importa o upstream (`kryonix.url = git+file:///etc/kryonix`) e usa suas funções de biblioteca (`mkNixosConfiguration`) para montar as máquinas reais.

## Mapa da Documentação

- **[Estado Atual](CURRENT_STATE.md):** O que está implementado, o que é parcial e o que está quebrado.
- **[Roadmap](ROADMAP.md):** Planejamento de futuras versões.
- **[Arquitetura](ARCHITECTURE.md):** Como as peças se encaixam dentro do engine.
- **[Operações](OPERATIONS.md):** Como rodar, testar e fazer build.
- **[Segurança](SECURITY.md):** Políticas de secrets, MCP e diretrizes de hardening.
- **[Memória da IA (AI)](ai/PROJECT_CONTEXT.md):** Contexto estrito para LLMs e Agentes que operam neste projeto.

## Diretórios Principais do Engine

- `modules/`: Módulos base do NixOS e Home Manager.
- `features/`: Combinações de alto nível (ex: `ai.nix`, `gaming.nix`).
- `profiles/`: Arquétipos de uso (ex: `glacier-ai.nix`, `laptop.nix`).
- `packages/`: Pacotes empacotados pelo Kryonix (ex: `kryonix-brain-lightrag`, `kryonix-cli`).
- `desktop/`: Configurações de ambiente gráfico (Hyprland/KDE).
- `hosts/`: Definições básicas e a ISO do instalador.
