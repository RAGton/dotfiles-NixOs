---
source: docs/brain/lightrag.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# LightRAG

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

O Kryonix utiliza o **LightRAG** como seu sistema primário de recuperação de informações baseadas em grafos.

## Fonte de Verdade
- **Status:** **VALIDATED** (Passou nos testes de CLI)
- **Serviço:** N/A (Execução via CLI / binário local atrelado aos pacotes Python no momento)
- **Porta:** N/A
- **Comando:** `kryonix graph stats --local`
- **Validação:** O diretório de storage em disco configurado localmente.

## Responsabilidades
- **Onde Roda:** Servidor `glacier` ou invocado localmente por ferramentas de auditoria.
- **Armazenamento:** `rag_storage` central.

> [!WARNING]
> O LightRAG em formato de API daemon server está desativado (Veja ROADMAP.md). Qualquer requisição remota dependente da porta 8000 no `inspiron` está atualmente desabilitada do runtime default até futura aprovação.

## Operações no Grafo

Para uso estrito via CLI (no host rodando a operação de fato):
```sh
kryonix graph stats --local
kryonix graph top --local --limit 10
kryonix graph heal --local
kryonix graph repair --local
```
