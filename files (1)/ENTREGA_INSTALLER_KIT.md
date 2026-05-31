# 🚀 ENTREGA: Kryonix Installer Kit Completo

**Data**: 31 de Maio de 2026  
**Status**: Kit pronto para diagnóstico, fix iterativo e teste em VM  
**Arquivo**: `kryonix-installer-kit.zip` (22 KB)

---

## 📦 O Que Você Recebeu

Um kit **completo e integrado** para diagnosticar, consertar e testar o Kryonix Installer (Kiosk + Web). Inclui:

### ✅ Governança Claude Code
- **CLAUDE.md** — Memória do projeto com contrato de sucesso
- **AGENTS.md** — Regras cross-tool
- **.claude/settings.json** — Permissões (allow/ask/deny)

### ✅ 4 Skills Especializadas
1. **installer-diagnose** — Roda cada componente, retorna tabela de status
2. **installer-backend-test** — Testa e itera backend Axum
3. **installer-frontend-test** — Testa e itera frontend Vite
4. **installer-vm-test** — Coordena teste em VirtualBox

### ✅ 2 Subagents Inteligentes
- **installer-reviewer** (Opus) — Revisa código Rust/TS/systemd, detecta problemas
- **installer-test-runner** (Haiku) — Executa testes automatizados, recolhe logs

### ✅ 3 Commands Rápidos
- **/diagnose** — Dispara diagnóstico completo
- **/fix** — Abre spec de fix e implementa
- **/test-vm** — Guia passo-a-passo VirtualBox

### ✅ 4 Specs Estruturadas
| Spec | O Quê | Quando |
|---|---|---|
| **00-diagnostico.md** | Verificar backend, frontend, kiosk | Sempre primeiro |
| **01-fix-backend.md** | Corrigir Axum (cargo, binding, error) | Se backend quebrado |
| **02-fix-frontend.md** | Corrigir Vite (npm, imports, build) | Se frontend quebrado |
| **03-fix-kiosk.md** | Corrigir systemd/wayland/display | Se kiosk quebrado |
| **04-vm-test.md** | Teste end-to-end em VM | Quando tudo parece OK |

### ✅ 2 Guias Práticos
- **vm-setup/SETUP_VIRTUALBOX.md** — Passo-a-passo: build ISO → VM → teste
- **vm-setup/CHECKLIST_FINAL.md** — DoD (Definition of Done) — quando parar de iterar

### ✅ Extras
- **README.md** — Guia completo do kit
- **QUICKSTART.txt** — Quick start (1-2 páginas)
- **.claude/rules/installer.md** — Regras de código do installer

---

## 🎯 Como Começar (3 Passos Rápidos)

### Passo 1 — Descompactar e Instalar (2 min)

```bash
cd /etc/kryonix  # ou ~/kryonix se é seu flake
unzip -o ~/Downloads/kryonix-installer-kit.zip

git add CLAUDE.md AGENTS.md .claude/ specs/ vm-setup/
git commit -m "kit(installer): diagnóstico + fix iterativo"
```

### Passo 2 — Diagnosticar (5 min)

Abra Claude Code em `/etc/kryonix` e rode:

```
/diagnose all
```

Claude vai:
1. Rodar `cargo build --release` no backend.
2. Rodar `npm run build` no frontend.
3. Checar `systemctl status kryonix-installer-kiosk.service`.
4. Testar `curl http://localhost:8080/api/health`.
5. Retornar tabela com Status | Erro | Sugestão.

**Você verá qual componente está quebrado.**

### Passo 3 — Iterar (30 min a 2h)

Baseado no diagnóstico, escolha:

```
/fix backend    # se diagnóstico disse que backend quebrou
/fix frontend   # se frontend quebrou
/fix kiosk      # se kiosk quebrou
```

Claude vai:
- Ler a spec correspondente.
- Editar o código.
- Validar com build/test.
- Você revisa, aprova, commita.

**Repeat** até diagnóstico retornar tudo verde.

---

## 🧪 Teste em VM (Final)

Quando diagnóstico disser "tudo OK", rode:

```
/test-vm
```

Claude guia você por:
1. **Build ISO** — `nix build .#nixosConfigurations.iso...`
2. **Setup VM** — Cria VM em VirtualBox (2GB RAM, 25GB disco)
3. **Boot** — ISO inicia, kiosk.service lança interface web
4. **Teste** — Você clica em formulários, testa navegação
5. **Logs** — Claude lê `journalctl` e interpreta erros
6. **Rollback** — Se quebrou: `git revert`, rebuild, retest

**Quando tudo passar em VM** → Confira `vm-setup/CHECKLIST_FINAL.md` → **Installer PRONTO** 🎉

---

## 📋 Estrutura Completa

