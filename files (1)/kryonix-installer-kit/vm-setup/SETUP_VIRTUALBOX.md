# Setup VM para Testar Kryonix Installer

Guia passo-a-passo pra testar o instalador em VirtualBox.

## Pré-requisitos
- VirtualBox instalado (6.1+).
- ISO do Kryonix buildada: `nix build .#nixosConfigurations.iso.config.system.build.isoImage -L`.
- ~2GB RAM livre, ~25GB disco livre.

## Passo 1 — Buildar a ISO

```bash
cd /etc/kryonix  # ou ~/kryonix (seu flake)
nix build .#nixosConfigurations.iso.config.system.build.isoImage -L
# Isso leva 5–15min (mais rápido se usar cachix).
# Resultado: ./result/iso/*.iso (~600MB)

# Copiar ISO pra um lugar acessível
cp result/iso/*.iso ~/kryonix-test.iso
ls -lah ~/kryonix-test.iso
```

## Passo 2 — Criar VM em VirtualBox

1. Abrir **VirtualBox**.
2. Clique em "Máquinas Novas" (Ctrl+N).
3. **Nome**: `kryonix-installer-test`.
4. **Tipo**: Linux.
5. **Versão**: Other Linux (64-bit).
6. **RAM**: 2048 MB (pode ser menos, mas 2GB é seguro).
7. **Disco**: Criar novo VDI, 25GB dinâmico.
8. Finalizar.

## Passo 3 — Configurar Boot da ISO

1. Na VM, clique em **Configurações** (Ctrl+S).
2. Vá em **Armazenamento**.
3. Em "Controlador SATA", clique em **Vazio** (ícone de disco vazio).
4. À direita, clique no ícone de pasta → escolha `~/kryonix-test.iso`.
5. OK.

## Passo 4 — Boot e Teste

1. Clique em **Iniciar** (Ctrl+I) na VM.
2. Deixe o kernel boot (5–10s).
3. Quando pronto, você verá:
   - **Se OK**: interface web do instalador em fullscreen (formulários, buttons).
   - **Se ERRO**: tela preta, ou texto "failed to start kiosk.service" (pressione Alt+Right pra ver logs).

## Passo 5 — Diagnóstico em VM

Se tudo preto ou erro, SSH na VM e inspecione:

```bash
# Dentro da VM ou via SSH:
systemctl status kryonix-installer-kiosk.service
journalctl -u kryonix-installer-*.service -n 50

# Test se backend está rodando:
curl http://localhost:8080/api/health

# Ver processos:
ps aux | grep -E "kiosk|installer|axum"
```

## Passo 6 — Interagir com Instalador (se OK)

1. Preencher formulário (hostname, usuário, disco).
2. Clicar "Próximo" → backend recebe POST, frontend navega.
3. Completar instalação.
4. VM rebooteia e entra no NixOS instalado.

## Passo 7 — Logs para Diagnóstico

Capture para diagnosticar problemas:

```bash
# No seu host (fora VM), se VM tem SSH:
ssh -p 2222 root@localhost "journalctl -u kryonix-installer-*.service" > vm-logs.txt

# Ou dentro da VM:
journalctl -u kryonix-installer-*.service --no-pager > /tmp/logs.txt
# Depois copie /tmp/logs.txt pra seu host.
```

## Passo 8 — Rollback (se quebrou)

```bash
# No seu host:
git revert HEAD --no-edit
nix build .#nixosConfigurations.iso.config.system.build.isoImage -L
cp result/iso/*.iso ~/kryonix-test-v2.iso

# Em VirtualBox: Armazenamento → trocar ISO pela nova.
# Boot novamente.
```

## Dicas

- **VirtualBox lento**: aumentar CPU/RAM em Configurações (até o limite do seu host).
- **QEMU alternative**: se preferir: `nix run nixpkgs#qemu -- -m 2G -cdrom ~/kryonix-test.iso -hda /tmp/kryonix-test.qcow2`.
- **Snapshot**: em VirtualBox, antes de testar, crie snapshot (Ctrl+Shift+S) — permite reverter rápido sem rebuild.

## Sequência Recomendada

1. Diagnóstico (spec-00): rode no seu host, veja o que quebra.
2. Fix (spec-01, 02, 03): edita código conforme diagnóstico.
3. Test (spec-04): builda ISO, cria VM, testa.
4. Commit se OK, rollback se não.
5. Iterar até DoD (ver CLAUDE.md "Contrato de Sucesso").
