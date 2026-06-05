# Integração Contínua e Cachix

O repositório Kryonix utiliza o GitHub Actions para validações e o serviço Cachix como cache de pacotes binários, acelerando massivamente o tempo de build das máquinas reais.

## Arquitetura de Pipelines (`.github/workflows/`)

O repositório do Engine contém múltiplos fluxos de CI:

### 1. CI Básico (`ci.yml`)
Roda em Pull Requests e commits na branch `main`.
- **Validação Nix:** Roda `nix flake check` e garante que nada no motor esteja quebrado. Faz build do CLI.
- **Checagem de Shell:** Valida scripts Bash.
- **Análise Python:** Roda linting no pacote Python do `kryonix-brain-lightrag`.
- **Gitleaks:** Escaneia ativamente o código buscando possíveis vazamentos de secrets (chaves de API, senhas).

### 2. Build and Cache (`build.yml`)
Responsável por popular o Cachix com os binários compilados.
- Cria os artefatos pesados do projeto (Kryonix CLI, Installer, Kernel Zen custom, etc).
- Envia as derivações (`push`) para `kryonix.cachix.org`.
- Os hosts reais consomem esse cache, o que previne recompilação excessiva nos laptops ou no servidor Glacier.

### 3. FlakeHub (`flakehub-publish-tagged.yml`)
Publica as releases marcadas com tag no FlakeHub da organização `RAGton/kryonix`, facilitando o consumo do engine por downstream remotos.

## Secret e Permissões

- `CACHIX_AUTH_TOKEN`: Necessário no repositório GitHub para fazer push para o bucket Cachix. Nunca inclua no código.

## Como utilizar o Cachix localmente

Ao instanciar um servidor ou estação usando a arquitetura downstream, o cache é ativado por padrão caso o módulo nix correspondente esteja incluído.
Para forçar a busca de um pacote via cachix em debug manual:

```bash
nix run --extra-substituters https://kryonix.cachix.org --extra-trusted-public-keys ...
```
