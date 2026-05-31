# Prompt: Kora — Wake-Word Fuzzy + Integração Desktop Completa

> Você está em `/etc/kryonix`.
> A Kora já tem: API :8787, CLI, push-to-talk, STT (whisper-cli), TTS (Piper),
> VAD, pipeline de voz, daemon base. O que FALTA é: wake-word validado com
> variantes fonéticas, listener always-on robusto, e ferramentas de desktop
> (screenshot, janela ativa, MCP) disponíveis para a Kora responder com contexto visual.

---

## Contexto atual (ler antes de qualquer coisa)

```bash
# Ver estado atual do módulo de voz
cat packages/kora/kora/voice/wakeword.py
cat packages/kora/kora/voice/daemon.py
cat packages/kora/kora/voice/pipeline.py

# Ver o que já está no roadmap
cat docs/kora/ROADMAP.md | grep -A5 "Fase 4"

# Verificar se wake-word está ready
kora voice doctor 2>/dev/null || python -c "
import json
from kora.voice.wakeword import WakeWordEngine
print(WakeWordEngine().status())
"

# Estado do daemon
kora voice service status 2>/dev/null
systemctl --user status kora-voice 2>/dev/null
```

Reportar o que está ready=true vs ready=false antes de qualquer implementação.

---

## TAREFA 1 — Wake-word fuzzy com variantes fonéticas de "Kora"

### Por que fuzzy é necessário

O usuário fala com variação de tonalidade, sotaque e velocidade. "Kora" pode soar
como: **kora, korra, cora, corra, hora, cara, kara**. O sistema deve acordar em
todos esses casos sem falsos positivos excessivos.

### Estratégia em duas camadas

**Camada 1 — openWakeWord (baixíssimo CPU, sempre ativo)**
Detecta palavras-chave com modelo leve. Se não tiver modelo customizado "kora",
usar "hey jarvis" ou modelo base como proxy para detectar atividade vocal.

**Camada 2 — Fuzzy match na transcrição**
Após detectar atividade, gravar 1-2s, transcrever com whisper e verificar se
o texto contém alguma das variantes fonéticas. Mais preciso, custo mais alto
mas só ativa quando a camada 1 detectou algo.

### Implementação em `packages/kora/kora/voice/wakeword.py`

```python
# Variantes fonéticas aceitas como wake-word
# Pegar qualquer uma dessas na transcrição = acordar
WAKE_VARIANTS = [
    "kora",    # canônico
    "korra",   # duplo r
    "cora",    # c inicial
    "corra",   # c + rr
    "hora",    # k → h (sotaque)
    "cara",    # vogal diferente
    "kara",    # variante
    "koa",     # r omitido
    "coa",     # c + vogal
]

def is_wake_word(text: str) -> bool:
    """Verifica se o texto contém uma variante do wake-word."""
    import difflib
    text_lower = text.lower().strip()
    words = text_lower.split()

    for word in words:
        # Match exato
        if word in WAKE_VARIANTS:
            return True
        # Match fuzzy (similaridade > 0.8 com "kora")
        if difflib.SequenceMatcher(None, word, "kora").ratio() > 0.80:
            return True

    return False
```

### Configuração da variante no `config.py`

```python
# packages/kora/kora/voice/config.py
WAKE_WORD_PRIMARY = "kora"
WAKE_WORD_VARIANTS = WAKE_VARIANTS  # importar de wakeword.py
WAKE_WORD_FUZZY_THRESHOLD = 0.80    # 80% de similaridade
WAKE_WORD_CONFIRM_STT = True        # confirmar com STT após detecção
```

### Modelo openWakeWord no NixOS

```nix
# Em modules/nixos/services/kora/voice.nix
# Adicionar openwakeword às dependências do pacote kora
```

Verificar se `openwakeword` está disponível em nixpkgs/pypi:
```bash
nix search nixpkgs openwakeword 2>/dev/null
pip index versions openwakeword 2>/dev/null | head -3
```

Se não disponível, usar abordagem alternativa: **always-VAD com STT rápido**
(gravar o tempo todo em janelas de 2s, transcrever com modelo tiny do whisper,
verificar fuzzy match). Consume mais CPU mas não depende de openWakeWord.

Documentar qual abordagem foi usada e por quê.

---

## TAREFA 2 — Daemon always-on robusto

### Comportamento esperado

