---
type: skill
domain: nixos
component: operations
status: canonical
graph_group: nixos
tags:
  - nixos
  - operations
  - skill
---

# Rebuild NixOS Command Skill

O caminho correto em sistemas Kryonix (como o Glacier) para reconstrução é usar a CLI Kryonix.

```bash
kryonix check --host <host>
kryonix rebuild --host <host>
kryonix test --host <host>
kryonix switch --host <host>
```

Sem ISO, sem disko, sem scripts ./run.sh manuais.
