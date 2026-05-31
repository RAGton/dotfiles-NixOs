---
name: llm-engineering
description: Engenharia com LLMs — design de prompts, RAG, agentes, fine-tuning, APIs (OpenAI, Anthropic, Ollama, LiteLLM), avaliação de modelos, embeddings, vector databases, chains, orquestração com LangChain/LlamaIndex/DSPy e deployment de aplicações com IA. Use sempre que o usuário mencionar LLM, GPT, Claude API, Ollama, RAG, embeddings, vector store, agente de IA, prompt engineering, fine-tuning, langchain, llamaindex, ou qualquer desenvolvimento de aplicação baseada em modelos de linguagem.
---

# LLM Engineering

## Hierarquia de decisão

```
Problema → Escolha de abordagem:
  Simples/pontual     → Prompt direto via API
  Precisa de contexto → RAG + retrieval
  Processo complexo   → Agente com ferramentas
  Domínio específico  → Fine-tuning
  Multi-modelo        → LiteLLM / gateway
```

## APIs essenciais

### Anthropic (Claude)
```python
import anthropic

client = anthropic.Anthropic()  # usa ANTHROPIC_API_KEY

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="Você é um assistente técnico.",
    messages=[{"role": "user", "content": "Explique RAG"}]
)
print(response.content[0].text)
```

### OpenAI
```python
from openai import OpenAI
client = OpenAI()  # usa OPENAI_API_KEY

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Explique RAG"}]
)
```

### Ollama (local)
```python
import ollama
response = ollama.chat(
    model='llama3.2',
    messages=[{'role': 'user', 'content': 'Explique RAG'}]
)
```

### LiteLLM (gateway unificado)
```python
from litellm import completion
# Troca provider só mudando model string
response = completion(
    model="anthropic/claude-sonnet-4-6",  # ou "openai/gpt-4o", "ollama/llama3"
    messages=[{"role": "user", "content": "Olá"}]
)
```

## RAG — padrão completo

```python
# 1. Indexação
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)
chunks = splitter.split_documents(docs)
vectorstore = Chroma.from_documents(chunks, OpenAIEmbeddings())

# 2. Retrieval + Generation
retriever = vectorstore.as_retriever(search_kwargs={"k": 5})
context_docs = retriever.invoke(query)
context = "\n\n".join(d.page_content for d in context_docs)

prompt = f"""Use apenas o contexto abaixo para responder.
Contexto: {context}
Pergunta: {query}"""
```

## Prompt Engineering — padrões

### System prompt estruturado
```
Você é [papel]. Seu objetivo é [objetivo].
Restrições: [lista]
Formato de saída: [especificação]
```

### Chain-of-Thought
```
Antes de responder, raciocine passo a passo entre <thinking></thinking>.
Depois dê a resposta final entre <answer></answer>.
```

### Few-shot
```
Exemplos:
Input: X → Output: A
Input: Y → Output: B
Input: Z → Output: ?
```

## Avaliação de LLMs

```python
# LLM-as-judge
def avaliar(pergunta, resposta, gabarito):
    prompt = f"""
    Pergunta: {pergunta}
    Resposta do modelo: {resposta}
    Gabarito: {gabarito}
    Avalie de 1-5 e explique. Responda em JSON: {{"score": N, "reason": "..."}}
    """
    return client.messages.create(model="claude-sonnet-4-6", ...)
```

## Streaming

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

## Referências adicionais
- **Agentes e ferramentas (tool use)**: ver [references/agents-tools.md](references/agents-tools.md)
- **Fine-tuning**: ver [references/fine-tuning.md](references/fine-tuning.md)
- **Vector databases (Chroma, Qdrant, Pinecone)**: ver [references/vector-dbs.md](references/vector-dbs.md)
- **Deployment (FastAPI + LLM)**: ver [references/deployment.md](references/deployment.md)
