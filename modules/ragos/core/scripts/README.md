# Scripts do Repositorio

Os scripts agora ficam separados por intencao operacional para reduzir ambiguidade e evitar que automacao de laboratorio pareca fluxo suportado.

## Categorias

- `dev/`: automacoes reproduziveis para laboratorios auxiliares de desenvolvimento
- `ops/`: scripts suportados para operacao e manutencao controlada
- `tests/`: harnesses reproduziveis de validacao, smoke e regressao
- `lab/`: automacao de Hyper-V, QEMU, WSL, serial e outros fluxos experimentais

## Scripts de desenvolvimento

Tudo em `dev/` continua auxiliar ao fluxo principal do projeto, mas ja deve nascer parametrizavel, auditavel e committavel. Use esta categoria para laboratorios de desenvolvimento que precisem ser reproduzidos por outros mantenedores sem carregar caminhos pessoais ou topologias improvisadas.

## Suportados para operacao

- `ops/migrate-ragos-inventory.sh`
  Bootstrap idempotente do inventario externo em `/etc/ragos-inventory`.

## Scripts de teste

- `tests/test-clients-inventory-validation.sh`
  Valida a biblioteca de inventario fora do host de producao.
- `tests/test-ragc-phaseA.sh`
  Exercita o fluxo principal do `ragc` em ambiente temporario.
- `tests/test-doctor-phase2-wsl.sh`
  Harness reproduzivel para checagens do `doctor` em ambiente controlado.
- `tests/test-phase2-wsl.sh`
  Harness de regressao para fluxos de GC/publicacao em ambiente controlado.
- `tests/test-brandlab-contract.sh`
  Garante que o BrandLab continue coerente entre wiring real, baseline e docs.
- `tests/test-day0-contract.sh`
  Consolida o contrato Day-0 entre instalador, first publish, inventario, ragc e documentacao canonica.
- `tests/test-server-access-contract.sh`
  Garante que o `srv-rag` mantenha SSH como acesso primario com fallback local em `tty1` e fallback serial em consoles suportados.
- `tests/test-client-lab-serial-contract.sh`
  Garante que o `desktop-lab` preserve `tty1` e exponha `ttyS0` como fallback serial de prova no lab libvirt.
- `tests/lint-repo-organization.sh`
  Valida convencoes de estrutura, cabecalhos, referencias antigas e artefatos do repositorio.

## Scripts de laboratorio

Tudo em `lab/` e explicitamente nao canonico. Esses scripts podem conter caminhos pessoais, nomes fixos de VM, topologias locais ou outras suposicoes adequadas apenas para experimentacao.

Mesmo assim, o harness abaixo e hoje a prova destrutiva canonica da reinstalacao limpa em laboratorio:

- `lab/validate-srv-rag-libvirt.sh`
  Reinstala o `srv-rag`, prova o primeiro boot em disco e valida o caminho Day-0 ate publish e boot de cliente.

Entradas relevantes para o BrandLab:

- `lab/branding/generate-branding-manifest.sh`
  Gera um manifest deterministico da superficie visual implementada no checkout.
- `lab/branding/render-branding-review.sh`
  Gera checklist objetivo para revisao visual sem fingir prova por screenshot.
- `lab/branding/capture-plasma.sh`
  Captura a tela atual do dominio quando o desktop estiver realmente exibido.
- `lab/branding/capture-sddm.sh`
  Captura a tela atual do dominio quando o greeter estiver ativo.
- `lab/branding/capture-plymouth.sh`
  Captura uma janela de boot do dominio para prova real do Plymouth.
- `lab/branding/capture-branding-e2e.sh`
  Executa o fluxo controlado de prova visual fim a fim: Plymouth, SDDM, login e Plasma autenticado.
- `lab/branding/compare-branding-baseline.sh`
  Consolida baseline, runtime doctor e capturas em um report comparativo.
- `lab/branding/set-plasma-variant.sh`
  Solicita via console serial a variante dark/light a ser aplicada na proxima sessao grafica.
- `lab/branding/prove-plasma-theme.sh`
  Coleta prova serial do Look and Feel, Plasma Style e Color Scheme ativos no cliente publicado.

## Regras de manutencao

- Scripts em `dev/` devem ser idempotentes ou explicitamente reexecutaveis, com defaults seguros e dependencia de host declarada.
- Scripts em `ops/` devem ser idempotentes, parametrizaveis e seguros para uso repetido.
- Scripts em `tests/` devem ser reproduziveis e ter escopo claro de validacao.
- Scripts em `lab/` devem declarar variaveis esperadas no cabecalho quando dependerem de ambiente local.
- Nada em `scripts/` substitui `ragos`, `ragc`, `ragos-inventory-apply` ou os modulos NixOS como fonte de verdade operacional.
