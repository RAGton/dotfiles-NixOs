# Prompt: Executor de Partições — Fase 2 do Instalador

> Implementar a execução real do install-plan.json.
> Usa disko para particionamento + nixos-install para o sistema.
> NUNCA executar em hardware sem confirmação explícita do usuário.
> Testar SOMENTE em VM com disco virtual dedicado.

---

## Pré-requisitos (checar antes de implementar)

```bash
# Fase 1 completa e passando em testes?
cd /etc/kryonix/packages/kryonix-installer
cargo test 2>&1 | tail -5
# → todos os testes devem passar

# Disko disponível na ISO?
grep -rn 'disko' /etc/kryonix/hosts/iso/ --include='*.nix' | head -5

# nixos-install disponível?
grep -rn 'nixos-install' /etc/kryonix/hosts/iso/ --include='*.nix' | head -5
```

---

## FASE 1 — Estrutura do executor

```
src/
├── executor/
│   ├── mod.rs          ← orquestrador
│   ├── partition.rs    ← disko wrapper
│   ├── nixos.rs        ← nixos-install wrapper
│   ├── progress.rs     ← SSE progress events
│   └── safety.rs       ← validações de segurança
```

### `safety.rs` — validações ANTES de executar

```rust
// src/executor/safety.rs

pub struct SafetyCheck {
    pub name: String,
    pub passed: bool,
    pub reason: String,
}

pub fn run_safety_checks(plan: &InstallPlan) -> Vec<SafetyCheck> {
    vec![
        check_disk_not_mounted(&plan.disk.target),
        check_disk_not_system(&plan.disk.target),
        check_disk_has_space(&plan.disk.target),
        check_nixos_install_available(),
        check_disko_available(),
        check_network_for_nix(),
    ]
}

fn check_disk_not_system(target: &str) -> SafetyCheck {
    // CRÍTICO: nunca particionar o disco onde o sistema está rodando
    let output = std::process::Command::new("findmnt")
        .args(["--target", "/", "--output", "SOURCE", "--noheadings"])
        .output()
        .expect("findmnt falhou");

    let root_disk = String::from_utf8_lossy(&output.stdout);
    let is_system = root_disk.contains(target.trim_start_matches("/dev/"));

    SafetyCheck {
        name: "disco_nao_e_sistema".into(),
        passed: !is_system,
        reason: if is_system {
            format!("PERIGO: {} é o disco do sistema atual!", target)
        } else {
            format!("{} não é o disco do sistema", target)
        },
    }
}
```

### `partition.rs` — wrapper do disko

```rust
// src/executor/partition.rs

pub struct PartitionResult {
    pub success: bool,
    pub output: String,
    pub error: Option<String>,
}

pub async fn run_disko(
    plan: &InstallPlan,
    tx: tokio::sync::mpsc::Sender<ProgressEvent>,
) -> PartitionResult {
    // Gerar configuração disko temporária a partir do plano
    let disko_config = generate_disko_config(plan);
    let config_path = "/tmp/kryonix-disko-config.nix";

    std::fs::write(config_path, disko_config)
        .expect("Falha ao escrever config disko");

    tx.send(ProgressEvent {
        step: "partition".into(),
        message: format!("Particionando {}...", plan.disk.target),
        percent: 10,
    }).await.ok();

    let result = tokio::process::Command::new("disko")
        .args(["--mode", "disko", config_path])
        .output()
        .await
        .expect("disko falhou");

    PartitionResult {
        success: result.status.success(),
        output:  String::from_utf8_lossy(&result.stdout).into(),
        error:   if !result.status.success() {
            Some(String::from_utf8_lossy(&result.stderr).into())
        } else {
            None
        },
    }
}

fn generate_disko_config(plan: &InstallPlan) -> String {
    // Gerar Nix config do disko baseado no layout escolhido
    match plan.disk.layout.as_str() {
        "btrfs-simple" => generate_btrfs_simple(&plan.disk.target, &plan.boot.mode),
        "lvm-simple"   => generate_lvm_simple(&plan.disk.target, &plan.boot.mode),
        _ => generate_btrfs_simple(&plan.disk.target, &plan.boot.mode),
    }
}

fn generate_btrfs_simple(target: &str, boot_mode: &str) -> String {
    let efi_part = if boot_mode == "uefi" {
        r#"
        esp = {
          size = "512M";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
        };"#
    } else { "" };

    format!(r#"
{{
  disko.devices.disk.main = {{
    type = "disk";
    device = "{}";
    content = {{
      type = "gpt";
      partitions = {{{}
        root = {{
          size = "100%";
          content = {{
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {{
              "@"      = {{ mountpoint = "/"; }};
              "@home"  = {{ mountpoint = "/home"; }};
              "@nix"   = {{ mountpoint = "/nix"; }};
              "@var"   = {{ mountpoint = "/var"; }};
              "@snapshots" = {{ mountpoint = "/.snapshots"; }};
            }};
          }};
        }};
      }};
    }};
  }};
}}
"#, target, efi_part)
}
```

