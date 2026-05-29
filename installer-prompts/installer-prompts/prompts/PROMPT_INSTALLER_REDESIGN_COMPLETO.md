# Prompt Master: Kryonix Installer — Redesign Completo + Particionamento Avançado

> Reescrever o frontend do instalador com design HUD profissional e expandir
> o backend para suportar multi-disco, particionamento manual e RAID.
> Referência visual: mockup interativo gerado com as abas Discos/Layout/Manual/RAID.
> Zero dependências externas. HTML/CSS/JS puro. Funciona offline na ISO.

---

## FASE 0 — Diagnóstico antes de qualquer edição

```bash
# Estado atual do frontend
find /etc/kryonix/packages/kryonix-installer/ui -type f | sort
wc -l /etc/kryonix/packages/kryonix-installer/ui/static/app.js
wc -l /etc/kryonix/packages/kryonix-installer/ui/static/style.css

# Estado atual do backend
find /etc/kryonix/packages/kryonix-installer/src -name "*.rs" | sort
grep -n 'struct\|fn ' /etc/kryonix/packages/kryonix-installer/src/main.rs | head -30

# Testes passando agora?
cd /etc/kryonix/packages/kryonix-installer
cargo test 2>&1 | tail -5
```

Reportar antes de editar.

---

## PARTE 1 — REDESIGN DO FRONTEND

### 1.1 — Paleta HUD (variáveis CSS — topo do style.css)

```css
:root {
  --bg:      #0a0d12;
  --bg2:     #0f1318;
  --bg3:     #131820;
  --bg4:     #181f28;
  --border:  #1e2d3d;
  --border2: #253545;
  --primary:  #00d4ff;
  --secondary:#82aaff;
  --accent:   #b48eff;
  --text:     #cdd6f4;
  --text2:    #7f8ea3;
  --text3:    #45566a;
  --success:  #a6e3a1;
  --danger:   #f38ba8;
  --warning:  #f9e2af;
  --r:        8px;
  --rlg:      12px;
}

* { box-sizing: border-box; margin: 0; padding: 0;
    font-family: 'JetBrains Mono', 'Courier New', monospace; }

body {
  background: var(--bg);
  color: var(--text);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.shell {
  width: 100vw;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--bg);
  overflow: hidden;
}
```

### 1.2 — Estrutura HTML principal (index.html)

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>⟡ Kryonix Installer</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="shell">

  <!-- Header -->
  <header class="hdr">
    <div class="logo">⟡ KRYONIX <span>installer</span></div>
    <nav class="breadcrumb" id="breadcrumb"></nav>
  </header>

  <!-- Step content -->
  <main class="content" id="content" role="main"></main>

  <!-- Footer navigation -->
  <footer class="ftr">
    <button class="btn btn-ghost" id="btn-back">← Voltar</button>
    <span class="step-info" id="step-info"></span>
    <button class="btn btn-primary" id="btn-next">Próximo →</button>
  </footer>

