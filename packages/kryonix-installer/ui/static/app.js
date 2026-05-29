// ═══════════════════════════════════════════════════════════════
// KIOSK LOCKDOWN — must remain first in this file
// ═══════════════════════════════════════════════════════════════
(function kioskLockdown() {
  'use strict';
  var BLOCKED = { F5: 1, F11: 1 };
  var BLOCKED_CTRL = { r: 1, l: 1, w: 1, t: 1, n: 1, R: 1, L: 1, W: 1, T: 1, N: 1 };

  document.addEventListener('keydown', function (e) {
    if (BLOCKED[e.key]) { e.preventDefault(); return; }
    if (e.key === 'Backspace' &&
        e.target.tagName !== 'INPUT' &&
        e.target.tagName !== 'TEXTAREA') { e.preventDefault(); return; }
    if ((e.ctrlKey || e.metaKey) && BLOCKED_CTRL[e.key]) { e.preventDefault(); }
  }, { capture: true });

  document.addEventListener('contextmenu', function (e) { e.preventDefault(); }, { capture: true });
}());
// ═══════════════════════════════════════════════════════════════

'use strict';

var API = '';  // same origin — backend serves this file

// ── State ────────────────────────────────────────────────────────
var state = {
  step: 0,
  hardware: null,
  disks: null,
  config: {
    hostname: 'kryonix',
    timezone: 'America/Cuiaba',
    keyboard: 'br-abnt2',
    username: '',
    password: '',
    confirmPassword: '',
    diskTarget: null,
    layout: 'btrfs-simple',
  },
  plan: null,
  dryRun: null,
  installStatus: null,
  installPercent: 0,
  installLog: [],
  installDone: false,
  installFailed: false,
};

var STEPS = [
  { title: 'Bem-vindo',    render: renderWelcome  },
  { title: 'Hardware',     render: renderHardware },
  { title: 'Configuração', render: renderConfig   },
  { title: 'Usuário',      render: renderUser     },
  { title: 'Disco',        render: renderDisk     },
  { title: 'Revisão',      render: renderReview   },
  { title: 'Instalação',   render: renderInstall  },
];

// ── DOM helpers ──────────────────────────────────────────────────
function el(id) { return document.getElementById(id); }
function html(id, content) { el(id).innerHTML = content; }

// ── API ──────────────────────────────────────────────────────────
async function apiFetch(path, opts) {
  var res = await fetch(API + path, Object.assign({ cache: 'no-store' }, opts || {}));
  var body = await res.text();
  try { return JSON.parse(body); } catch (_) { return body; }
}

