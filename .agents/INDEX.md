# Kryonix Agent Index

> **Equipe de agentes Kora/Antigravity aposentada.** A Kora foi removida (ver
> `docs/aura/KORA_RETIREMENT_STUDY.md`); a assistente agora é a **Aura**
> (`kryonix.services.aura` — camada `aura`, motor a definir). Os papéis `kora-*`
> e os workflows/prompts da equipe Kora foram removidos.

## Agentes ativos

| Nome do Agente | Função / Missão | Escopo de Edição | Permissões | Foco Operacional |
| :--- | :--- | :--- | :--- | :--- |
| [kryonix-nixos-integrator](file:///etc/kryonix/.agents/roles/kryonix-nixos-integrator.md) | Integração NixOS & HM Declarativa | `flake.nix`, `hosts/`, `modules/nixos/` | **Implementação** | Módulos Nix, builds, systemd system units e switch seguro |

## Como operar

1. **Intake**: determine qual componente do ecossistema Kryonix será afetado.
2. **Checklists**: rode os gates em [checklists/](file:///etc/kryonix/.agents/checklists/) antes de declarar pronto.
3. **Revisão de segurança**: [workflows/security-review.md](file:///etc/kryonix/.agents/workflows/security-review.md).
