# Kryonix Installer — Kit Completo de Refinamento e Teste

**Status**: Kiosk não funciona, web installer precisa ser página fixa operacional.  
**Objetivo**: Diagnóstico, fix iterativo, e validação em VM até DoD (Definition of Done).

---

## 📦 Conteúdo do Kit

```
kryonix-installer-kit/
├── CLAUDE.md                      # Memória do projeto (contrato de sucesso)
├── AGENTS.md                      # Contrato cross-tool
├── README.md                      # Este arquivo
├── .claude/
│   ├── settings.json              # Permissões (allow/ask/deny)
│   ├── rules/installer.md         # Regras de código pra installer
│   ├── skills/
│   │   ├── installer-diagnose/    # Diagnóstico completo (backend, frontend, kiosk)
│   │   ├── installer-backend-test/  # Testa e itera backend Axum
│   │   ├── installer-frontend-test/ # Testa e itera frontend Vite
│   │   └── installer-vm-test/       # Testa em VM (VirtualBox)
│   ├── agents/
│   │   ├── installer-reviewer.md    # Revisor especialista (Opus)
│   │   └── installer-test-runner.md # Executor de testes (Haiku)
│   └── commands/
│       ├── diagnose.md            # /diagnose → dispara diagnóstico
│       ├── fix.md                 # /fix [backend|frontend|kiosk]
│       └── test-vm.md             # /test-vm → guia VirtualBox
├── specs/
│   ├── 00-diagnostico.md          # Spec 0: verificar cada componente
│   ├── 01-fix-backend.md          # Spec 1: corrigir backend Axum
│   ├── 02-fix-frontend.md         # Spec 2: corrigir frontend Vite
│   ├── 03-fix-kiosk.md            # Spec 3: corrigir kiosk systemd
│   └── 04-vm-test.md              # Spec 4: teste em VM
└── vm-setup/
    ├── SETUP_VIRTUALBOX.md        # Passo-a-passo: build ISO → VM → test
    └── CHECKLIST_FINAL.md         # DoD (o que significa "pronto")
```

---

## 🚀 Como Usar Este Kit

### Fase 0 — Instalação do Kit no Repo

```bash
# No seu repo /etc/kryonix (ou ~/kryonix):
unzip -o kryonix-installer-kit.zip
cd /etc/kryonix

# Agora você tem:
# - CLAUDE.md atualizado (memória do instalador)
# - .claude/skills/, agents/, commands/ (prontos pra Claude Code)
# - specs/ com guias passo-a-passo
# - vm-setup/ com instruções de VirtualBox

git add CLAUDE.md AGENTS.md .claude/ specs/ vm-setup/
git commit -m "kit(installer): diagnóstico + fix iterativo + VM test (Kiosk recovery)"
```

### Fase 1 — Diagnóstico (Em Claude Code)

```
/diagnose all
```

Ou se quiser um componente específico:
```
/diagnose backend
/diagnose frontend
/diagnose kiosk
```

**O quê esperar**: Claude roda cada teste, retorna uma tabela com Status/Erro/Sugestão. Ele aponta qual é o bloqueador crítico.

### Fase 2 — Fix Iterativo (Você + Claude)

Baseado no diagnóstico, escolha a spec:

**Se backend tem erro:**
```
/fix backend
```
Claude lê `specs/01-fix-backend.md`, identifica o erro, propõe fix, valida com `cargo build`.

**Se frontend tem erro:**
```
/fix frontend
```
Claude lê `specs/02-fix-frontend.md`, propõe fix, valida com `npm run build`.

**Se kiosk tem erro:**
```
/fix kiosk
```
Claude lê `specs/03-fix-kiosk.md`, ajusta systemd/launch.sh, valida.

**Ciclo**: fix → test → commit se OK → próximo erro → repeat.

### Fase 3 — Teste em VM (Você Manual + Claude Guia)

Quando backend + frontend + kiosk parecem OK:

```
/test-vm
```

Claude vai guiar você por:
1. Build da ISO (`nix build .#...iso...`).
2. Setup VM em VirtualBox (2GB RAM, 25GB disco).
3. Boot da ISO, teste interativo (clique em formulários, navegue).
4. Coleta de logs (`journalctl -u kryonix-installer-*.service`).
5. Rollback se quebrou (`git revert`, rebuild, retest).

**Manual**: você controla a VM (cliques, navegação). Claude interpreta logs e orienta.

### Fase 4 — DoD (Definition of Done)