```
kryonix-installer-kit/
├── CLAUDE.md                          # Memória (contrato de sucesso)
├── AGENTS.md                          # Regras cross-tool
├── README.md                          # Guia completo
├── QUICKSTART.txt                     # Quick start
├── .claude/
│   ├── settings.json                  # Permissões
│   ├── rules/installer.md             # Regras de código
│   ├── skills/
│   │   ├── installer-diagnose/SKILL.md
│   │   ├── installer-backend-test/SKILL.md
│   │   ├── installer-frontend-test/SKILL.md
│   │   └── installer-vm-test/SKILL.md
│   ├── agents/
│   │   ├── installer-reviewer.md      # Opus reviewer
│   │   └── installer-test-runner.md   # Haiku executor
│   └── commands/
│       ├── diagnose.md
│       ├── fix.md
│       └── test-vm.md
├── specs/
│   ├── 00-diagnostico.md              # Verificar componentes
│   ├── 01-fix-backend.md              # Fix backend
│   ├── 02-fix-frontend.md             # Fix frontend
│   ├── 03-fix-kiosk.md                # Fix kiosk
│   └── 04-vm-test.md                  # Teste em VM
└── vm-setup/
    ├── SETUP_VIRTUALBOX.md            # Passo-a-passo
    └── CHECKLIST_FINAL.md             # DoD
```

---

## 🎓 Fluxo de Trabalho Recomendado

```
Terminal 1: Seu IDE/Editor
Terminal 2: Claude Code (diagnose, fix, test-vm)
Terminal 3: VirtualBox (VM)

Dia 1:
  - Descompactar kit
  - `/diagnose all` → descobre o problema
  - `/fix [componente]` → edita e valida
  - Repete até diagnóstico OK

Dia 2:
  - `/test-vm` → testa em VM de verdade
  - Clica em formulários, navega, testa end-to-end
  - Se OK: checklist final ✓
  - Se não: volta a `/diagnose`, itera

Resultado: Installer funcionando 100%
```

---

## 🚨 Regras Críticas (Não Viole!)

| Regra | Por Quê |
|---|---|
| **Diagnóstico antes de fix** | Não suponha — rode, veja, reporte o erro real |
| **Cada fix pequeno** | Um problema = um commit. Não mexe em 3 coisas. |
| **Teste em VM obrigatório** | Código que compila ≠ código que funciona. VM testa de verdade. |
| **Nenhum secret no binário** | brain.env é ENV VAR em runtime, nunca em nix store. |
| **Rollback sempre disponível** | Cada commit é revertível via `git revert HEAD --no-edit`. |

---

## ✅ Checklist de Sucesso (DoD)

Quando TODOS estes itens estão ✓, o installer está pronto:

- [ ] Backend compila (`cargo build --release` OK)
- [ ] Frontend builda (`npm run build` OK)
- [ ] ISO buildada (~600MB gerada)
- [ ] Kiosk lança em VM (interface web visível em fullscreen)
- [ ] Web renderiza (formulários, inputs, botões visíveis)
- [ ] Backend responde (curl http://localhost:8080/api/health = 200)
- [ ] Navegação funciona (clique "Próximo" muda de tela, POST registrado em logs)
- [ ] Formulário completo (preenchimento, validação, envio sem erro)
- [ ] Instalação completa (VM rebooteia, NixOS funciona)
- [ ] Logs limpos (não há "failed", "Connection refused", "file not found" em journalctl)
- [ ] Código reviewado (sem imports soltos, sem TODOs, sem hardcodes)

**Quando todos ✓ → Fase 5 (Meta-Distro Consumidor) pode começar.**

---

## 📞 FAQ Rápido

**P: Por quanto tempo?**  
A: Diagnóstico 5min, cada fix 10-30min, teste VM 20min. Total: 1-3h.

**P: Preciso de nix flake?**  
A: Sim, você já tem (você está em /etc/kryonix com flake.nix funcionando).

**P: E se tudo quebrar em VM?**  
A: `git revert HEAD --no-edit`, rebuild ISO, testa novamente. Volta ao anterior intacto.

**P: Quando devo fazer push?**  
A: Só DEPOIS que teste em VM passou. Não empurra código quebrado pro CI.

---

## 📁 Arquivo Entregue

```
/mnt/user-data/outputs/kryonix-installer-kit.zip  (22 KB)
```

**Contém**: Tudo acima. Descompacte em `/etc/kryonix`, rode `/diagnose all` em Claude Code, e comece.

---

## 🎬 Próximos Passos

1. ✅ Recebeu o kit (este arquivo).
2. 🔲 Descompacte em `/etc/kryonix`.
3. 🔲 Rode `/diagnose all` em Claude Code.
4. 🔲 Veja qual componente quebra.
5. 🔲 Rode `/fix [componente]`.
6. 🔲 Edite código, valide, commita.
7. 🔲 Repete até tudo verde.
8. 🔲 Teste em VM com `/test-vm`.
9. 🔲 Confira CHECKLIST_FINAL.md.
10. ✅ Installer PRONTO!

---

**Bom trabalho! O kit está pronto, you have full control now. 🚀**

Qualquer dúvida sobre um spec ou skill, é só ler o arquivo correspondente — tudo está documentado.
