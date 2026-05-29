# Prompt: Frontend Web do Instalador (Chromium Kiosk UI)

> Implementar o frontend do instalador que roda dentro do Chromium em kiosk mode.
> Interface de instalação step-by-step que consome a API Axum do backend.
> Stack: HTML + Vanilla JS (zero deps externas — precisa funcionar offline na ISO).

---

## FASE 1 — Estado atual do backend

```bash
# Ver os endpoints disponíveis
cat /etc/kryonix/packages/kryonix-installer/src/main.rs 2>/dev/null | \
  grep -A2 'route\|get\|post\|Router'

# Testar o backend localmente
cd /etc/kryonix
nix run .#kryonix-installer -- --port 8080 &
sleep 2
curl -s http://localhost:8080/health | jq .
curl -s http://localhost:8080/probe  | jq .
curl -s http://localhost:8080/plan   | jq .
```

---

## FASE 2 — Estrutura do frontend

Criar em `packages/kryonix-installer/frontend/`:

```
frontend/
├── index.html         ← página principal
├── style.css          ← tema HUD (paleta kryonix)
├── app.js             ← lógica principal
└── assets/
    └── logo.svg       ← logo kryonix
```

### Paleta de cores HUD (consistente com o sistema)

```css
:root {
  --bg:        #0a0d12;
  --bg2:       #0f1318;
  --border:    #1a2332;
  --primary:   #00d4ff;   /* ciano */
  --secondary: #82aaff;   /* azul */
  --accent:    #b48eff;   /* roxo */
  --text:      #cdd6f4;
  --text-dim:  #6c7086;
  --success:   #a6e3a1;
  --warning:   #f9e2af;
  --error:     #f38ba8;
}
```

### Fluxo de telas (steps)

```
Step 1: Bem-vindo
  → Detectar hardware automaticamente
  → Mostrar: CPU, RAM, discos, GPU, modo de boot

Step 2: Configuração básica
  → Hostname (input)
  → Timezone (select — pré-selecionado: America/Cuiaba)
  → Idioma/teclado (select — pré-selecionado: pt_BR / br-abnt2)

Step 3: Usuário
  → Nome de usuário (input)
  → Senha (input + confirmação)
  → Checkbox: admin (sudo)

Step 4: Disco
  → Lista de discos detectados (tabela)
  → Seleção de disco alvo
  → Layout: btrfs-simple / btrfs-home-var / lvm-simple
  → Aviso de DESTRUIÇÃO DE DADOS em vermelho

Step 5: Perfil
  → Desktop: Hyprland+Caelestia / GNOME / Minimal
  → Features: Brain Client, Bluetooth, Gaming (Steam)
  → Kryonix Brain: conectar ao Glacier? (toggle)

Step 6: Revisão
  → Resumo de tudo que será feito
  → Botão "Gerar install-plan.json" → chama POST /plan
  → Mostra o JSON gerado
  → Botão "Dry Run" → chama POST /dry-run

Step 7: Instalação (Fase 2)
  → Progress bar
  → Log em tempo real (SSE ou polling)
  → Botão "Reiniciar" ao fim
```

### index.html — estrutura mínima

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kryonix Installer</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <div class="logo">⟡ KRYONIX</div>
    <div class="step-indicator" id="steps"></div>
  </header>

  <main id="app">
    <!-- Steps são renderizados aqui via JS -->
  </main>

  <footer>
    <button id="btn-back" class="btn-secondary">← Voltar</button>
    <div class="step-label" id="step-label">1 / 7</div>
    <button id="btn-next" class="btn-primary">Próximo →</button>
  </footer>

  <script src="app.js"></script>
</body>
</html>
```

### app.js — estrutura

```javascript
// Estado global
const state = {
  step: 0,
  hardware: null,
  config: {
    hostname: 'kryonix',
    timezone: 'America/Cuiaba',
    locale: 'pt_BR.UTF-8',
    keyboard: 'br-abnt2',
    username: '',
    password: '',
    disk: null,
    layout: 'btrfs-simple',
    profile: 'hyprland-caelestia',
    features: { brain_client: false, bluetooth: true, gaming: false },
  },
  plan: null,
};

const API = 'http://localhost:8080';

// Carregar hardware ao iniciar
async function loadHardware() {
  const r = await fetch(`${API}/probe`);
  state.hardware = await r.json();
  renderStep();
}

// Gerar plano
async function generatePlan() {
  const body = {
    version: 1,
    hostname:  state.config.hostname,
    timezone:  state.config.timezone,
    locale:    state.config.locale,
    keyboard:  state.config.keyboard,
    boot: { mode: state.hardware.boot_mode },
    disk: {
      mode:   'dry-run',
      target: state.config.disk,
      layout: state.config.layout,
    },
    user: {
      name:  state.config.username,
      admin: true,
    },
    features: {
      desktop:      state.config.profile,
      nvidia:       state.hardware.gpu?.some(g => g.vendor === 'nvidia') ? 'auto' : 'none',
      zram:         true,
      brain_client: state.config.features.brain_client,
    },
  };

  const r = await fetch(`${API}/plan`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  state.plan = await r.json();
  return state.plan;
}

// Cada step é uma função que retorna HTML
const steps = [
  renderWelcome,
  renderHardware,
  renderBasicConfig,
  renderUser,
  renderDisk,
  renderProfile,
  renderReview,
];

function renderStep() {
  document.getElementById('app').innerHTML = steps[state.step]();
  document.getElementById('step-label').textContent =
    `${state.step + 1} / ${steps.length}`;
}

loadHardware();
```

---

## FASE 3 — Empacotar no Nix

```nix
# packages/kryonix-installer/frontend.nix
{ pkgs }:

pkgs.runCommand "kryonix-installer-frontend" {} ''
  mkdir -p $out/share/kryonix-installer/frontend
  cp -r ${./frontend}/* $out/share/kryonix-installer/frontend/
''
```

O backend Axum deve servir os arquivos estáticos:

```rust
// src/main.rs — adicionar rota estática
.nest_service("/", ServeDir::new(frontend_path))
```

---

## FASE 4 — Teste no browser antes da ISO

```bash
# Iniciar backend
nix run /etc/kryonix#kryonix-installer -- --port 8080 &

# Abrir no browser normal para desenvolver
xdg-open http://localhost:8080

# Ou testar com Chromium em kiosk
chromium --kiosk http://localhost:8080
```

---

## Checklist

```
[ ] Step 1 (hardware) carrega dados reais do /probe
[ ] Step 4 (disco) lista discos com tamanho correto
[ ] Step 6 (revisão) gera install-plan.json válido
[ ] Dry run retorna sem erro
[ ] Tema HUD (fundo escuro, texto ciano) aplicado
[ ] Funciona sem internet (zero CDN, tudo local)
[ ] Chromium --kiosk não mostra barra de endereço
```

---

## Commit

```bash
git -C /etc/kryonix add packages/kryonix-installer/frontend/

git -C /etc/kryonix commit -m "feat(installer): frontend web kiosk step-by-step

- 7 steps: hardware, config, usuário, disco, perfil, revisão
- Consome API Axum local (/probe, /plan, /dry-run)
- Tema HUD kryonix (ciano/escuro)
- Zero dependências externas (funciona offline na ISO)"
```