async function apiPost(path, data) {
  return apiFetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

// ── Navigation ───────────────────────────────────────────────────
function updateNav() {
  var nav = el('step-nav');
  nav.innerHTML = STEPS.map(function (_, i) {
    var cls = i < state.step ? 'done' : i === state.step ? 'active' : '';
    return '<div class="step-dot ' + cls + '" title="' + STEPS[i].title + '"></div>';
  }).join('');

  el('step-label').textContent = (state.step + 1) + ' / ' + STEPS.length + ' — ' + STEPS[state.step].title;
  el('btn-back').disabled  = state.step === 0;
  el('btn-next').disabled  = state.step === STEPS.length - 1;
}

async function goTo(i) {
  state.step = Math.max(0, Math.min(STEPS.length - 1, i));
  updateNav();
  html('app', '<div class="loading">Carregando</div>');
  try {
    var content = await STEPS[state.step].render();
    html('app', content || '');
    bindStepEvents();
  } catch (err) {
    html('app', '<div class="banner banner-error">Erro: ' + err.message + '</div>');
  }
}

function bindStepEvents() {
  // hostname
  var h = el('inp-hostname');
  if (h) h.oninput = function () { state.config.hostname = h.value; };

  // timezone
  var tz = el('inp-timezone');
  if (tz) tz.onchange = function () { state.config.timezone = tz.value; };

  // keyboard
  var kb = el('inp-keyboard');
  if (kb) kb.onchange = function () { state.config.keyboard = kb.value; };

  // username
  var u = el('inp-username');
  if (u) u.oninput = function () { state.config.username = u.value; };

  // password
  var p = el('inp-password');
  if (p) p.oninput = function () { state.config.password = p.value; };

  // confirmPassword
  var pc = el('inp-confirm');
  if (pc) pc.oninput = function () { state.config.confirmPassword = pc.value; };

  // layout
  var lay = el('inp-layout');
  if (lay) lay.onchange = function () { state.config.layout = lay.value; };

  // disk rows
  document.querySelectorAll('[data-disk]').forEach(function (row) {
    row.onclick = function () {
      state.config.diskTarget = row.dataset.disk;
      document.querySelectorAll('[data-disk]').forEach(function (r) { r.classList.remove('selected'); });
      row.classList.add('selected');
    };
  });

  // action buttons
  var btnPlan = el('btn-generate-plan');
  if (btnPlan) btnPlan.onclick = doGeneratePlan;

  var btnDry = el('btn-dry-run');
  if (btnDry) btnDry.onclick = doDryRun;

  var btnInstall = el('btn-start-install');
  if (btnInstall) btnInstall.onclick = doInstall;
}

// ── Step 0: Welcome ──────────────────────────────────────────────
function renderWelcome() {
  return '<div class="welcome-hero">' +
    '<div class="logo-big">⟡ KRYONIX</div>' +
    '<p>Instalador do sistema operacional Kryonix.<br>' +
    'Siga as etapas para configurar e instalar o sistema.</p>' +
    '<button class="btn btn-primary" onclick="goTo(1)">Começar →</button>' +
    '</div>';
}

// ── Step 1: Hardware ─────────────────────────────────────────────
async function renderHardware() {
  if (!state.hardware) {
    state.hardware = await apiFetch('/probe');
  }

  var hw = state.hardware;
  if (!hw || hw.error) {
    return '<div class="banner banner-error">Falha ao ler hardware: ' + (hw && hw.error || 'sem resposta') + '</div>';
  }

  var gpu = hw.gpu && hw.gpu.length
    ? hw.gpu.map(function (g) { return g.vendor + ' ' + g.model; }).join(', ')
    : 'Não detectada';

  var disks = hw.disks && hw.disks.length
    ? hw.disks.map(function (d) { return d.path + ' (' + d.size_gb.toFixed(0) + ' GB, ' + d.kind + ')'; }).join(', ')
    : 'Nenhum disco detectado';

  var nets = hw.network && hw.network.length
    ? hw.network.map(function (n) { return n.name; }).join(', ')
    : 'Nenhuma interface';

  var virt = hw.virtualized ? '<div class="hw-card"><div class="hw-card-label">Ambiente</div><div class="hw-card-value">' + hw.virtualized + '</div></div>' : '';

  return '<h1 class="step-title">Hardware detectado</h1>' +
    '<p class="step-sub">Dados reais via kryonix-hardware-probe.</p>' +
    '<div class="hw-grid">' +
    '<div class="hw-card"><div class="hw-card-label">CPU</div><div class="hw-card-value">' + hw.cpu.model + '</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">Cores / Threads</div><div class="hw-card-value">' + hw.cpu.cores + ' / ' + hw.cpu.threads + ' (' + hw.cpu.arch + ')</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">RAM</div><div class="hw-card-value">' + hw.memory_gb.toFixed(1) + ' GB</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">Boot</div><div class="hw-card-value">' + hw.boot_mode.toUpperCase() + '</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">GPU</div><div class="hw-card-value">' + gpu + '</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">Discos</div><div class="hw-card-value">' + disks + '</div></div>' +
    '<div class="hw-card"><div class="hw-card-label">Rede</div><div class="hw-card-value">' + nets + '</div></div>' +
    virt +
    '</div>';
}

// ── Step 2: Basic config ─────────────────────────────────────────
function renderConfig() {
  var timezones = ['America/Cuiaba','America/Sao_Paulo','America/Manaus',
                   'America/Belem','America/Fortaleza','America/Recife',
                   'America/Maceio','America/Bahia','America/Noronha',
                   'UTC'];
  var keyboards = [
    { v: 'br-abnt2', l: 'Português (ABNT2)' },
    { v: 'us',       l: 'Inglês (US QWERTY)' },
    { v: 'us-intl',  l: 'Inglês Internacional' },
  ];

  return '<h1 class="step-title">Configuração básica</h1>' +
    '<p class="step-sub">Idioma, fuso horário e teclado.</p>' +
    '<div class="field"><label>Hostname</label>' +
    '<input id="inp-hostname" type="text" value="' + esc(state.config.hostname) + '" maxlength="63" spellcheck="false"></div>' +
    '<div class="field"><label>Fuso horário</label><select id="inp-timezone">' +
    timezones.map(function (tz) {
      return '<option value="' + tz + '"' + (tz === state.config.timezone ? ' selected' : '') + '>' + tz + '</option>';
    }).join('') + '</select></div>' +
    '<div class="field"><label>Layout de teclado</label><select id="inp-keyboard">' +
    keyboards.map(function (kb) {
      return '<option value="' + kb.v + '"' + (kb.v === state.config.keyboard ? ' selected' : '') + '>' + kb.l + '</option>';
    }).join('') + '</select></div>';
}

// ── Step 3: User ─────────────────────────────────────────────────
function renderUser() {
  return '<h1 class="step-title">Conta de usuário</h1>' +
    '<p class="step-sub">Será criado com acesso sudo.</p>' +
    '<div class="field"><label>Nome de usuário</label>' +
    '<input id="inp-username" type="text" value="' + esc(state.config.username) + '" spellcheck="false" autocomplete="off"></div>' +
    '<div class="field"><label>Senha</label>' +
    '<input id="inp-password" type="password" value="' + esc(state.config.password) + '" autocomplete="new-password"></div>' +
    '<div class="field"><label>Confirmar senha</label>' +
    '<input id="inp-confirm" type="password" value="' + esc(state.config.confirmPassword) + '" autocomplete="new-password"></div>';
}

// ── Step 4: Disk ─────────────────────────────────────────────────
async function renderDisk() {
  if (!state.disks) {
    var res = await apiFetch('/api/disks');
    state.disks = Array.isArray(res) ? res : [];
  }

  var layouts = [
    { v: 'btrfs-simple',   l: 'Btrfs simples (root + boot)' },
    { v: 'btrfs-home-var', l: 'Btrfs com @home e @var separados' },
    { v: 'lvm-simple',     l: 'LVM simples' },
  ];

  var rows = state.disks.map(function (d) {
    var sel = state.config.diskTarget === ('/dev/' + d.name) ? ' selected' : '';
    var size = d.size ? (parseInt(d.size, 10) / 1e9).toFixed(0) + ' GB' : '?';
    return '<tr data-disk="/dev/' + esc(d.name) + '"' + (sel ? ' class="selected"' : '') + '>' +
      '<td>/dev/' + esc(d.name) + '</td>' +
      '<td>' + esc(d.model || '—') + '</td>' +
      '<td>' + size + '</td>' +
      '<td>' + esc(d.type || '—') + '</td>' +
      '</tr>';
  }).join('');

  if (!rows) rows = '<tr><td colspan="4" style="color:var(--text-dim);text-align:center">Nenhum disco encontrado</td></tr>';

  return '<h1 class="step-title">Disco de destino</h1>' +
    '<div class="banner banner-error">⚠ ATENÇÃO: o disco selecionado será completamente apagado.</div>' +
    '<table class="disk-table"><thead><tr><th>Dispositivo</th><th>Modelo</th><th>Tamanho</th><th>Tipo</th></tr></thead>' +
    '<tbody>' + rows + '</tbody></table>' +
    '<div class="field" style="margin-top:20px"><label>Layout de partição</label><select id="inp-layout">' +
    layouts.map(function (l) {
      return '<option value="' + l.v + '"' + (l.v === state.config.layout ? ' selected' : '') + '>' + l.l + '</option>';
    }).join('') + '</select></div>';
}

// ── Step 5: Review ───────────────────────────────────────────────
async function renderReview() {
  var hw = state.hardware || {};
  var nvidia = hw.gpu && hw.gpu.some(function (g) { return g.vendor === 'nvidia'; });

  var planHtml = state.plan
    ? '<div class="plan-box">' + esc(JSON.stringify(state.plan, null, 2)) + '</div>'
    : '<p style="color:var(--text-dim)">Clique em "Gerar Plano" para ver o install-plan.json.</p>';

  var dryHtml = '';
  if (state.dryRun) {
    var checks = state.dryRun.checks.map(function (c) {
      return '<li class="' + (c.ok ? 'check-ok' : 'check-fail') + '">' +
        (c.ok ? '✓' : '✗') + ' ' + esc(c.message) + '</li>';
    }).join('');
    dryHtml = '<h2 style="font-size:1rem;color:var(--text-dim);margin:20px 0 8px">Resultado do Dry Run</h2>' +
      '<div class="banner ' + (state.dryRun.ok ? 'banner-success' : 'banner-error') + '">' +
      (state.dryRun.ok ? '✓ Plano válido — pronto para instalar' : '✗ Erros encontrados no plano') + '</div>' +
      '<ul class="checks">' + checks + '</ul>';
  }

  return '<h1 class="step-title">Revisão</h1>' +
    '<p class="step-sub">Verifique o plano antes de instalar.</p>' +
    '<div style="display:flex;gap:12px;margin-bottom:20px">' +
    '<button id="btn-generate-plan" class="btn btn-primary">Gerar Plano</button>' +
    '<button id="btn-dry-run" class="btn btn-secondary"' + (state.plan ? '' : ' disabled') + '>Dry Run</button>' +
    '</div>' +
    planHtml + dryHtml;
}

async function doGeneratePlan() {
  var hw = state.hardware || {};
  var nvidia = hw.gpu && hw.gpu.some(function (g) { return g.vendor === 'nvidia'; });

  el('btn-generate-plan').disabled = true;
  el('btn-generate-plan').textContent = 'Gerando…';

  try {
    state.plan = await apiPost('/plan', {
      hostname: state.config.hostname,
      timezone: state.config.timezone,
      keyboard: state.config.keyboard,
      disk: { target: state.config.diskTarget || '/dev/sda', layout: state.config.layout },
      user: { name: state.config.username || 'admin', admin: true },
      features: {
        desktop: 'hyprland-caelestia',
        nvidia:  nvidia ? 'auto' : 'none',
        zram:    true,
      },
    });
    state.dryRun = null;
    goTo(5);
  } catch (err) {
    el('btn-generate-plan').disabled = false;
    el('btn-generate-plan').textContent = 'Gerar Plano';
    html('app', (await renderReview()) + '<div class="banner banner-error">Erro: ' + esc(err.message) + '</div>');
    bindStepEvents();
  }
}

async function doDryRun() {
  if (!state.plan) return;
  el('btn-dry-run').disabled = true;
  el('btn-dry-run').textContent = 'Validando…';

  try {
    state.dryRun = await apiPost('/dry-run', state.plan);
    goTo(5);
  } catch (err) {
    el('btn-dry-run').disabled = false;
    el('btn-dry-run').textContent = 'Dry Run';
  }
}

// ── Step 6: Install ──────────────────────────────────────────────
function renderInstall() {
  var dryOk     = state.dryRun && state.dryRun.ok;
  var isRunning = state.installPercent > 0 && state.installPercent < 100 && !state.installFailed && !state.installDone;
  var canStart  = dryOk && !isRunning && !state.installDone;
  var btnLabel  = isRunning ? '⏳ Instalando…' : '⚡ Iniciar Instalação';

  var bannerClass, bannerText;
  if (state.installDone) {
    bannerClass = 'banner-success'; bannerText = '✓ Instalação concluída! Reinicie o sistema.';
  } else if (state.installFailed) {
    bannerClass = 'banner-error';   bannerText = '✗ Instalação falhou — veja o log abaixo.';
  } else if (dryOk) {
    bannerClass = 'banner-success'; bannerText = '✓ Dry run passou — pronto para instalar.';
  } else {
    bannerClass = 'banner-warning'; bannerText = '⚠ Execute o Dry Run antes de instalar.';
  }

  var progressHtml = '';
  if (state.installPercent > 0) {
    progressHtml =
      '<div style="margin:12px 0;background:rgba(255,255,255,.08);border-radius:6px;overflow:hidden">' +
        '<div id="install-progress-bar" style="height:8px;width:' + state.installPercent + '%;' +
        'background:#4ade80;transition:width .4s ease"></div>' +
      '</div>' +
      '<div id="install-progress-pct" style="font-size:.8rem;color:var(--text-dim);margin-bottom:12px">' +
      state.installPercent + '%</div>';
  } else {
    progressHtml =
      '<div style="margin:12px 0;background:rgba(255,255,255,.08);border-radius:6px;overflow:hidden">' +
        '<div id="install-progress-bar" style="height:8px;width:0%;background:#4ade80;transition:width .4s ease"></div>' +
      '</div>' +
      '<div id="install-progress-pct" style="font-size:.8rem;color:var(--text-dim);margin-bottom:12px">0%</div>';
  }

  var logHtml = state.installLog.length
    ? '<div id="install-log" class="install-log">' + esc(state.installLog.join('\n')) + '</div>'
    : '<div id="install-log" class="install-log" style="display:none"></div>';

  return '<h1 class="step-title">Instalação</h1>' +
    '<p class="step-sub">Esta etapa apaga o disco selecionado. Ação irreversível.</p>' +
    '<div id="install-banner" class="banner ' + bannerClass + '">' + bannerText + '</div>' +
    '<button id="btn-start-install" class="btn btn-danger"' + (canStart ? '' : ' disabled') + '>' + btnLabel + '</button>' +
    progressHtml + logHtml;
}

// Update install UI elements in-place — no full re-render needed.
function updateInstallUI() {
  var bar    = el('install-progress-bar');
  var pct    = el('install-progress-pct');
  var log    = el('install-log');
  var banner = el('install-banner');
  var btn    = el('btn-start-install');

  if (bar) bar.style.width = state.installPercent + '%';
  if (pct) pct.textContent = state.installPercent + '%';
  if (log) {
    log.style.display = state.installLog.length ? '' : 'none';
    log.textContent = state.installLog.join('\n');
    log.scrollTop = log.scrollHeight;
  }
  if (banner) {
    if (state.installDone) {
      banner.className = 'banner banner-success';
      banner.textContent = '✓ Instalação concluída! Reinicie o sistema.';
    } else if (state.installFailed) {
      banner.className = 'banner banner-error';
      banner.textContent = '✗ Instalação falhou — veja o log abaixo.';
    }
  }
  if (btn && (state.installDone || state.installFailed)) {
    btn.disabled = true;
    btn.textContent = state.installDone ? '✓ Concluído' : '✗ Falhou';
  }
}

async function doInstall() {
  if (!state.plan) return;

  // Override mode — plan from /plan always returns "dry-run"
  var installPlan = Object.assign({}, state.plan, {
    disk: Object.assign({}, state.plan.disk, { mode: 'install' }),
  });

  el('btn-start-install').disabled = true;
  el('btn-start-install').textContent = '⏳ Enviando…';

  var res;
  try {
    res = await fetch('/install', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(installPlan),
      cache: 'no-store',
    });
  } catch (err) {
    state.installFailed = true;
    state.installLog = ['[ERRO] Falha de rede: ' + err.message];
    updateInstallUI();
    return;
  }

  var body;
  try { body = JSON.parse(await res.clone().text()); } catch (_) { body = null; }

  if (res.status === 403) {
    // Safety checks failed — show which checks failed
    state.installFailed = true;
    var checks = (body && body.checks) ? body.checks : [];
    state.installLog = ['[ERRO] Safety checks falharam:']
      .concat(checks.map(function (c) {
        return (c.passed ? '  ✓ ' : '  ✗ ') + c.name + ': ' + c.reason;
      }));
    if (!checks.length && body && body.error) state.installLog.push('  ' + body.error);
    updateInstallUI();
    return;
  }

  if (!res.ok || !body || !body.job_id) {
    state.installFailed = true;
    state.installLog = ['[ERRO] Resposta inesperada do backend:', JSON.stringify(body)];
    updateInstallUI();
    return;
  }

  // 202 Accepted — connect SSE progress stream
  state.installPercent = 5;
  state.installLog = ['[INFO] Instalação iniciada (job: ' + body.job_id + ')'];
  updateInstallUI();

  var source = new EventSource('/install/progress');

  source.onmessage = function (event) {
    var evt;
    try { evt = JSON.parse(event.data); } catch (_) {
      state.installLog.push(event.data);
      updateInstallUI();
      return;
    }
    state.installPercent = evt.percent || state.installPercent;
    state.installLog.push('[' + evt.step.toUpperCase() + '] ' + evt.message);

    if (evt.step === 'done') {
      state.installDone = true;
      state.installPercent = 100;
      source.close();
    } else if (evt.step === 'error') {
      state.installFailed = true;
      source.close();
    }
    updateInstallUI();
  };

  source.onerror = function () {
    if (!state.installDone) {
      state.installLog.push('[ERRO] Conexão SSE perdida');
      state.installFailed = true;
      source.close();
      updateInstallUI();
    }
  };
}

// ── Utility ──────────────────────────────────────────────────────
function esc(str) {
  return String(str == null ? '' : str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Boot ─────────────────────────────────────────────────────────
el('btn-back').onclick = function () { goTo(state.step - 1); };
el('btn-next').onclick = function () { goTo(state.step + 1); };

goTo(0);
