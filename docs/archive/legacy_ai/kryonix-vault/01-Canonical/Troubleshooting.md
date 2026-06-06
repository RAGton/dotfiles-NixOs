---
source: docs/TROUBLESHOOTING.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Resolução de Problemas (Troubleshooting)

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento centraliza a abordagem oficial de resolução e documenta problemas conhecidos da infraestrutura Kryonix.

## Metodologia de Resolução

Ao encontrar um erro, siga o método:
1. Capture a mensagem exata de erro.
2. Identifique o comando ou o módulo/serviço que a gerou.
3. Classifique o erro entre:
   - Erro novo causado por uma alteração recente
   - Erro antigo já existente
   - Erro de ambiente/rede (ex: indisponibilidade do Glacier)
4. Corrija se possível, teste novamente e comunique. **Nunca esconda erros.**

## Problemas Conhecidos

### 1. Build do Inspiron Puxando Cadeia Pesada (Deno / rusty-v8)
**Sintoma:** Ao compilar o host `inspiron`, dependências pesadas e lentas (`rusty-v8`, `deno`, `yt-dlp`, `mpv-with-scripts`, `kalarm`) são requisitadas, atrasando o setup.
**Ação:** Analise de onde vem a requisição da dependência (`nix why-depends .#nixosConfigurations.inspiron.config.system.build.toplevel <drv>`).
**Correção:** Remova o serviço/pacote problemático do perfil do inspiron, isolando-o ao `glacier` se for apenas um recurso servidor; evite remover `Caelestia` ou `Hyprland` inteiros como "solução rápida".

### 2. Caelestia - Erro de Literal Inválido em postPatch
**Sintoma:** O patch falha exibindo `1: command not found`.
**Correção:** A formatação no `postPatch` precisa estar coesa. Modifique de acordo:
```nix
postPatch = (old.postPatch or "") + ''
  sed -i '/pragma DefaultEnv/d' shell.qml
'';
```

### 3. Erro D-Bus ou de Sessão Gráfica
**Investigação:**
Muitas vezes apps não rodam porque a sessão DBus não foi exportada adequadamente pelo systemd.
Execute os seguintes comandos para investigar em vez de aplicar workarounds ineficazes:
```sh
systemctl --user status dbus.service --no-pager
journalctl --user -b --no-pager -n 200
loginctl session-status
echo "$DBUS_SESSION_BUS_ADDRESS"
```

### 4. `bwrap: Can't chdir to /etc/kryonix`
**Sintoma:** Apps usando sandbox / libcontainers ou ambientes dev não conseguem acesso.
**Investigação e Causas:**
Pode significar um working directory inválido, a ausência de um bind mount na configuração, ou ausência do repositório no host em questão.
Para diagnosticar:
```sh
pwd
ls -ld /etc/kryonix
mount | grep kryonix
```
Não desabilite o sandbox cegamente.
