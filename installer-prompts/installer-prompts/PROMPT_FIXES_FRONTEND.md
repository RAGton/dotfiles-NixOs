# Prompt: Fixes Priorizados — Frontend + Backend + Testes

> Executar em ordem de prioridade. Cada fix tem validação própria.
> Parar após cada grupo e reportar antes de avançar.

---

## FIX 1 — SSE progress no frontend (CRÍTICO — Step 7 morto)

### Problema
POST /install retorna 202+job_id mas o frontend não conecta ao
EventSource('/install/progress'). A tela de instalação fica vazia.

### Fix em `ui/static/app.js`

Substituir a função que trata a resposta do POST /install por:

```javascript
async function startInstall(plan) {
  // Confirmar antes de tudo
  if (!document.getElementById('confirm-check')?.checked) {
    alert('Confirme que entende que os dados serão apagados.');
    return;
  }

  // Enviar POST /install
  let jobId;
  try {
    const r = await fetch('/install', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(plan),
    });
    if (r.status === 403) {
      const err = await r.json();
      showError('Safety checks falharam', err.checks);
      return;
    }
    const data = await r.json();
    jobId = data.job_id;
  } catch (e) {
    showError('Falha ao iniciar instalação', e.message);
    return;
  }

  // Ir para step de progresso
  renderProgressStep();

  // Conectar ao SSE
  const source = new EventSource('/install/progress');

  source.onmessage = (e) => {
    const evt = JSON.parse(e.data);
    updateProgress(evt.step, evt.message, evt.percent);

    if (evt.step === 'done') {
      source.close();
      showSuccess('Instalação concluída! Reiniciando em 10s...');
      setTimeout(() => {
        fetch('/reboot', { method: 'POST' }).catch(() => {});
      }, 10000);
    }
    if (evt.step === 'error') {
      source.close();
      showError('Erro durante instalação', evt.message);
    }
  };

  source.onerror = () => {
    source.close();
    showError('Conexão com o backend perdida', 'Verifique se o instalador ainda está rodando.');
  };
}

function renderProgressStep() {
  document.getElementById('app').innerHTML = `
    <div style="text-align:center;padding:40px 0">
      <div style="font-size:48px;margin-bottom:16px">⟡</div>
      <div id="progress-message" style="font-size:16px;color:var(--text);margin-bottom:24px">
        Iniciando instalação...
      </div>
      <div style="background:var(--border);border-radius:4px;height:4px;max-width:400px;margin:0 auto">
        <div id="progress-bar" style="background:var(--primary);height:4px;border-radius:4px;
             width:0%;transition:width 0.5s ease"></div>
      </div>
      <div id="progress-percent" style="font-size:13px;color:var(--text-dim);margin-top:8px">0%</div>
    </div>
  `;
}

function updateProgress(step, message, percent) {
  const bar  = document.getElementById('progress-bar');
  const msg  = document.getElementById('progress-message');
  const pct  = document.getElementById('progress-percent');
  if (bar)  bar.style.width  = percent + '%';
  if (msg)  msg.textContent  = message;
  if (pct)  pct.textContent  = percent + '%';
}
```

### Validação

```bash
cargo run -- --port 9999 &
sleep 2

# T21: EventSource presente
grep -q 'EventSource' ui/static/app.js && echo "PASS" || echo "FAIL"

# T: SSE endpoint responde
curl -sf -N http://localhost:9999/install/progress \
  --max-time 2 -H 'Accept: text/event-stream' | head -3
```

---

## FIX 2 — Modal de confirmação de destruição (CRÍTICO — segurança)

### Fix em `ui/static/app.js` — adicionar no Step 6 (revisão)

```javascript
function renderReview() {
  const plan = state.plan;
  return `
    <div class="review-section">
      <h3>Resumo da instalação</h3>
      <!-- ... resumo atual ... -->

      <!-- AVISO DE DESTRUIÇÃO — em vermelho, não pode ser ignorado -->
      <div style="border:1px solid #f38ba8;border-radius:8px;
                  background:#181020;padding:16px;margin:24px 0">
        <div style="color:#f38ba8;font-weight:500;margin-bottom:8px">
          ⚠ ATENÇÃO — Ação irreversível
        </div>
        <div style="color:#cdd6f4;font-size:14px;line-height:1.5;margin-bottom:12px">
          Todos os dados em <strong>${plan?.disk?.target || 'disco selecionado'}</strong>
          serão permanentemente apagados. Esta ação não pode ser desfeita.
        </div>
        <label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-size:14px">
          <input type="checkbox" id="confirm-check"
                 style="width:16px;height:16px;accent-color:#00d4ff">
          Entendo que todos os dados serão apagados e confirmo a instalação
        </label>
      </div>

      <button id="btn-install"
              onclick="startInstall(state.plan)"
              disabled
              style="width:100%;padding:12px;background:transparent;
                     border:1px solid #00d4ff;color:#00d4ff;border-radius:8px;
                     cursor:not-allowed;opacity:0.5;font-size:15px">
        ⟡ Instalar Kryonix
      </button>
    </div>
  `;
}

// Habilitar botão apenas quando checkbox marcado
document.addEventListener('change', (e) => {
  if (e.target.id === 'confirm-check') {
    const btn = document.getElementById('btn-install');
    if (btn) {
      btn.disabled = !e.target.checked;
      btn.style.opacity = e.target.checked ? '1' : '0.5';
      btn.style.cursor  = e.target.checked ? 'pointer' : 'not-allowed';
    }
  }
});
```

