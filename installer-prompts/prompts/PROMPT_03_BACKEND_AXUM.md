# Prompt: Backend Axum do Instalador — Completar Fase 1 e iniciar Fase 2

> Completar o backend Rust (Axum) do instalador com endpoints reais.
> Fase 1: probe + plan + dry-run funcionando.
> Fase 2: executor de partições via disko (apenas stub seguro por ora).

---

## FASE 1 — Diagnóstico do backend atual

```bash
# Ver estrutura atual
find /etc/kryonix/packages/kryonix-installer/src -name "*.rs" | sort
cat /etc/kryonix/packages/kryonix-installer/src/main.rs

# Compilar e ver erros
cd /etc/kryonix/packages/kryonix-installer
cargo build 2>&1 | tail -20
cargo test  2>&1 | tail -20

# Ver quais endpoints existem
grep -n 'route\|\.get\|\.post\|async fn' \
  /etc/kryonix/packages/kryonix-installer/src/main.rs | head -30
```

---

## FASE 2 — Endpoints obrigatórios

### `GET /health`

```rust
async fn health() -> Json<serde_json::Value> {
    Json(json!({ "status": "ok", "version": env!("CARGO_PKG_VERSION") }))
}
```

### `GET /probe` — Hardware real

```rust
// src/probe.rs
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct HardwareReport {
    pub cpu: CpuInfo,
    pub memory_gb: f32,
    pub disks: Vec<DiskInfo>,
    pub gpu: Vec<GpuInfo>,
    pub boot_mode: String,   // "uefi" | "bios"
    pub network: Vec<NetInfo>,
}

pub fn probe_hardware() -> HardwareReport {
    HardwareReport {
        cpu:       probe_cpu(),
        memory_gb: probe_memory(),
        disks:     probe_disks(),
        gpu:       probe_gpu(),
        boot_mode: probe_boot_mode(),
        network:   probe_network(),
    }
}

fn probe_boot_mode() -> String {
    if std::path::Path::new("/sys/firmware/efi").exists() {
        "uefi".into()
    } else {
        "bios".into()
    }
}

fn probe_disks() -> Vec<DiskInfo> {
    // Ler /sys/block/ + lsblk JSON
    let output = std::process::Command::new("lsblk")
        .args(["-J", "-b", "-o", "NAME,SIZE,TYPE,MODEL,TRAN"])
        .output()
        .expect("lsblk falhou");

    let json: serde_json::Value =
        serde_json::from_slice(&output.stdout).unwrap_or_default();

    // Parsear e filtrar apenas discos (type == "disk")
    json["blockdevices"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter(|d| d["type"].as_str() == Some("disk"))
        .map(|d| DiskInfo {
            path:     format!("/dev/{}", d["name"].as_str().unwrap_or("?")),
            size_gb:  d["size"].as_u64().unwrap_or(0) as f32 / 1_000_000_000.0,
            model:    d["model"].as_str().unwrap_or("Unknown").to_string(),
            kind:     if d["tran"].as_str() == Some("nvme") { "nvme" }
                      else { "sata" }.to_string(),
        })
        .collect()
}
```

### `POST /plan` — Gerar install-plan.json

```rust
// Recebe o request body, valida e retorna o plano
async fn plan(Json(req): Json<InstallRequest>) -> Json<InstallPlan> {
    let plan = InstallPlan {
        version: 1,
        hostname: req.hostname,
        timezone: req.timezone,
        locale: req.locale.unwrap_or_else(|| "pt_BR.UTF-8".into()),
        keyboard: req.keyboard.unwrap_or_else(|| "br-abnt2".into()),
        boot: BootConfig { mode: req.boot.mode },
        disk: DiskConfig {
            mode: "dry-run".into(),   // SEMPRE dry-run até Fase 2
            target: req.disk.target,
            layout: req.disk.layout,
        },
        user: req.user,
        features: req.features,
    };
    Json(plan)
}
```

### `POST /dry-run` — Validar sem executar