</div>
<script src="app.js"></script>
</body>
</html>
```

### 1.3 — Sete steps com particionamento expandido

```
Step 0: Bem-vindo
Step 1: Hardware detectado (GET /probe)
Step 2: Configuração básica (hostname, timezone, teclado, locale)
Step 3: Usuário (nome, senha, admin)
Step 4: Particionamento  ←── EXPANDIDO (ver 1.4)
Step 5: Perfil (desktop + features)
Step 6: Revisão + confirmação destruição
Step 7: Instalação com SSE progress
```

### 1.4 — Step 4: Particionamento (ponto central)

O step 4 tem QUATRO abas internas:

#### Aba A — Discos
- Listar todos os discos retornados pelo `/probe`
- Cada disco é um card clicável com:
  - Ícone visual (nvme/sata/usb)
  - Path, modelo, tamanho
  - Mapa visual das partições existentes (barras coloridas)
  - Legenda de partições (tamanho, fs, mountpoint se tiver)
- Múltipla seleção para RAID/LVM

```javascript
function renderDiskMap(disk) {
  // Chamar GET /api/disks/:device/partitions para obter layout
  // Renderizar barra proporcional ao tamanho de cada partição
  // Cores: EFI=#1a3a5c, root=#0d2e1a, home=#1a1a3a, swap=#2e1a0d,
  //        Windows=#2a1a0d, Linux-other=#1a2a1a, livre=var(--bg4)
}
```

#### Aba B — Layout (modo automático)
- Três opções: "Apagar tudo", "Dual boot", "Manual"
- Se "Apagar tudo": mostrar preview do layout que será criado
  - BTRFS: EFI 512MB + / 120GB + /home (resto) + swap 8GB
  - LVM: opcional
- Se "Dual boot": detectar OS existente, mostrar espaço livre disponível

#### Aba C — Particionamento manual
Tabela editável com colunas:
- Dispositivo | Tamanho | FS | Ponto de montagem | Flags | Ações

Cada linha tem:
- Botão "editar" → abre modal com todos os campos
- Botão "✕" → remove (com confirmação se tiver dados)
- Botão "+ Nova partição" no rodapé

Modal de edição/criação:
```
Tamanho: [input] [GB/MB/% do disco]
Sistema de arquivos: [BTRFS / ext4 / XFS / FAT32 / swap / NTFS / não formatar]
Ponto de montagem: [input com autocomplete: /, /home, /boot/efi, /data, /nix, /var]
Flag: [nenhuma / boot,esp / root / home]
Rótulo: [input opcional]
Subvolumes BTRFS: [input — se FS=BTRFS: @,@home,@nix,@var,@snapshots]
```

Validação em tempo real:
- `/` é obrigatório
- `/boot/efi` obrigatório se UEFI
- swap recomendado (warning se ausente)
- tamanho total não pode exceder disco

#### Aba D — RAID / Multi-disco
- Seleção de modo: RAID 0 / RAID 1 / RAID 5 / LVM
- Lista de discos no array (drag ou checkbox)
- Descrição do modo selecionado
- Capacidade efetiva calculada

```javascript
const RAID_MODES = {
  'raid1': { name:'RAID 1', desc:'Espelho — tolera falha de 1 disco', eff: (disks) => Math.min(...disks.map(d=>d.size_gb)) },
  'raid0': { name:'RAID 0', desc:'Stripe — velocidade, sem redundância', eff: (disks) => disks.reduce((a,d)=>a+d.size_gb,0) },
  'raid5': { name:'RAID 5', desc:'Stripe com paridade — min 3 discos', eff: (disks) => (disks.length-1)*Math.min(...disks.map(d=>d.size_gb)) },
  'lvm':   { name:'LVM',    desc:'Volumes lógicos flexíveis', eff: (disks) => disks.reduce((a,d)=>a+d.size_gb,0) },
};
```

### 1.5 — Lockdown de teclado (PRIMEIRO código do app.js)

```javascript
(function() {
  const BLOCK = new Set(['F5','F11','F12']);
  const CTRL  = new Set(['r','R','l','L','w','W','t','T','n','N','u','U']);
  document.addEventListener('keydown', e => {
    if (BLOCK.has(e.key)) { e.preventDefault(); return; }
    if (e.ctrlKey && CTRL.has(e.key)) { e.preventDefault(); return; }
    if (e.key === 'Backspace' && !['INPUT','TEXTAREA'].includes(document.activeElement?.tagName)) {
      e.preventDefault();
    }
  }, true);
  document.addEventListener('contextmenu', e => e.preventDefault(), true);
})();
```

### 1.6 — Step 7: Instalação com SSE

```javascript
async function startInstall(plan) {
  renderProgressScreen();

  // POST /install
  const r = await fetch('/install', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(plan),
  });

  if (r.status === 403) {
    const err = await r.json();
    showSafetyError(err.checks);
    return;
  }

  // Conectar SSE
  const source = new EventSource('/install/progress');
  source.onmessage = e => {
    const evt = JSON.parse(e.data);
    updateProgress(evt);
    if (evt.step === 'done') { source.close(); showSuccess(); }
    if (evt.step === 'error') { source.close(); showError(evt.message); }
  };
  source.onerror = () => { source.close(); showError('Conexão perdida com o backend.'); };
}

