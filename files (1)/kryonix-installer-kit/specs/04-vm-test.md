# Spec 04 — Teste em VM (VirtualBox)

Validação final de todo o stack.

## Setup VM
1. Buildar ISO: `nix build .#nixosConfigurations.iso.config.system.build.isoImage -L`.
2. Copiar ISO pra VirtualBox: `cp result/iso/*.iso ~/Downloads/kryonix-test.iso`.
3. Criar VM: 2GB RAM, 20GB disco, boot da ISO.
4. Iniciar VM, deixar o instalador rodar.

## Testes em VM
- [ ] Kiosk lança na boot (interface web visível em fullscreen).
- [ ] Web renderiza (forma, inputs, botões).
- [ ] Clique em "Próximo" → navegação funciona.
- [ ] Backend recebe POST (journalctl mostra requisições).
- [ ] Estado persiste (voltar e revisar OK).
- [ ] Instalação completa → NixOS roda.

## Rollback se quebrou
```bash
git revert HEAD --no-edit
nix build .#nixosConfigurations.iso... -L
# Testa ISO nova na VM
```