```rust
async fn dry_run(Json(plan): Json<InstallPlan>) -> Json<DryRunResult> {
    let mut checks = vec![];
    let mut ok = true;

    // Check: disco existe
    if !std::path::Path::new(&plan.disk.target).exists() {
        checks.push(Check::fail(&format!("Disco {} não encontrado", plan.disk.target)));
        ok = false;
    } else {
        checks.push(Check::ok(&format!("Disco {} encontrado", plan.disk.target)));
    }

    // Check: espaço mínimo (20GB)
    // Check: modo de boot compatível
    // Check: hostname válido (sem espaços, min 1 char)
    // Check: usuário válido

    Json(DryRunResult { ok, checks })
}
```

### `POST /install` — STUB APENAS (Fase 2)

```rust
async fn install() -> (StatusCode, Json<serde_json::Value>) {
    // Fase 2 — não implementado ainda
    (
        StatusCode::NOT_IMPLEMENTED,
        Json(json!({
            "error": "Instalação real ainda não implementada (Fase 2)",
            "hint": "Use /dry-run para validar o plano"
        })),
    )
}
```

---

## FASE 3 — Servir frontend estático

```rust
use tower_http::services::ServeDir;

// Em main():
let frontend_dir = std::env::var("KRYONIX_FRONTEND_DIR")
    .unwrap_or_else(|_| "/share/kryonix-installer/frontend".into());

let app = Router::new()
    .route("/health",   get(health))
    .route("/probe",    get(probe))
    .route("/plan",     post(plan))
    .route("/dry-run",  post(dry_run))
    .route("/install",  post(install))
    .nest_service("/",  ServeDir::new(frontend_dir));
```

---

## FASE 4 — Cargo.toml dependências

```toml
[dependencies]
axum          = "0.7"
tokio         = { version = "1", features = ["full"] }
serde         = { version = "1", features = ["derive"] }
serde_json    = "1"
tower-http    = { version = "0.5", features = ["fs"] }
anyhow        = "1"
tracing       = "0.1"
tracing-subscriber = "0.3"
```

---

## FASE 5 — Testes

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_probe_boot_mode_returns_valid() {
        let mode = probe_boot_mode();
        assert!(mode == "uefi" || mode == "bios");
    }

    #[test]
    fn test_dry_run_rejects_nonexistent_disk() {
        let plan = make_test_plan("/dev/nonexistent999");
        let result = validate_plan(&plan);
        assert!(!result.ok);
        assert!(result.checks.iter().any(|c| !c.ok));
    }

    #[test]
    fn test_install_returns_not_implemented() {
        // Garante que install não executa nada
        // (apenas verifica que retorna 501)
    }
}
```

**Validação:**
```bash
cargo fmt --check
cargo clippy -- -D warnings
cargo test
cargo build --release

# Teste manual
./target/release/kryonix-installer --port 8080 &
curl -s http://localhost:8080/health
curl -s http://localhost:8080/probe | jq '.disks'
curl -s http://localhost:8080/install  # deve retornar 501
```

---

## Commit

```bash
git -C /etc/kryonix/packages/kryonix-installer commit -am \
  "feat(installer): backend Axum completo Fase 1

- GET /health: status + versão
- GET /probe: hardware real (CPU, RAM, discos, GPU, boot mode)
- POST /plan: gera install-plan.json validado
- POST /dry-run: valida sem executar
- POST /install: stub 501 (Fase 2)
- ServeDir: serve frontend estático
- Testes: probe, dry-run, stub install"
```

---

## Regras

1. `/install` DEVE retornar 501 até a Fase 2 estar implementada e testada
2. Backend escuta SOMENTE em 127.0.0.1 — nunca 0.0.0.0
3. `probe_disks()` usa `lsblk --json` — não inventar paths manualmente
4. `DiskConfig.mode` é sempre `"dry-run"` na Fase 1 — hardcoded no backend
5. `cargo test` tem que passar antes de qualquer commit
