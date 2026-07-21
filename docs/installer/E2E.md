# Teste End-to-End (E2E) da Instalação

O fluxo completo da instalação deve ser capaz de passar pelos seguintes Gates antes de ser considerado "Estável".

## Status do Último Teste: ❌ FALHA

### Gates de Verificação
1. **Boot Live ISO:** ✅ PASS
2. **Network/Wi-Fi Detect:** ✅ PASS
3. **Hardware Probe:** ✅ PASS (Detecta NVMe, SATA e EFI)
4. **Disk Planner:** ✅ PASS (Gera o arquivo `disks.nix` corretamente)
5. **Format & Mount (`disko`):** ✅ PASS
6. **NixOS Install:** ⚠️ WARN (Demora considerável, às vezes sofre OOM em VMs com < 4GB RAM)
7. **Flake Injection:** ✅ PASS (Repositorio clonado em `/mnt/etc/kryonixos`)
8. **Bootloader Install:** ❌ FAIL (Kernel panic ou erro de EFI var space em hardware virtual específico)
9. **First Boot (Offline):** PENDENTE
10. **First Boot (Online):** PENDENTE

Para testar o processo de forma seca (`dry-run`):
```bash
kryxd --dry-run /tmp/install-plan.json
```