### `nixos.rs` — wrapper do nixos-install

```rust
// src/executor/nixos.rs

pub async fn run_nixos_install(
    plan: &InstallPlan,
    tx: tokio::sync::mpsc::Sender<ProgressEvent>,
) -> Result<(), String> {
    tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Gerando configuração NixOS...".into(),
        percent: 40,
    }).await.ok();

    // Gerar nixos config temporária
    let nixos_config = generate_nixos_config(plan);
    std::fs::create_dir_all("/mnt/etc/nixos").ok();
    std::fs::write("/mnt/etc/nixos/configuration.nix", nixos_config)
        .map_err(|e| e.to_string())?;

    tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Instalando NixOS (pode demorar)...".into(),
        percent: 50,
    }).await.ok();

    let result = tokio::process::Command::new("nixos-install")
        .args([
            "--root", "/mnt",
            "--no-root-password",
            "--flake", &format!("/etc/kryonix#{}", plan.hostname),
        ])
        .output()
        .await
        .map_err(|e| e.to_string())?;

    if result.status.success() {
        tx.send(ProgressEvent {
            step: "done".into(),
            message: "Instalação concluída! Reinicie para usar o Kryonix.".into(),
            percent: 100,
        }).await.ok();
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&result.stderr).into())
    }
}
```

### `progress.rs` — SSE para o frontend

```rust
// src/executor/progress.rs — Server-Sent Events
use axum::response::Sse;

#[derive(serde::Serialize, Clone)]
pub struct ProgressEvent {
    pub step:    String,
    pub message: String,
    pub percent: u8,
}

// Rota: GET /install/progress
// O frontend faz EventSource('/install/progress')
// e recebe atualizações em tempo real
```

---

## FASE 2 — Endpoint /install real

```rust
// Só chamar depois que TODOS os safety checks passarem
async fn install(
    State(state): State<AppState>,
    Json(plan): Json<InstallPlan>,
) -> impl IntoResponse {
    // 1. Safety checks
    let safety = run_safety_checks(&plan);
    if safety.iter().any(|c| !c.passed) {
        return (StatusCode::FORBIDDEN, Json(json!({
            "error": "Safety checks falharam",
            "checks": safety
        }))).into_response();
    }

    // 2. Executar em background, retornar job_id
    let job_id = uuid::Uuid::new_v4().to_string();
    let tx = state.progress_tx.clone();

    tokio::spawn(async move {
        let _ = run_disko(&plan, tx.clone()).await;
        let _ = run_nixos_install(&plan, tx).await;
    });

    (StatusCode::ACCEPTED, Json(json!({ "job_id": job_id }))).into_response()
}
```

---

## FASE 3 — Teste em VM antes de tudo

```bash
# Criar VM de teste com disco vazio (10GB)
qemu-img create -f qcow2 /tmp/test-disk.qcow2 10G

qemu-system-x86_64 \
  -m 4096 \
  -cpu host \
  -enable-kvm \
  -vga virtio \
  -drive file=/tmp/test-disk.qcow2,format=qcow2 \
  -cdrom /tmp/result-iso/iso/*.iso \
  -boot d \
  -display gtk

# Dentro da VM:
# 1. Abrir o instalador no kiosk
# 2. Selecionar /dev/sda como disco alvo
# 3. Completar os steps
# 4. Dry-run primeiro
# 5. Só depois executar install
```

---

## Checklist de segurança

```
[ ] check_disk_not_system() impede particionar disco atual
[ ] /install retorna 403 se safety checks falharem
[ ] disko NUNCA roda sem os safety checks
[ ] nixos-install só roda após disko com sucesso
[ ] Executor NUNCA roda fora de context de ISO (verificar /proc/cmdline)
[ ] Teste em VM com disco virtual ANTES de hardware real
[ ] Botão "Confirmar" no frontend exige checkbox "Entendo que os dados serão apagados"
```

---

## Commit

```bash
git commit -am "feat(installer): Fase 2 — executor partições via disko

- safety.rs: 6 checks antes de qualquer execução
- partition.rs: disko wrapper com btrfs-simple e lvm-simple
- nixos.rs: nixos-install wrapper com progresso
- progress.rs: SSE para atualizações em tempo real
- /install: 403 se safety falhar, 202 + job_id se ok
- Testado em VM com disco virtual 10GB"
```

---

## Regras ABSOLUTAS

1. Safety checks são OBRIGATÓRIOS — sem eles, sem instalação
2. `check_disk_not_system()` é inegociável — nunca remover
3. Testar SOMENTE em VM antes de hardware real
4. `/install` com `mode: dry-run` nunca deve chamar disko real
5. Usuário deve confirmar checkbox no frontend antes do POST /install
6. Nunca fazer `force-push` no repositório do instalador
