# RAGOS Installer ISO Forensics

Status: archived  
Scope: Analise forense de um problema anterior do installer kiosk

Data da auditoria: 2026-03-12

## Diagnostico executivo

- Bloqueador principal: regressao de policy do Chromium introduzida na v12.
- Defeito secundario: empacotamento de fontconfig incompleto na ISO, gerando erro de runtime e ruido de diagnostico.
- Rede/Hyper-V: nao era a causa raiz do travamento local. O host alcançava a VM e a API do installer normalmente.

Resumo:

1. A VM recebeu IP `172.20.227.35`.
2. O backend `ragos-installer-ui` subia corretamente em `0.0.0.0:8000`.
3. O host acessava `http://172.20.227.35:8000/api/v1/status` com `200 OK`.
4. O problema local vinha do Chromium em kiosk bloqueando `http://127.0.0.1:8000` por policy.

## Matriz de falha

| Sintoma | Evidencia | Hipotese | Como validar | Resultado | Correcao |
| --- | --- | --- | --- | --- | --- |
| Host nao via a UI | `Test-NetConnection 172.20.227.35 -Port 8000` e `Invoke-WebRequest` retornaram sucesso | Problema de rede externa | Testar IP real da VM e endpoint `/api/v1/status` | Refutado | Nenhuma correcao de rede foi necessaria |
| Chromium local travado | Tela mostrava `127.0.0.1 is blocked` | Policy do navegador bloqueando a propria UI | Inspecionar `ragos-kiosk.json` e comparar com a versao funcional | Confirmado | Corrigir `URLAllowlist` |
| Possivel falha do backend | `systemctl is-active ragos-installer-ui` = `active`; `ss -ltnp` mostrou `0.0.0.0:8000` | Backend caiu ou bindou errado | Verificar service, porta e status endpoint | Refutado | Nenhuma correcao de backend foi necessaria |
| Possivel quebra do display | `display-manager` ativo, `X`, `openbox` e `chromium` presentes | LightDM/X/Openbox nao subiram | Verificar sessao e processos | Refutado | Nenhuma correcao de display foi necessaria |
| Ruido de Fontconfig | `Fontconfig error: Cannot load default config file` no log do kiosk | Chromium sem config de fontes na ISO | Validar `/etc/fonts/fonts.conf` e empacotamento | Confirmado como defeito secundario | Habilitar `fonts.fontconfig.enable` e expor envs do fontconfig |

## Cadeia de falha

Fluxo real observado na v12:

`boot ok -> lightdm ok -> openbox ok -> backend ok -> chromium abre -> policy corporativa bloqueia http://127.0.0.1:8000 -> UI local nao carrega`

Fluxo do host em paralelo:

`host -> 172.20.227.35:8000 -> backend responde -> frontend renderiza normalmente`

Conclusao:

- O defeito local do installer e o acesso host -> VM nao eram o mesmo problema.
- O caminho remoto funcionava.
- O caminho local kiosk quebrava por policy do Chromium.

## Regressao identificada

Versao funcional comparada: commit `0f93dc0`

Na versao funcional nao existia o arquivo de policy do Chromium para bloquear todas as URLs.