function renderProgressScreen() {
  document.getElementById('content').innerHTML = `
    <div class="progress-wrap">
      <div class="prog-icon" id="pi">⟡</div>
      <div class="prog-msg" id="pm">Iniciando...</div>
      <div class="prog-bar-bg">
        <div class="prog-bar-fg" id="pb" style="width:0%"></div>
      </div>
      <div class="prog-pct" id="pp">0%</div>
      <div class="prog-log" id="pl"></div>
    </div>`;
}

function updateProgress({step, message, percent}) {
  document.getElementById('pb').style.width = percent + '%';
  document.getElementById('pm').textContent = message;
  document.getElementById('pp').textContent = percent + '%';
  const log = document.getElementById('pl');
  if (log) {
    const line = document.createElement('div');
    line.className = step === 'error' ? 'log-err' : step === 'done' ? 'log-ok' : 'log-cur';
    line.textContent = (step === 'done' ? '✓ ' : step === 'error' ? '✗ ' : '▸ ') + message;
    log.appendChild(line);
    log.scrollTop = log.scrollHeight;
  }
}
```

---

## PARTE 2 — BACKEND: novos endpoints para particionamento

### 2.1 — GET /api/disks/:device/partitions

Retorna as partições existentes de um disco específico:

```rust
// src/disk.rs — adicionar
pub async fn get_partitions(Path(device): Path<String>) -> Json<serde_json::Value> {
    let target = format!("/dev/{}", device.replace("..", "").replace("/", ""));
    let output = tokio::process::Command::new("lsblk")
        .args(["-J", "-b", "-o", "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,PARTFLAGS", &target])
        .output().await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap_or_default();
    Json(json)
}
```

### 2.2 — POST /plan — expandir para particionamento manual

Adicionar ao `InstallPlan`:

```rust
#[derive(Clone, Serialize, Deserialize)]
pub struct InstallPlan {
  // campos existentes...
  pub partition_mode: String,  // "auto" | "manual" | "raid"
  pub partitions: Option<Vec<PartitionSpec>>,
  pub raid: Option<RaidConfig>,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct PartitionSpec {
  pub device:     String,          // "/dev/nvme0n1"
  pub size_mb:    Option<u64>,     // None = usar resto
  pub filesystem: String,          // "btrfs" | "ext4" | "xfs" | "fat32" | "swap" | "ntfs"
  pub mountpoint: Option<String>,  // "/" | "/home" | "/boot/efi" | None
  pub flags:      Vec<String>,     // ["boot", "esp"] | []
  pub label:      Option<String>,
  pub subvolumes: Vec<String>,     // ["@", "@home", "@nix", "@var"] se btrfs
  pub format:     bool,            // false = manter dados
}

#[derive(Clone, Serialize, Deserialize)]
pub struct RaidConfig {
  pub mode:    String,       // "raid0" | "raid1" | "raid5" | "lvm"
  pub devices: Vec<String>,  // ["/dev/sda", "/dev/sdb"]
}
```

### 2.3 — POST /dry-run — expandir validações

Adicionar checks de particionamento manual:

```rust
// Validações para mode=manual
fn validate_manual_partitions(plan: &InstallPlan) -> Vec<Check> {
    let mut checks = vec![];
    let parts = plan.partitions.as_deref().unwrap_or(&[]);

    let has_root = parts.iter().any(|p| p.mountpoint.as_deref() == Some("/"));
    checks.push(if has_root {
        Check::ok("Partição raiz (/) definida")
    } else {
        Check::fail("Partição raiz (/) obrigatória — não definida")
    });

    if plan.disk.mode != "bios" {
        let has_efi = parts.iter().any(|p|
            p.mountpoint.as_deref() == Some("/boot/efi") &&
            p.filesystem == "fat32"
        );
        checks.push(if has_efi {
            Check::ok("Partição EFI (/boot/efi) FAT32 definida")
        } else {
            Check::fail("Partição EFI (/boot/efi) FAT32 obrigatória para UEFI")
        });
    }

    // Verificar que não há overlap de mountpoints
    let mounts: Vec<_> = parts.iter()
        .filter_map(|p| p.mountpoint.as_ref())
        .collect();
    let unique: std::collections::HashSet<_> = mounts.iter().collect();
    checks.push(if mounts.len() == unique.len() {
        Check::ok("Sem conflito de pontos de montagem")
    } else {
        Check::fail("Ponto de montagem duplicado detectado")
    });

    checks
}
```

### 2.4 — Gerar config disko a partir de partições manuais

Em `src/executor/partition.rs`:

```rust
fn generate_disko_config_manual(plan: &InstallPlan) -> String {
    let parts = plan.partitions.as_deref().unwrap_or(&[]);
    // Gerar o Nix config do disko com as partições exatamente
    // como especificadas pelo usuário
    // Agrupar por device, gerar GPT table com as partiçōes na ordem
    let mut by_device: HashMap<String, Vec<&PartitionSpec>> = HashMap::new();
    for p in parts {
        by_device.entry(p.device.clone()).or_default().push(p);
    }
    // ... gerar Nix config
}
```

---

## PARTE 3 — BATERIA DE TESTES (executar antes do build)

```bash
cd /etc/kryonix/packages/kryonix-installer

# 1. Testes unitários
cargo fmt --check && cargo clippy -- -D warnings
cargo test --all -- --nocapture 2>&1 | grep -E 'PASS|FAIL|error|ok'

# 2. Backend integration
cargo run -- &
BPID=$!; sleep 3

# Novos endpoints
curl -sf http://localhost:8080/api/disks/sda/partitions | jq 'has("blockdevices")' \
  && echo "T-disks PASS" || echo "T-disks FAIL"

# Plan com particionamento manual
curl -sf -X POST http://localhost:8080/plan \
  -H 'Content-Type: application/json' \
  -d '{
    "hostname":"test","timezone":"America/Cuiaba",
    "disk":{"target":"/dev/vda","layout":"manual","mode":"dry-run"},
    "user":{"name":"rocha","admin":true},
    "partition_mode":"manual",
    "partitions":[
      {"device":"/dev/vda","size_mb":512,"filesystem":"fat32","mountpoint":"/boot/efi","flags":["boot","esp"],"subvolumes":[],"format":true,"label":null},
      {"device":"/dev/vda","size_mb":null,"filesystem":"btrfs","mountpoint":"/","flags":[],"subvolumes":["@","@home","@nix"],"format":true,"label":null}
    ]
  }' | jq '.disk.layout' | grep -q '"manual"' && echo "T-plan-manual PASS" || echo "T-plan-manual FAIL"