### Validação

```bash
grep -qiE 'confirm-check|apagados|irreversível' ui/static/app.js \
  && echo "T22 PASS" || echo "T22 FAIL"
```

---

## FIX 3 — Step indicator com estados (UX)

### Fix em `ui/static/app.js`

```javascript
const STEP_LABELS = [
  'Bem-vindo', 'Hardware', 'Configuração',
  'Usuário', 'Disco', 'Perfil', 'Revisão'
];

function renderStepIndicator() {
  const container = document.getElementById('steps');
  if (!container) return;

  container.innerHTML = STEP_LABELS.map((label, i) => {
    const done    = i < state.step;
    const active  = i === state.step;
    const color   = done   ? '#a6e3a1'
                  : active ? '#00d4ff'
                           : '#45475a';

    return `
      <div onclick="${done ? `goToStep(${i})` : ''}"
           style="display:flex;align-items:center;gap:4px;
                  cursor:${done ? 'pointer' : 'default'};
                  opacity:${active || done ? '1' : '0.4'}">
        <div style="width:20px;height:20px;border-radius:50%;
                    background:${active ? '#00d4ff22' : 'transparent'};
                    border:1px solid ${color};
                    display:flex;align-items:center;justify-content:center;
                    font-size:10px;color:${color}">
          ${done ? '✓' : i + 1}
        </div>
        <span style="font-size:11px;color:${color};display:none" class="step-label-text">
          ${label}
        </span>
      </div>
      ${i < STEP_LABELS.length - 1
        ? `<div style="height:1px;width:20px;background:${done ? '#a6e3a1' : '#45475a'}"></div>`
        : ''}
    `;
  }).join('');
}

function goToStep(n) {
  if (n < state.step) {
    state.step = n;
    renderStep();
    renderStepIndicator();
  }
}
```

---

## FIX 4 — Validação em tempo real (UX)

### Fix nos campos de `renderBasicConfig()` e `renderUser()`

```javascript
function validateHostname(value) {
  if (!value) return 'Nome obrigatório';
  if (!/^[a-z0-9-]+$/.test(value)) return 'Apenas letras minúsculas, números e hífens';
  if (value.length > 63) return 'Máximo 63 caracteres';
  return null;
}

function validateUsername(value) {
  if (!value) return 'Nome de usuário obrigatório';
  if (!/^[a-z][a-z0-9_-]*$/.test(value)) return 'Deve começar com letra; apenas letras minúsculas, números, _ e -';
  return null;
}

// Usar nos campos:
// <input oninput="validateField(this, validateHostname)"
//        id="hostname" placeholder="meu-computador">
// <div id="hostname-error" style="color:#f38ba8;font-size:12px;margin-top:4px"></div>

function validateField(input, validator) {
  const error = validator(input.value);
  const errorEl = document.getElementById(input.id + '-error');
  if (errorEl) errorEl.textContent = error || '';
  input.style.borderColor = error ? '#f38ba8' : (input.value ? '#a6e3a1' : '');
  return !error;
}
```

---

## FIX 5 — Executar bateria de testes

Após os fixes, rodar a bateria completa:

```bash
cd /etc/kryonix/packages/kryonix-installer
cargo test --all -- --nocapture 2>&1 | tail -20

# Backend integration
cargo run -- --port 9999 &
sleep 2

# T01-T10 automatizados (da BATERIA_TESTES.md)
curl -sf http://localhost:9999/health | jq '.status'
curl -sf http://localhost:9999/probe | jq '{cpu: .cpu.model, disks: (.disks | length)}'

# Frontend checks
grep -q 'EventSource' ui/static/app.js && echo "SSE: PASS" || echo "SSE: FAIL"
grep -q 'confirm-check' ui/static/app.js && echo "MODAL: PASS" || echo "MODAL: FAIL"
grep -q 'goToStep' ui/static/app.js && echo "STEPS: PASS" || echo "STEPS: FAIL"
grep -q 'validateHostname' ui/static/app.js && echo "VALIDATION: PASS" || echo "VALIDATION: FAIL"

kill %1 2>/dev/null
```

---

## Commit após todos os fixes

```bash
git -C /etc/kryonix add \
  packages/kryonix-installer/ui/static/app.js \
  packages/kryonix-installer/src/

git -C /etc/kryonix commit -m "fix(installer): frontend UX + segurança

- SSE /install/progress conectado (step 7 funcional)
- Modal confirmação destruição de dados antes de /install
- Checkbox obrigatório para habilitar botão Instalar
- Step indicator: estados done/active/pending + navegação para steps anteriores
- Validação em tempo real: hostname e username com feedback visual"

git -C /etc/kryonix push
```

---

## Regras

1. Fix 1 (SSE) e Fix 2 (modal) são CRÍTICOS — fazer antes dos outros
2. Cargo test deve passar após cada fix antes de commitar
3. Testar o frontend no browser local antes da ISO
4. Não combinar todos os fixes num commit só — um por vez
5. Rodar a bateria de testes completa após todos os fixes