Confira `vm-setup/CHECKLIST_FINAL.md`. Quando TODOS os itens estão ✓:
- Kiosk roda sem erro.
- Web renderiza, formulários funcionam.
- Backend recebe dados, responde 200.
- Instalação completa → NixOS bootável.

→ **Installer PRONTO**. Próximo: Fase 5 (Distro Consumidor).

---

## 🔧 Estrutura de Trabalho (Recomendada)

```
Terminal 1: Seu IDE (editar código)
Terminal 2: Claude Code (`/diagnose`, `/fix`, `/test-vm`)
Terminal 3: VirtualBox (rodar VM, testar)

Workflow:
1. Terminal 2: `/diagnose backend` → vê erro
2. Terminal 1: edita código conforme diagnóstico
3. Terminal 2: `/fix backend` → Claude valida build
4. Terminal 3: `nix build .#...iso`, testa em VM
5. Se OK: `git commit -m "fix(installer): ..."`
6. Repeat até DoD
```

---

## 📋 Specs Principais

| Spec | Objetivo | Quanto? |
|---|---|---|
| `00-diagnostico.md` | Verificar cada componente (backend, frontend, kiosk) | Primeiro sempre |
| `01-fix-backend.md` | Fix backend Axum (cargo, binding, error handling) | Se backend quebrado |
| `02-fix-frontend.md` | Fix frontend Vite (npm, imports, build) | Se frontend quebrado |
| `03-fix-kiosk.md` | Fix kiosk systemd (wayland, service unit, paths) | Se kiosk quebrado |
| `04-vm-test.md` | Teste end-to-end em VM | Quando tudo parece OK |

---

## 🎯 Regras Críticas (NÃO viole)

1. **Diagnóstico antes de fix**: não suponha o erro — rode, veja, reporte.
2. **Cada fix é pequeno**: um problema por commit. Não mexe em 3 coisas ao mesmo tempo.
3. **Teste em VM obrigatório**: código que compila não significa que funciona. VM testa de verdade.
4. **Nenhum secret no binário**: `brain.env` é RUNTIME ENV VAR, nunca baked no nix store.
5. **Rollback sempre disponível**: cada commit é revertível via `git revert`. ISO velha fica guardada pra rollback rápido.

---

## 🚨 Troubleshooting Rápido

| Problema | Ação |
|---|---|
| `cargo: command not found` | Você está em `/etc/kryonix`? Rodou `nix flake update`? |
| `npm: command not found` | Mesmo — verifique estar no repo e `nix flake` sincronizado. |
| `kiosk não lança em VM` | Veja `journalctl -u kryonix-installer-kiosk.service` dentro da VM (SSH ou terminal). |
| `port 8080 refused` | Backend não está rodando. Cheque `cargo build --release` de novo. |
| `ISO muito grande` | Normal (~600MB). Verifique espaço em disco (25GB+ livre). |
| Tudo quebrou | `git revert HEAD --no-edit`, rebuild ISO, retest. Volta ao estado anterior. |

---

## 📞 Perguntas Frequentes

**P: Por quanto tempo isso vai levar?**  
R: Diagnóstico (~5min), cada fix (~10-30min), teste VM (~10min). Total: 1-3h dependendo de quantos bugs.

**P: Posso editar código enquanto Claude Code roda?**  
R: Sim, em outro terminal. Claude detecta mudanças e relê na próxima rodada.

**P: O que fazer se VM travou?**  
R: Force-kill em VirtualBox (máquina → fechar → descartar estado salvo), reboot VM, tenta de novo.

**P: Quando push no git?**  
R: Só depois que teste em VM passou. Não empurra código quebrado — vai triggar CI que falha.

---

## ✅ Checklist de Entrega

- [x] CLAUDE.md com memória do projeto
- [x] 4 specs (diagnóstico, 3 fixes, teste VM)
- [x] 4 skills (diagnose, backend-test, frontend-test, vm-test)
- [x] 2 subagents (reviewer Opus, test-runner Haiku)
- [x] 3 commands (/diagnose, /fix, /test-vm)
- [x] Regras de código (.claude/rules/installer.md)
- [x] VM setup guide (VirtualBox step-by-step)
- [x] DoD checklist (quando parar de iterar)

---

## 🎬 Começar Agora

1. Descompacte o ZIP em `/etc/kryonix`.
2. Rode em Claude Code: `/diagnose all`.
3. Leia a saída, veja qual componente quebra primeiro.
4. Rode `/fix [componente]`.
5. Edita código conforme Claude sugere.
6. Repeat até tudo verde.
7. Teste em VM com `/test-vm`.
8. DoD checklist ✓ → installer pronto!

**Bom trabalho! 🚀**