# Dry-run sem partição raiz deve falhar
curl -sf -X POST http://localhost:8080/dry-run \
  -H 'Content-Type: application/json' \
  -d '{
    "hostname":"test","timezone":"America/Cuiaba",
    "disk":{"target":"/dev/vda","layout":"manual","mode":"dry-run"},
    "user":{"name":"rocha","admin":true},
    "partition_mode":"manual",
    "partitions":[]
  }' | jq '.ok' | grep -q 'false' && echo "T-noroot PASS" || echo "T-noroot FAIL"

# Frontend
grep -q 'EventSource' ui/static/app.js && echo "T-sse PASS" || echo "T-sse FAIL"
grep -q 'confirm-check\|confirm_check\|apagados' ui/static/app.js && echo "T-confirm PASS" || echo "T-confirm FAIL"
grep -q 'contextmenu' ui/static/app.js && echo "T-lockdown PASS" || echo "T-lockdown FAIL"
grep -qiE 'cdn\.|googleapis\.' ui/static/index.html ui/static/app.js && echo "T-nodep FAIL" || echo "T-nodep PASS"

kill $BPID 2>/dev/null

# 3. Build ISO
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  --dry-run 2>&1 | grep -c '^error' | xargs -I{} sh -c '[ "{}" = "0" ] && echo "T-iso-eval PASS" || echo "T-iso-eval FAIL"'
```

---

## PARTE 4 — BUILD E TESTE NA VM

```bash
# Build da ISO
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  -o /tmp/result-iso -L 2>&1 | tail -10