Na v12, o modulo [`installer/iso-kiosk.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso-kiosk.nix) passou a gerar:

```nix
URLBlocklist = [ "*" ];
URLAllowlist = [
  "http://127.0.0.1:8000/*"
  "http://localhost:8000/*"
  "file://${ragosKioskFallbackPage}"
];
```

Isso introduziu a regressao. `URLAllowlist`/`URLBlocklist` usam a sintaxe de filtro do Chromium. Nesse formato, `http://127.0.0.1:8000/*` nao libera a URL raiz `http://127.0.0.1:8000`, entao o proprio Chromium passou a bloquear a home do installer.

Evidencia direta em runtime:

- Tela local: `127.0.0.1 is blocked`
- Titulo da janela X antes da correcao:

```text
WM_NAME(UTF8_STRING) = "127.0.0.1"
```

- Titulo da janela X depois da correcao:

```text
WM_NAME(UTF8_STRING) = "RAGos Think Installer"
```

## Evidencias principais

### IP real da VM

```text
172.20.227.35
```

### Backend acessivel pelo host

```text
Test-NetConnection 172.20.227.35 -Port 8000 => TcpTestSucceeded = True
Invoke-WebRequest http://172.20.227.35:8000/api/v1/status => 200 OK
```

Resposta observada:

```json
{"havePlan":false,"canInstall":false,"running":false,"exitCode":null,"startedAt":null,"finishedAt":null,"installRunning":false,"lastInstallExit":null,"installStartedAtUnix":null}
```

### UI renderizando fora da VM

Validacao via Playwright no host:

- Titulo: `RAGos Think Installer`
- Sem erros de console
- Wizard renderizado corretamente

### Policy ativa na ISO corrigida

```json
{"BrowserAddPersonEnabled":false,"BrowserGuestModeEnabled":false,"DeveloperToolsAvailability":2,"URLAllowlist":["http://127.0.0.1:8000","http://localhost:8000","file:///nix/store/syscamrfri27qral1vl95b9yx93h1gg8-ragos-installer-fallback.html"],"URLBlocklist":["*"]}
```

### Validacao local da janela do kiosk

```text
_NET_ACTIVE_WINDOW(WINDOW): window id # 0x600003
WM_NAME(UTF8_STRING) = "RAGos Think Installer"
_NET_WM_NAME(UTF8_STRING) = "RAGos Think Installer"
WM_CLASS(STRING) = "127.0.0.1", "Chromium-browser"
```

## Correcao implementada

### 1. Correcao principal da regressao

Arquivo alterado:

- [`installer/iso-kiosk.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso-kiosk.nix)

Mudanca:

- Troca da allowlist com `/*` por filtros validos para a origem do installer:
  - `http://127.0.0.1:8000`
  - `http://localhost:8000`
  - `file://...fallback.html`

Protecoes adicionadas:

- Assertion exigindo as origens raiz do installer na `URLAllowlist`
- Assertion bloqueando o padrao `/*` em entradas HTTP/HTTPS desse kiosk

### 2. Correcao secundaria de fontconfig

Arquivos alterados:

- [`installer/iso-base.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso-base.nix)
- [`installer/iso.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso.nix)

Mudancas:

- `fonts.fontconfig.enable = true`
- assertion de build para nao remover fontconfig sem falha explicita
- `FONTCONFIG_FILE` e `FONTCONFIG_PATH` exportados no launcher do kiosk
- simplificacao das flags agressivas adicionadas no launcher do Chromium

## Validacao final

### Validacao dentro da VM

Checklist validado em boot limpo com a ISO nova:

1. `display-manager` ativo
2. `ragos-installer-ui` ativo
3. `ss -ltnp` com `0.0.0.0:8000`
4. policy correta presente em `/etc/chromium/policies/managed/ragos-kiosk.json`
5. `WM_NAME` da janela local = `RAGos Think Installer`

### Validacao a partir do host

1. `172.20.227.35:22` acessivel
2. `172.20.227.35:8000` acessivel
3. `GET /api/v1/status` respondendo normalmente
4. frontend renderizando corretamente no host

## Artefatos gerados

- ISO corrigida copiada para:
  - `C:\Users\aguia\Documents\ragos-installer-25.11-kiosk-v16.iso`

## Prevencao de regressao

Minimo adicionado nesta correcao:

1. Assertions de build para a policy do Chromium em [`installer/iso-kiosk.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso-kiosk.nix)
2. Assertion de build para `fonts.fontconfig.enable` em [`installer/iso-base.nix`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/iso-base.nix)

Checklist recomendado para futuras ISOs:

1. Bootar a ISO em Hyper-V
2. Descobrir o IP da VM
3. Validar `curl http://IP:8000/api/v1/status`
4. Validar o titulo local da janela com `xprop`
5. Confirmar que `WM_NAME` e `RAGos Think Installer`
6. Confirmar que a policy do Chromium contem as origens raiz e nao `/*`
7. Capturar um screenshot local e um remoto antes de promover a release

## Comandos que fecharam o diagnostico

```powershell
Test-NetConnection 172.20.227.35 -Port 8000
Invoke-WebRequest http://172.20.227.35:8000/api/v1/status
```

```bash
cat /etc/chromium/policies/managed/ragos-kiosk.json
```

```bash
runuser -u ragos -- env DISPLAY=:0 XAUTHORITY=/home/ragos/.Xauthority xprop -root _NET_ACTIVE_WINDOW
runuser -u ragos -- env DISPLAY=:0 XAUTHORITY=/home/ragos/.Xauthority xprop -id 0x600003 WM_NAME _NET_WM_NAME WM_CLASS
```

## Estado final

- Backend da ISO sobe corretamente
- Porta esperada esta ouvindo
- UI abre do host
- UI abre localmente no modo grafico
- IP validado: `172.20.227.35`
- Causa raiz identificada com precisao
- Protecoes de regressao adicionadas

## Follow-up: selecao de discos

Problema adicional encontrado apos a recuperacao do kiosk:

- Sintoma: clicar em um disco na etapa de storage nao marcava a selecao.
- Causa raiz: [`installer/installer-ui/src/state/wizardState.js`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/installer-ui/src/state/wizardState.js) normalizava `selectedDisks`, `storageBlockingIssues` e `storageWarnings` para os dois lados do estado ao mesmo tempo.
- Efeito: `uiState.selectedDisks = []` passava a sobrescrever `draft.selectedDisks` em `mergeWizardState`, entao o clique persistia por um instante e sumia visualmente.

Correcao:

- normalizacao condicionada apenas aos campos permitidos de cada metade do estado
- teste novo em [`installer/installer-ui/src/tests/wizardState.test.js`](/C:/Users/aguia/OneDrive/Documents/GitHub/ragos/installer/installer-ui/src/tests/wizardState.test.js)

Validacao real na ISO corrigida:

```text
attrs={"ariaPressed":"true","dataSelected":"true","text":"/dev/sdaSelecionadoVirtual Disk • 127 GiB✓"}
selectedDisks=["/dev/sda"]
sysDisk="/dev/sda"
uiSelectedDisksField=undefined
```
