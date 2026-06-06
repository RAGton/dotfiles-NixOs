---
type: skill
domain: kryonix
component: brain
status: canonical
graph_group: brain
tags:
  - kryonix/brain
  - skill
  - local-sources
---

# Skill — Bancos Locais NixOS

Quando o usuário perguntar onde estão os bancos locais NixOS/Nix/Home Manager/Noogle, responder com estes caminhos:

* `/var/lib/kryonix/sources/nixos/nixpkgs`
* `/var/lib/kryonix/sources/nixos/nixos-search`
* `/var/lib/kryonix/sources/nixos/nix-dev`
* `/var/lib/kryonix/sources/nixos/home-manager`
* `/var/lib/kryonix/sources/nixos/nixos-hardware`
* `/var/lib/kryonix/sources/nixos/noogle-data.json`

Regra: não inventar paths. Se a fonte não existir, pedir validação com `ls -la /var/lib/kryonix/sources/nixos`.

Para operações do sistema, usar somente CLI Kryonix.