```
daemon rodando silenciosamente
    ↓
microfone ativo, escutando (low-CPU)
    ↓
detecta algo parecido com "Kora"
    ↓
♪ beep curto de confirmação (notify-send + som)
    ↓
grava enquanto usuário fala
    ↓
silêncio por 1.0s → para de gravar
    ↓
STT local (whisper tiny/base)
    ↓
Kora API :8787/chat POST
    ↓
TTS Piper → alto-falante
    ↓
volta a escutar
```

### Sinal visual quando acorda (integração Hyprland)

```python
# Em daemon.py, ao detectar wake-word:
import subprocess

def signal_awake():
    """Feedback visual + sonoro ao acordar."""
    # Notificação no Caelestia Shell
    subprocess.run([
        "notify-send",
        "--icon", "audio-input-microphone",
        "--urgency", "low",
        "--expire-time", "2000",
        "⟡ Kora", "ouvindo..."
    ])
    # Beep via PipeWire (som curto de 440Hz, 0.1s)
    subprocess.run([
        "pw-play", "--target=0",
        "/run/current-system/sw/share/sounds/freedesktop/stereo/message.oga"
    ], capture_output=True)

def signal_thinking():
    """Feedback quando está processando."""
    subprocess.run([
        "notify-send", "--icon", "system-search",
        "--urgency", "low", "--expire-time", "5000",
        "⟡ Kora", "processando..."
    ])
```

### Arquivo do daemon (`/var/lib/kryonix/kora/voice/muted`)

O daemon deve verificar este arquivo antes de processar. Se existir → mudo.
`kora voice mute` cria o arquivo. `kora voice unmute` remove.

---

## TAREFA 3 — Ferramentas de desktop para contexto visual

A Kora deve poder tirar screenshot e ver o contexto atual quando o usuário pede
"o que está na minha tela?" ou "dá uma olhada no projeto".

### Tool: screenshot

```python
# packages/kora/kora/tools/desktop.py

import subprocess, base64, tempfile, os
from pathlib import Path

def capture_screenshot() -> str:
    """Captura tela ativa e retorna como base64. Usa grimblast (já instalado)."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        path = f.name

    result = subprocess.run(
        ["grimblast", "save", "active", path],
        capture_output=True
    )

    if result.returncode != 0:
        # Fallback: captura a tela inteira
        subprocess.run(["grimblast", "save", "screen", path])

    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()

    os.unlink(path)
    return data  # base64 PNG


def get_active_window() -> dict:
    """Retorna informações da janela ativa via hyprctl."""
    result = subprocess.run(
        ["hyprctl", "activewindow", "-j"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        import json
        return json.loads(result.stdout)
    return {}


def get_system_context() -> dict:
    """Coleta contexto do sistema para enriquecer a resposta da Kora."""
    return {
        "active_window": get_active_window(),
        "workspaces": _get_workspaces(),
        "hostname": os.uname().nodename,
    }


def _get_workspaces() -> list:
    result = subprocess.run(
        ["hyprctl", "workspaces", "-j"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        import json
        return json.loads(result.stdout)
    return []
```

### Integração no endpoint de chat da Kora API

Quando a mensagem contém palavras-chave visuais, incluir a screenshot:

```python
# packages/kora/kora/core/orchestrator.py (adicionar)

VISUAL_TRIGGERS = [
    "olha", "vê", "veja", "screenshot", "tela", "janela",
    "projeto", "código", "o que está", "mostra", "o que tem"
]

def needs_visual_context(text: str) -> bool:
    return any(trigger in text.lower() for trigger in VISUAL_TRIGGERS)
```

### Ferramenta de busca MCP quando pedido

Quando o usuário pede "pesquisa X" ou "busca no Brain", a Kora deve usar os
MCP servers já configurados:

```python
# packages/kora/kora/tools/mcp_bridge.py

MCP_TOOLS = {
    "brain": "kryonix-brain",      # LightRAG
    "nixos": "mcp-nixos",          # Opções NixOS
    "vault": "vault-readonly",     # Obsidian vault
    "github": "github",            # Repositórios
}

def search_brain(query: str) -> str:
    """Busca no Kryonix Brain via API."""
    import httpx
    resp = httpx.post(
        "http://glacier:8000/query",
        json={"query": query},
        timeout=30
    )
    return resp.json().get("result", "")
```

---

## TAREFA 4 — Voz feminina PT-BR local

