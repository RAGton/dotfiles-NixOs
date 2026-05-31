# Kryonix Contribution Guidelines

Obrigado por seu interesse em contribuir com o Kryonix! Como uma plataforma de alto desempenho e focada em reprodutibilidade, mantemos padrões rigorosos de engenharia.

## 🛠️ Ambiente de Desenvolvimento

Recomendamos o uso de `direnv` com Nix para garantir que o seu shell de desenvolvimento contenha todas as ferramentas necessárias (Rust, Nix, QEMU, etc).

```bash
nix profile install nixpkgs#direnv
direnv allow .
```

## 🧪 Validando Mudanças na ISO

Antes de submeter qualquer Pull Request que altere o instalador ou a configuração da ISO, você **DEVE** rodar o teste de boot automatizado.

```bash
# 1. Build da ISO
kryonix build iso

# 2. Executar teste de boot em VM
./scripts/test-iso-boot.sh
```

O script validará se a ISO dá boot em modo UEFI e se a API do instalador está respondendo corretamente.

## ✅ Checklist de Pull Request

1.  **Flake Check**: Execute `nix flake check` para garantir que não há erros de sintaxe ou referências quebradas.
2.  **Linting**: Para mudanças em Rust, garanta que `cargo fmt` e `cargo clippy` passem sem avisos.
3.  **Documentação**: Se adicionar uma nova funcionalidade, atualize o `README.md` ou crie uma spec em `docs/specs/`.
4.  **Verdade Operacional**: Mudanças que afetam o particionamento ou boot devem ser testadas fisicamente ou via VM.

## 🤝 Processo de Revisão

- Pull Requests são revisados pela equipe core.
- Focamos em: Segurança de dados, performance e simplicidade declarativa.
- Evite adicionar dependências pesadas sem uma justificativa técnica sólida.

---
*A qualidade do Kryonix depende da precisão de cada commit.*
