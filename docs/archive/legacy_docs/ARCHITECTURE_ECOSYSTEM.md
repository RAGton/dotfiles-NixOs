# 🏗️ Ecossistema Kryonix: Upstream vs. Downstream

Este documento explica a arquitetura de separação entre o **Motor** (Upstream) e a **Instância** (Downstream). Esta estrutura foi desenhada para garantir que o sistema seja modular, fácil de atualizar e "à prova de IA".

---

## 1. O Upstream (`/etc/kryonix`) - O MOTOR
O repositório upstream é a inteligência do sistema. Ele contém a definição de *como* as coisas funcionam, mas não *quem* as usa.

### O que vive aqui:
- **`modules/`**: Implementação lógica de baixo nível (NixOS e Home Manager). Se você quer mudar como o VSCode é instalado ou como o kernel Zen é configurado, o código vive aqui.
- **`features/`**: Funcionalidades opcionais e transversais (AI, Virtualização, Gaming). Define as opções `kryonix.features.*`.
- **`profiles/`**: Conjuntos lógicos de ferramentas (ex: `dev-rust`, `workstation-gamer`). Agrupam features para facilitar o uso.
- **`packages/`**: Builds de pacotes customizados (CLI `kryonix`, `kora`, etc).
- **`lib/`**: Helpers e funções Nix que sustentam a infraestrutura do flake.

### Regra de Ouro:
> **Mude aqui se:** A alteração for útil para qualquer máquina rodando Kryonix no futuro.
> **Exemplo:** Adicionar um novo kernel, corrigir um bug no script de voz da Kora, ou criar um novo perfil "Data Science".

---

## 2. O Downstream (`/etc/kryonixos`) - A INSTÂNCIA
O repositório downstream é a sua personalização. Ele consome o motor e define *onde* e *por quem* ele é usado.

### O que vive aqui:
- **`hosts/`**: Configurações de hardware real. UUIDs de disco, drivers de vídeo, bootloader e rede. Cada pasta representa um PC físico (ex: `inspiron`, `glacier`).
- **`users/`**: A identidade humana. Configurações de Home Manager, dotfiles, preferências de tema e chaves SSH.
- **`profiles/`**: Presets locais que não fazem sentido no upstream (ex: segredos de empresa ou caminhos de pastas específicos do seu backup).
- **`flake.nix`**: O "cola-tudo" que importa o upstream como um input e materializa o sistema.

### Regra de Ouro:
> **Mude aqui se:** A alteração for pessoal ou específica de um hardware.
> **Exemplo:** Mudar o papel de parede, trocar a partição de swap, adicionar o seu e-mail no git ou habilitar o VSCode no seu usuário.

---

## 3. Fluxo de Trabalho (Workflow)

### Como ativar uma feature nova:
1.  Verifique se a feature existe no **Upstream** (`/etc/kryonix/features`).
2.  Habilite-a no seu **Host** ou **User** no **Downstream** (`/etc/kryonixos`).
3.  Rode o switch:
    ```bash
    kryonix switch all
    ```

### Como atualizar o Motor:
Se você (ou uma IA) fez uma melhoria no `/etc/kryonix`, você precisa atualizar o "ponteiro" no seu repositório pessoal:
```bash
cd /etc/kryonixos
nix flake update kryonix
kryonix switch all
```

---

## 4. Guia Rápido de Diretórios

| Recurso | Localização Recomendada | Comando de Edição |
| :--- | :--- | :--- |
| **Driver de Vídeo** | `/etc/kryonixos/hosts/<host>/` | Foco em Hardware |
| **Alias de Terminal** | `/etc/kryonixos/users/<user>/` | Foco em Preferência |
| **Novo Perfil de Linguagem** | `/etc/kryonix/profiles/` | Foco em Reuso |
| **Segredos/Tokens** | `/etc/kryonixos/` (Downstream) | **NUNCA** no Upstream |

---

## 5. Instruções para IAs (Claude/Gemini)
Sempre que iniciar uma tarefa, a IA deve ler o `CONTRIBUTING_AGENTS.md` presente na raiz de ambos os repositórios. Isso garante que o assistente não tente instalar um driver de rede (Hardware) dentro de um perfil de desenvolvimento (Software).

---

**Status da Arquitetura:** ✅ Validada e Sincronizada (31/05/2026)