O TTS atual está masculino/robótico. Piper tem modelos femininos PT-BR.

```bash
# Ver modelos disponíveis
kora voice models status
kora voice voices list

# Baixar modelo feminino PT-BR (escolher o melhor disponível):
# Opções conhecidas para Piper PT-BR:
# - pt_BR-faber-medium
# - pt_BR-edresson-low
# Verificar qual existe no pacote
kora voice models install 2>/dev/null || \
  python -c "from kora.voice.models import list_available; print(list_available())"
```

Após identificar o melhor modelo feminino PT-BR disponível:

```python
# packages/kora/kora/voice/config.py
TTS_VOICE = "pt_BR-faber-medium"  # ou o melhor disponível
TTS_LANGUAGE = "pt-BR"
TTS_SPEED = 1.0
TTS_PITCH = 0.0  # ajustar para soar mais natural
```

---

## TAREFA 5 — Serviço systemd permanente

O listener de voz deve iniciar automaticamente no login do usuário:

```nix
# modules/nixos/services/kora/voice.nix (adicionar ou completar)
systemd.user.services.kora-voice = {
  description = "Kora Voice Listener — wake-word + always-on";
  wantedBy    = [ "graphical-session.target" ];
  after       = [ "graphical-session.target" "pipewire.service" ];
  partOf      = [ "graphical-session.target" ];

  serviceConfig = {
    Type       = "simple";
    ExecStart  = "${kora}/bin/kora voice service start --foreground";
    Restart    = "on-failure";
    RestartSec = "5s";

    # Não reiniciar se o usuário mutou
    ExecStartPre = pkgs.writeShellScript "kora-voice-check" ''
      [ -f /var/lib/kryonix/kora/voice/muted ] && exit 1 || exit 0
    '';
  };

  environment = {
    KORA_API_URL = "http://glacier:8787";
    DISPLAY      = ":0";  # necessário para notify-send
    WAYLAND_DISPLAY = "wayland-1";
  };
};
```

---

## Validação

```bash
# 1. Sintaxe e compilação
python -m compileall packages/kora
nix build .#kora --no-link -L

# 2. Wake-word fuzzy
python -c "
from kora.voice.wakeword import is_wake_word
tests = ['kora', 'korra', 'cora', 'hora', 'oi kora tudo bem', 'pizza']
for t in tests:
    print(f'{t!r:30} → {is_wake_word(t)}')
"
# Esperado: tudo menos 'pizza' = True

# 3. Screenshot tool
python -c "
from kora.tools.desktop import capture_screenshot, get_active_window
w = get_active_window()
print('Janela ativa:', w.get('title', 'N/A'))
img = capture_screenshot()
print('Screenshot capturada:', len(img), 'bytes base64')
"

# 4. Daemon de voz (testar sem fechar o terminal primeiro)
kora voice doctor
kora voice service start
sleep 3
kora voice service status
# → deve mostrar running=true

# 5. Teste de wake-word (falar "Kora" após iniciar)
kora voice service logs --follow

# 6. Mute/unmute
kora voice mute
kora voice status   # → muted=true
kora voice unmute
kora voice status   # → muted=false

# 7. Aplicar no sistema
kryonix switch all
systemctl --user restart kora-voice
```

### Checklist

```
[ ] is_wake_word("korra") retorna True
[ ] is_wake_word("cora") retorna True
[ ] is_wake_word("pizza") retorna False
[ ] grimblast captura screenshot sem erro
[ ] get_active_window() retorna dados da janela atual
[ ] kora-voice.service inicia e fica running
[ ] Falar "Kora" → notify-send aparece "ouvindo..."
[ ] Kora responde por voz (Piper) em PT-BR
[ ] kora voice mute desativa o listener
[ ] kryonix switch all passa sem erro
```

---

## Regras

1. Não usar cloud STT/TTS — tudo local
2. Não salvar áudio bruto por padrão
3. is_wake_word deve passar nos testes unitários antes do commit
4. Screenshot só captura quando o usuário pede — nunca automático
5. Não quebrar: `kora ask`, `kora listen --push-to-talk`, `kora voice doctor`
6. Reportar qual abordagem de wake-word foi usada (openWakeWord ou VAD+STT)
7. Não declarar ready=true se não passou pelo teste de fala real
8. Commit separado por tarefa — não tudo junto
9. Se distrair com outro erro → anotar e reportar, mas não corrigir agora
```
