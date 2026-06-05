# Manual de Operações Kryonix

Este guia descreve as operações do dia a dia no ecossistema Kryonix.

## Ferramenta Oficial: Kryonix CLI

O `kryonix-cli` (`packages/kryonix-cli`) é a interface central para interagir com o sistema.

### Build e Deploy

- `kryonix status` - Diagnóstico rápido de sistema e dual-flake.
- `kryonix build <host>` - Roda `nixos-rebuild build` na máquina atual apontando para o flake correto.
- `kryonix switch <host>` - Aplica a configuração no sistema.
- `kryonix test <host>` - Aplica a configuração temporariamente, não sobrevive a boot.
- `kryonix update` - Atualiza as referências do flake (`flake.lock`).

*Nota:* Ao trabalhar em um host real (downstream), a CLI resolve automaticamente o caminho do flake a partir de `/etc/kryonixos` ou do diretório corrente.

## Validações de Sistema (Engine)

Antes de aprovar mudanças no Motor (upstream `/etc/kryonix`), execute a validação estática:

```bash
cd /etc/kryonix
nix flake check --keep-going
```

Isto garante que as definições Nix estão válidas e que nenhum derivation quebrou de forma fatal.

## Manutenção do Brain (Ollama e LightRAG)

O serviço do Ollama no servidor Glacier não fica ativo perpetuamente. Para economizar VRAM, ele possui tempo limite e desliga quando ocioso (`keepAlive=0`).

Para debugar a infra de IA:

- Checar logs: `journalctl -u kryonix-brain-api.service -f`
- Parar o motor: `systemctl stop kryonix-brain-api.service`

A pasta de estado da inteligência artificial fica em `/var/lib/kryonix/brain/`.
