# Estratégia: Desenvolvimento do Instalador Kryonix/RagOS

> Ordem de execução dos prompts. Cada fase entrega algo testável.
> Repo: https://github.com/RAGEnterprise/ragos-installer

---

## Ordem recomendada

```
PROMPT_01 → Cage/Kiosk    (ISO mostra UI)
PROMPT_05 → Hardware Probe (dados reais)
PROMPT_03 → Backend Axum  (API completa)
PROMPT_02 → Frontend Web  (UI step-by-step)
PROMPT_04 → Executor      (instalação real — LAST)
```

## Por que essa ordem

1. **Kiosk primeiro** — sem UI gráfica, nada do resto importa
2. **Probe segundo** — o frontend depende dos dados de hardware
3. **Backend terceiro** — o frontend consome a API
4. **Frontend quarto** — depende de probe + backend funcionando
5. **Executor por último** — só quando tudo acima estiver testado em VM

## Uma fase por conversa com o agente

```
"Execute APENAS o PROMPT_01 (Kiosk).
 Pare após o commit. Não avance para outro prompt."
```

## Validação final da ISO

```bash
# Build
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  -o /tmp/result-iso

# Teste em VM (não em hardware real ainda)
qemu-system-x86_64 -m 4096 -cpu host -enable-kvm \
  -vga virtio -display gtk \
  -drive file=/tmp/test-disk.qcow2,format=qcow2 \
  -cdrom /tmp/result-iso/iso/*.iso -boot d

# Checklist
[ ] Cage sobe automaticamente (sem login manual)
[ ] Chromium abre no instalador
[ ] Hardware detectado corretamente
[ ] Steps funcionam
[ ] dry-run passa
[ ] (Fase 2) install funciona em VM com disco vazio
```

## Regras gerais

1. Nunca executar install em hardware real antes de 3 VMs de teste
2. Safety checks são inegociáveis
3. Backend sempre em 127.0.0.1
4. Chromium sem acesso à internet
5. `cargo test` antes de cada commit Rust
6. ISO testada em VM antes de hardware
