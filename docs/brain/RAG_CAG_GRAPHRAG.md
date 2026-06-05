# Modos de Recuperação (RAG, CAG, GraphRAG)

O pacote `kryonix-brain-lightrag` suporta três paradigmas distintos de recuperação de informação, dependendo da necessidade de precisão versus criatividade.

## 1. RAG (Retrieval-Augmented Generation)
O modo padrão e mais estável.
- Usa o LightRAG base em conjunto com o `nano-vectordb` para buscar similaridade vetorial (Cosine Similarity).
- **Quando usar:** Buscas gerais de código, procura por exceções em logs e documentação básica.

## 2. CAG (Cache-Augmented Generation)
Um modo otimizado introduzido nas versões recentes do Kryonix.
- Em vez de buscar por vetorização distante a cada query, mantém um pre-cache dos grafos ou sumários frequentes na memória RAM.
- **Vantagem:** Latência quase zero para recuperação da parte não-LLM, respondendo imediatamente se a inferência for trivial.

## 3. GraphRAG (Graph-based Retrieval)
A evolução semântica profunda do Brain.
- Ao invés de buscar fragmentos avulsos de texto, caminha pelos relacionamentos semânticos injetados no [Neo4j](NEO4J.md).
- **Quando usar:** Para responder a perguntas como *"Quais módulos dependem da feature de IA mas não estão no host Inspiron?"* (Questões que exigem navegação de propriedades e relações lógicas, não apenas palavra-chave).
- **Status:** Implementação parcial. O backend Python extrai corretamente, mas a injeção via Agentes ainda está no Roadmap.
