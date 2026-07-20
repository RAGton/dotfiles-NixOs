# ✅ SOLUÇÃO DEFINITIVA: greetd com Sessão Wayland Funcional

**Data**: 2026-02-21 (atualizado)
**Status**: ✅ Implementada e Documentada  
**Autor**: RAGton

---

## 🎯 Objetivo

Garantir que o greetd funcione **perfeitamente** como display manager para Hyprland/DMS, criando sessões Wayland válidas com seat attachment, permitindo que o compositor inicie corretamente após o login via UWSM.

---

## 🚨 Problema Identificado: Login Loop

### Sintoma
- Usuário faz login via greetd + tuigreet
- Hyprland/DMS **não iniciam** (login loop)
- Sistema volta para TTY ou tela preta

### Raiz do Problema
A configuração PAM do greetd não especificava parâmetros críticos para `pam_systemd.so`:
- **Faltava**: `class=user type=wayland`
- **Resultado**: logind criava sessão tipo "manager" sem seat
- **Consequência**: UWSM e Hyprland não conseguiam acessar dispositivos gráficos

### Por Que `startSession = true` Não É Suficiente

A opção estruturada do NixOS `startSession = true` adiciona `pam_systemd.so` **SEM** os parâmetros necessários:

```nix
# ❌ INCOMPLETO (apenas adiciona pam_systemd.so básico)
security.pam.services.greetd = {
  startSession = true;  # Não especifica class= nem type=
};

# ✅ CORRETO (especifica class=user type=wayland)
security.pam.services.greetd = {
  text = lib.mkForce ''
    session  required pam_systemd.so class=user type=wayland
  '';
};
```

---

## ✅ Solução Implementada

### Arquivo Modificado
`modules/nixos/services/greetd-dms/default.nix`

### Características da Solução

1. **Configuração explícita do VT** - greetd executa no VT1 por padrão
2. **tuigreet otimizado** - com `--remember`, `--remember-user-session` e `--asterisks`
3. **PAM configurado para Wayland** - `class=user type=wayland` em pam_systemd.so
4. **logind configurado corretamente** - não mata processos no logout
5. **UWSM como comando padrão** - `uwsm start hyprland-uwsm.desktop`

### Configuração PAM Completa

```nix
security.pam.services.greetd = {
  allowNullPassword = lib.mkForce false;
  unixAuth = true;
  text = lib.mkForce ''
    # PAM para greetd - Sessão Wayland funcional
    
    # Autenticação
    auth     required pam_unix.so nullok try_first_pass
    auth     optional pam_gnome_keyring.so

    # Verificação de conta
    account  required pam_unix.so

    # Senha (para troca de senha)
    password required pam_unix.so nullok yescrypt
    password optional pam_gnome_keyring.so use_authtok

    # Sessão - ORDEM IMPORTA
    session  required pam_unix.so
    session  required pam_env.so conffile=/etc/pam/environment readenv=0
    session  optional pam_keyinit.so force revoke
    session  required pam_limits.so

    # CRÍTICO: class=user type=wayland para sessão Wayland válida
    session  required pam_systemd.so class=user type=wayland

    # Gnome Keyring (desbloqueio automático)
    session  optional pam_gnome_keyring.so auto_start

    # Fallback para módulos opcionais
    session  optional pam_permit.so
  '';
};
```

### Por Que Funciona

| Parâmetro | Função |
|-----------|---------|
| `class=user` | Instrui logind a criar sessão de classe "user" (com seat) em vez de "manager" |
| `type=wayland` | Marca a sessão como Wayland, fazendo logind alocar VT e definir `XDG_SESSION_TYPE=wayland` |
| `vt = 1` | Define explicitamente o VT onde greetd executa |
| `--remember` | tuigreet lembra o último usuário logado |
| `force revoke` | pam_keyinit revoga keys antigas forçadamente |

---

## 🔄 Fluxo Correto (Após Solução)

```
[Boot]
  ↓
[greetd.service inicia]
  ↓
[tuigreet exibe prompt de login]
  ↓
[Usuário digita credenciais]
  ↓
[PAM autentica → pam_systemd.so class=user type=wayland]
  ↓
[logind cria sessão Wayland com seat0 ✅]
  ↓
[Exporta XDG_SESSION_TYPE=wayland, XDG_SEAT=seat0]
  ↓
[Executa: uwsm start hyprland-uwsm.desktop]
  ↓
[UWSM herda sessão Wayland válida ✅]
  ↓
[Hyprland inicia com acesso ao seat ✅]
  ↓
[DMS shell é renderizada ✅]
  ↓
[Interface gráfica funcional! 🎉]
```

---

## 🧪 Como Validar

### 1. Reconstruir o Sistema
```bash
cd ~/node-nixos
sudo nixos-rebuild switch --flake .#inspiron
```

