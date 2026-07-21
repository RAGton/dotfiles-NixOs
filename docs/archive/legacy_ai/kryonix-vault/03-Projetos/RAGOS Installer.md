# NODE Installer

## Repositório

- GitHub: `RAGEnterprise/node-installer`
- Visibilidade: público
- Branch padrão: `main`
- Relação: instalador oficial do ecossistema NODE

## Descrição operacional

O NODE Installer prepara o servidor base, gera parâmetros de implantação e executa o pipeline de instalação do ambiente.

Ele concentra:

- composição da ISO de instalação;
- executor shell que prepara disco, rede e `nixos-install`;
- interface local em React;
- backend local em Rust/Axum;
- `params.nix` e contratos do pipeline.

## Arquitetura declarada

Fluxo operacional:

```txt
UI React
  -> Backend local Rust/Axum
    -> Executor shell
      -> Particionamento / montagem
        -> params.nix
          -> nixos-install
            -> sistema NODE instalado
```

## Escopo

Cobre:

- geração da mídia instalável;
- coleta e validação dos parâmetros;
- preparação de disco/filesystem;
- geração do plano aplicado ao sistema alvo;
- execução do `nixos-install`;
- integração com o repo principal NODE.

Não cobre:

- operação contínua do servidor já instalado;
- publicação de imagens de cliente;
- ciclo operacional do `knyc`;
- administração contínua do ambiente diskless.

## Contratos críticos

- `NODE_DISK_MODE = one|two`
- `NODE_SYS_DISK`
- `NODE_DATA_DISK`
- `NODE_ROOT_FS`
- `NODE_DATA_FS`

## Layouts declarados

- single disk com BTRFS;
- split disks;
- RAID explícito apenas por caminho operacional explícito;
- LUKS suportado;
- LVM não implementado ponta a ponta.

## Alerta de qualidade detectado

O README do repositório contém marcadores de conflito Git:

```txt
<<<<<<< HEAD
=======
>>>>>>> 44d53e29fecc58aec2fa94dabc7cf7e48acaf579
```

Isso significa que a documentação atual **não deve ser tratada como referência limpa até ser corrigida**.

Ação recomendada:

1. abrir issue/PR para limpar conflito;
2. revisar se o conteúdo duplicado/conflitante representa divergência real de contrato;
3. atualizar README somente com o fluxo implementado;
4. adicionar checklist CI para detectar conflict markers.

## Regras para IA/agente

Antes de alterar este repo:

1. Classificar mudança: UI, backend, shell, NixOS ou ISO.
2. Verificar contrato entre camadas.
3. Nunca alterar storage/particionamento sem plano de rollback.
4. Nunca adicionar detecção agressiva de discos.
5. Não tratar suporte parcial como suporte completo.
6. Testar UI, backend e fluxo shell quando o contrato mudar.
7. Atualizar submodule/ponteiro no repo `node` quando necessário.

## Riscos principais

- wipe de disco incorreto;
- plano de instalação inconsistente;
- UI validando algo diferente do shell;
- `params.nix` incompatível com NixOS final;
- ISO com boot frágil;
- documentação divergente do comportamento real;
- LUKS/RAID parcialmente suportados sendo vendidos como completos.

## MOCs relacionados

- [[03-Projetos/NODE]]
- [[01-MOCs/Mapa - NixOS e Infra Declarativa]]
- [[01-MOCs/Mapa - Linux e Sistemas]]
- [[01-MOCs/Mapa - Frontend Moderno]]
- [[01-MOCs/Mapa - Debug Testes e Qualidade]]
