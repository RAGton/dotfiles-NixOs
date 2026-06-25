# Arquitetura do Motor Kryonix

Esta documentação descreve a arquitetura estrutural do **upstream** Kryonix (`/etc/kryonix`). Para entender a relação deste repositório com as configurações de usuário e máquinas físicas, consulte o [README](README.md) sobre a arquitetura Dual-Flake.

## Árvore do Motor (Upstream)

A estrutura de diretórios foi pensada para maximizar reuso e separação de conceitos:

```txt
/etc/kryonix
├── flake.nix             # Ponto de entrada do Nix
├── flake/                # Lógica de integração e helpers (lib.nix)
├── modules/              # Funcionalidades atômicas e configuráveis (NixOS / Home Manager)
├── modules/nixos/features/ # Árvore canônica de features (schema.nix, registry.nix, etc)
├── features/             # (LEGACY/COMPAT) Combinações coesas de módulos a serem migradas
├── profiles/             # Casos de uso de alto nível que ativam features (ex: glacier-ai, laptop)
├── packages/             # Derivações customizadas de pacotes (ex: kryonix-cli, kryonix-brain-lightrag)
├── desktop/              # Configuração visual do sistema (Hyprland/KDE)
├── hosts/                # Definições base e ISO (common, inspiron base, iso)
├── overlays/             # Patches sobre o nixpkgs
├── lib/                  # Funções puras Nix
├── scripts/              # Utilitários bash/python avulsos
└── docs/                 # Documentação canônica do projeto
```

## Níveis de Abstração

O design do sistema segue uma escada de abstração rigorosa. Camadas superiores chamam as inferiores, nunca o inverso.

1. **Modules (Baixo Nível):**
   - Definem as "engrenagens" reais do sistema usando `lib.mkOption`.
   - Exemplo: `modules/nixos/services/brain.nix` cria a opção `kryonix.services.brain.enable` e sobe os systemd services (`ollama`, `kryonix-lightrag`, `kryonix-brain-api`).

2. **Features (Médio Nível):**
   - Ativam e configuram múltiplos módulos atômicos que fazem sentido juntos.
   - Exemplo: `features/ai.nix` liga o brain, configura túneis e variáveis de ambiente relevantes. Não define novos systemd units, apenas orquestra módulos.

3. **Profiles (Alto Nível):**
   - Definem "papéis" para máquinas inteiras. Ativam features.
   - Exemplo: `profiles/glacier-ai.nix` ativa o servidor IA, performance tuning e ferramentas de rede.

4. **Hosts (Nível Final):**
   - Onde o hardware encontra o software. Atribui um profile a uma máquina real.
   - **Nota:** Os hosts reais (`glacier`, `inspiron`) são definidos no repositório *downstream*, consumindo os profiles exportados pelo upstream.

## Integração Upstream → Downstream (Flake Lib)

A "cola" mágica entre os repositórios vive em `flake/lib.nix`.
O Kryonix expõe uma função de biblioteca `mkNixosConfiguration` que o downstream chama:

```nix
# Simplificação de como funciona
mkNixosConfiguration = hostname: username: inputs.nixpkgs.lib.nixosSystem {
  modules = [
    # 1. Base sempre vem do motor (upstream)
    inputs.kryonix.nixosModules.default

    # 2. Definição específica de hardware e role vem da instância (downstream)
    "${inputs.self}/hosts/${hostname}"
  ];
};
```

## Arquitetura de IA (Brain)

O Kryonix Engine fornece a infraestrutura completa para IA nativa, conhecida como **Kryonix Brain**:

- **Motor Central:** LightRAG + FastAPI encapsulado em `packages/kryonix-brain-lightrag`.
- **LLM Local:** Integração nativa com Ollama gerenciado via systemd.
- **Grafo:** Neo4j Community (local-only, restrito a Tailscale).
- **Dados:** Persistência padronizada em `/var/lib/kryonix/brain/`.
- **Topologia:** Suporte a separação Cliente/Servidor (ex: Inspiron atuando como cliente via túnel SSH/Tailscale acessando o Glacier como servidor IA).

## Feature architecture status

`modules/nixos/features/` is the canonical feature tree.

Current foundation:

- `schema.nix`: common namespace declarations
- `registry.nix`: feature metadata registry
- `development.nix`: canonical development feature
- `virtualization.nix`: canonical virtualization feature
- `gaming.nix`: canonical gaming feature
- `ai.nix`: partial namespace/compat layer, no runtime migration yet

Legacy wrappers remain under `features/` for compatibility during migration.