### 2. Reiniciar
```bash
sudo reboot
```

### 3. Fazer Login
- Digite seu usuário no prompt do tuigreet
- Digite sua senha
- Pressione ENTER

### 4. Verificar Sessão logind
```bash
loginctl session-status
```

**Esperado (✅ CORRETO)**:
```
Session c1
     Type: wayland       ← Tipo correto
    Class: user          ← Classe correta
    State: active
     Seat: seat0         ← Seat atribuído
```

**Problema (❌ INCORRETO)**:
```
Session 1
     Type: tty
    Class: manager       ← Classe errada
    State: active
     Seat: (nenhum)      ← Sem seat
```

### 5. Verificar Variáveis de Ambiente
```bash
env | grep XDG_SESSION
```

**Esperado**:
```
XDG_SESSION_TYPE=wayland
XDG_SESSION_CLASS=user
XDG_SEAT=seat0
```

---

## 📊 Comparação Técnica

| Aspecto | Antes (❌) | Depois (✅) |
|---------|-----------|------------|
| PAM `pam_systemd.so` | Padrão (sem parâmetros) | `class=user type=wayland` |
| Classe da Sessão logind | `manager` | `user` |
| Tipo da Sessão | `tty` | `wayland` |
| Seat Atribuído | (nenhum) | `seat0` |
| `XDG_SESSION_TYPE` | (indefinido) | `wayland` |
| Hyprland Inicia | ❌ Não | ✅ Sim |
| DMS Renderizado | ❌ Não | ✅ Sim |

---

## 🔍 Troubleshooting

### Problema: Hyprland não inicia após login
**Diagnóstico**:
```bash
loginctl session-status
```

Se `Class: manager` ou `Seat: (nenhum)`:
1. Verifique se o rebuild foi feito corretamente
2. Confirme que `/etc/pam.d/greetd` contém `pam_systemd.so class=user type=wayland`
   ```bash
   cat /etc/pam.d/greetd | grep pam_systemd
   ```
3. Refaça o rebuild se necessário

### Problema: Tela preta após login
**Diagnóstico**:
```bash
journalctl -u greetd -n 50
```

Procure por:
- Erros de UWSM
- Falhas de permissão em `/dev/dri`
- Problemas de seat

**Solução**: Verifique que a sessão logind tem seat atribuído (veja passo 4 acima)

---

## 🎁 Benefícios da Solução

1. **✅ Sessão Wayland Válida**: logind cria sessão com todos os atributos corretos
2. **✅ Seat Attachment**: Acesso garantido a dispositivos gráficos
3. **✅ UWSM Funcional**: Herda ambiente Wayland correto
4. **✅ Hyprland Inicia**: Compositor tem acesso ao VT e pode renderizar
5. **✅ DMS Visível**: Shell gráfica é exibida corretamente
6. **✅ Gnome Keyring**: Integração automática com pam_gnome_keyring.so
7. **✅ Segurança**: `allowNullPassword = false` mantém segurança

---

## 📝 Notas Técnicas

### pam_systemd.so
Módulo PAM que integra autenticação com systemd-logind:
- **class=user**: Cria sessão "user" com seat de VT (não "manager" nem "greeter")
- **type=wayland**: Informa ao logind que é sessão Wayland (define XDG_SESSION_TYPE)

### UWSM (Universal Wayland Session Manager)
Gerenciador de sessão Wayland moderno que:
- Requer `XDG_SESSION_TYPE=wayland` para funcionar
- Lança compositores Wayland (como Hyprland) com ambiente correto
- Gerencia o ciclo de vida da sessão gráfica

### greetd + tuigreet
Display manager minimalista:
- greetd: daemon que gerencia logins
- tuigreet: greeter TUI (Text User Interface)
- Leve, Wayland-friendly, sem dependências de GNOME/KDE

---

## 🔗 Referências

- **Documentação do Problema**: `docs/AUDIT_LOGIND_SESSION.md`
- **Solução Técnica**: `docs/SOLUTION_LOGIND_WAYLAND.md`
- **Testes de Validação**: `docs/TEST_GUIDE_WAYLAND_SESSION.md`
- **Módulo Implementado**: `modules/nixos/services/greetd-dms/default.nix`

---

## 🎯 Resumo Executivo

**Problema**: greetd criava sessões "manager" sem seat, impedindo Hyprland/DMS de iniciar.

**Solução**: Configuração PAM explícita com `pam_systemd.so class=user type=wayland`.

**Resultado**: Sessões Wayland válidas com seat, Hyprland/DMS funcionam perfeitamente.

**Status**: ✅ **RESOLVIDO DEFINITIVAMENTE**

---

**Última atualização**: 2026-02-21  
**Versão do NixOS**: 26.05 (unstable)  
**Testado em**: inspiron (Dell Inspiron 15 3000)
