# 🤖 Regra de Governança para Agentes (Claude/Gemini)

Este documento define os limites operacionais e a arquitetura de decisão para assistentes de IA que operam neste repositório. **Siga estas regras rigorosamente.**

## 🎯 Escopo de Responsabilidades

### 1. Camada de Host (`/hosts/*`)
- **Foco:** Hardware, Kernel, Bootloader, Particionamento (Disko).
- **Regra:** Alterações aqui devem ser específicas da máquina. **NUNCA** adicione pacotes de usuário ou ferramentas de desenvolvimento diretamente no `default.nix` do host. Use os perfis.

### 2. Camada de Perfil (`/profiles/*`)
- **Foco:** Conjuntos lógicos de funcionalidade (Gamer, Dev, Rust, Workstation).
- **Regra:** Se a tarefa é "instalar ferramentas de X", crie ou modifique um perfil em `/profiles/`. O host apenas *habilita* o perfil.

### 3. Camada de Features (`/features/*`)
- **Foco:** Funcionalidades transversais e opcionais (AI, Virtualização, Gaming).
- **Regra:** Mantenha a separação entre a *declaração* da feature (em `/features/`) e sua *ativação* (via perfis ou hosts).

### 4. Camada de Módulos (`/modules/*`)
- **Foco:** Implementação de baixo nível e lógica NixOS/Home Manager.
- **Regra:** Não altere módulos globais para resolver problemas locais de um host. Se precisar de uma mudança global, garanta retrocompatibilidade.

## 🛡️ Regras de Ouro (Segurança e Integridade)

1.  **Imutabilidade do Upstream:** Este repositório (`/etc/kryonix`) é o **MOTOR**. Ele deve ser genérico o suficiente para ser usado por qualquer instância. Configurações pessoais e segredos vivem no repositório downstream (`/etc/kryonixos`).
2.  **Tratamento de Segredos:**
    *   **NUNCA** leia ou escreva arquivos em `/etc/sops/` ou chaves privadas.
    *   Use placeholders (ex: `/path/to/secret`) se uma configuração exigir um caminho de segredo.
3.  **Protocolo de Validação:**
    *   Sempre rode `nix flake check` após modificações.
    *   Se não puder validar localmente, instrua o usuário a rodar o comando explicitamente antes de cometer.
4.  **Declaratividade:** Prefira sempre opções customizadas (`kryonix.*`) em vez de `environment.systemPackages` puros, para manter a rastreabilidade.

## 📝 Como contribuir
Ao iniciar uma tarefa, identifique em qual camada ela se encaixa e respeite a hierarquia. Se uma mudança cruzar camadas, explique a racionalização no log de alteração.