# VM com disco virtual maior (para testar particionamento)
qemu-img create -f qcow2 /tmp/test-disk.qcow2 20G

qemu-system-x86_64 \
  -m 4096 -cpu host -enable-kvm \
  -vga virtio -display gtk \
  -drive file=/tmp/test-disk.qcow2,if=virtio,format=qcow2 \
  -cdrom /tmp/result-iso/iso/*.iso \
  -boot d \
  -machine type=q35  # UEFI firmware
```

### Checklist na VM

```
VISUAL
[ ] Chromium sem barra de abas (--app= ativo)
[ ] Fundo #0a0d12 (escuro profundo)
[ ] Texto ciano #00d4ff nos títulos
[ ] Fonte monospace (JetBrains Mono ou Courier New)
[ ] Breadcrumb no header mostra step atual
[ ] Step indicator com estados done/active/pending

PARTICIONAMENTO
[ ] Aba "Discos" lista /dev/vda (disco virtual 20GB)
[ ] Mapa visual de partições renderiza corretamente
[ ] Aba "Manual" abre tabela de partições editável
[ ] Modal de nova partição tem todos os campos
[ ] Subvolumes BTRFS aparecem quando FS=BTRFS
[ ] Validação: sem partição / → dry-run falha
[ ] Validação: sem EFI (UEFI) → dry-run falha
[ ] RAID: seleção de múltiplos discos funciona

FLUXO COMPLETO
[ ] Step 0 → 6 navega sem erro
[ ] Dry-run passa com particionamento válido
[ ] POST /install retorna 202 (não 501)
[ ] SSE /install/progress mostra log em tempo real
[ ] Barra de progresso avança
[ ] Banner de conclusão aparece
[ ] Disco /dev/vda tem partições criadas pelo disko
```

---

## Commit final

```bash
git -C /etc/kryonix add \
  packages/kryonix-installer/ui/ \
  packages/kryonix-installer/src/

git -C /etc/kryonix commit -m "feat(installer): redesign completo + particionamento avançado

Frontend:
- Redesign HUD completo: fundo #0a0d12, ciano #00d4ff, monospace
- Step 4 expandido: 4 abas (Discos/Layout/Manual/RAID)
- Mapa visual de partições existentes por disco
- Particionamento manual: tabela editável + modal completo
- RAID 0/1/5 e LVM: seleção de discos + capacidade efetiva
- SSE progress no Step 7 com log em tempo real
- Modal de confirmação destruição de dados
- Lockdown de teclado como primeiro código

Backend:
- GET /api/disks/:device/partitions: layout do disco via lsblk
- POST /plan: suporte a partition_mode=manual com PartitionSpec[]
- POST /dry-run: valida /, /boot/efi, sem overlap de mountpoints
- executor/partition.rs: generate_disko_config_manual()
- RaidConfig struct para agregação multi-disco"

git -C /etc/kryonix push
```

---

## Regras absolutas

1. Zero CDN — sem Google Fonts, sem bootstrap, sem cdn.jsdelivr
2. Lockdown de teclado é o PRIMEIRO código do app.js (IIFE)
3. Backend em 127.0.0.1 — nunca 0.0.0.0
4. check_disk_not_system() inegociável — sem bypass
5. dry-run com mode=dry-run nunca chama disko real
6. Modal de confirmação obrigatório antes de POST /install
7. cargo test passa antes de cada commit
8. Testar em VM (não hardware) antes de release
9. Reportar o resultado de cada teste antes de commitar
10. Não misturar múltiplas features num commit — fazer incremental
