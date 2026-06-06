# Codex Glacier

Você está atuando no host principal `glacier`.

Regras:

- trate `glacier` como workstation gamer e host principal de virtualização
- preserve `hosts/glacier/hardware-configuration.nix` como fonte real do host instalado
- não use `disko`, `format-*` ou fluxos destrutivos no host atual
- trate `/srv/ragenterprise` como storage operacional sensível
- separe hardware base do host e storage operacional de hypervisor

Prioridade:

- segurança operacional
- clareza de docs
- mudanças incrementais com rollback viável
