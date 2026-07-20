# Arquitetura do Instalador Kryonix

O instalador do Kryonix segue uma arquitetura cliente-servidor para garantir desacoplamento, segurança e facilidade de manutenção.

## Componentes

1.  **Hardware Probe (`kryonix-hardware-probe`)**
    *   Escrito em Rust.
    *   Responsabilidade: Detectar o hardware real e retornar um JSON padronizado.
    *   Independente de privilégios elevados sempre que possível.

2.  **Disk Planner (`kryonix-disk-planner`)**
    *   Escrito em Rust.
    *   Responsabilidade: Receber o relatório de hardware e as preferências do usuário para gerar um `install-plan.json`.
    *   Não executa alterações no disco.

3.  **Installer Backend (`kryxd`)**
    *   Escrito em Rust (Axum).
    *   Responsabilidade: API REST que orquestra o probe, o planner e o executor.
    *   Expõe endpoints para a UI (Web ou TUI).

4.  **Executor (Fase 2)**
    *   Responsabilidade: Ler o `install-plan.json` e invocar as ferramentas do NixOS (`disko`, `nixos-install`) de forma controlada.

## Fluxo de Instalação

1.  O usuário inicia a ISO.
2.  A CLI `kryonix install` inicia o servidor backend.
3.  A UI consulta `/probe` para mostrar o hardware detectado.
4.  O usuário escolhe o disco e configurações.
5.  A UI envia para `/plan` que retorna o `install-plan.json`.
6.  O usuário revisa o plano.
7.  (Fase 1) O usuário roda `/dry-run` para validar.
8.  (Fase 2) O usuário confirma e o executor aplica as mudanças.
