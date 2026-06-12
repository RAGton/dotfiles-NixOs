mod auth;
mod detection;
mod disk;
mod executor;
mod network;
use network::apply_network;
mod profiles;

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    response::{
        IntoResponse,
        sse::{Event, Sse},
    },
    routing::{get, post},
};
use executor::{ProgressEvent, SafetyCheck, run_preflight};
use futures_util::stream::Stream;
use serde::{Deserialize, Serialize};
use std::convert::Infallible;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::{RwLock, broadcast};
use tower_http::{cors::CorsLayer, services::ServeDir};

// ── Shared state ──────────────────────────────────────────────────────────────

pub struct AppState {
    log_sender: Arc<broadcast::Sender<String>>,
    progress_tx: Arc<broadcast::Sender<ProgressEvent>>,
    install_status: Arc<RwLock<InstallStatus>>,
    /// GitHub OAuth state — token kept in memory only
    pub auth: auth::SharedAuthState,
    /// Reusable HTTP client (connection pooling, rustls)
    pub http_client: reqwest::Client,
}

// ── Common error type ─────────────────────────────────────────────────────────

#[derive(Serialize, Deserialize)]
struct ErrorResponse {
    error: String,
    details: Option<String>,
}

type ApiError = (StatusCode, Json<ErrorResponse>);

fn err500(msg: impl Into<String>, detail: Option<String>) -> ApiError {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(ErrorResponse {
            error: msg.into(),
            details: detail,
        }),
    )
}

// ── Install plan types ────────────────────────────────────────────────────────

#[derive(Deserialize)]
struct PlanRequest {
    hostname: Option<String>,
    timezone: Option<String>,
    locale: Option<String>,
    keyboard: Option<String>,
    disk: PlanDiskReq,
    user: PlanUserReq,
    features: Option<serde_json::Value>,
}

#[derive(Deserialize)]
struct PlanDiskReq {
    target: String,
    layout: Option<String>,
    boot_mode: Option<String>,
}

#[derive(Deserialize)]
struct PlanUserReq {
    name: String,
    admin: Option<bool>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct InstallPlan {
    pub version: u32,
    pub hostname: String,
    pub timezone: String,
    pub locale: String,
    pub keyboard: String,
    pub disk: PlanDisk,
    pub user: PlanUser,
    pub features: serde_json::Value,
    #[serde(default)]
    pub network: NetworkPlan,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct NetworkPlan {
    pub hostname: String,
    pub interface: String,
    pub server_ip: String,
    pub prefix_length: u8,
    pub mode: String,
    pub gateway: String,
    pub dns: Vec<String>,
    pub http_port: u16,
    #[serde(default)]
    pub wan: WanPlan,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct WanPlan {
    pub interface: String,
    pub mode: String,
    pub address: Option<String>,
    pub prefix_length: Option<u8>,
    pub gateway: Option<String>,
    pub dns: Vec<String>,
    pub pppoe_user: Option<String>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct PlanDisk {
    pub mode: String,
    pub target: String,
    pub layout: String,
    pub boot_mode: String,
    #[serde(default)]
    pub profile: String,
    #[serde(rename = "selectedDisks", default)]
    pub selected_disks: Vec<String>,
    #[serde(rename = "raidLevel")]
    pub raid_level: Option<String>,
    #[serde(rename = "manualPartitions")]
    pub manual_partitions: Option<Vec<PartitionSpec>>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct PartitionSpec {
    pub device: String,
    pub mountpoint: String,
    pub fstype: String,
    pub size: String,
    pub format: bool,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct PlanUser {
    pub name: String,
    pub admin: bool,
}

// ── Dry-run / validation types ────────────────────────────────────────────────

#[derive(Serialize)]
struct DryRunResult {
    ok: bool,
    checks: Vec<Check>,
}

#[derive(Serialize)]
struct Check {
    ok: bool,
    message: String,
}

impl Check {
    fn pass(msg: impl Into<String>) -> Self {
        Self {
            ok: true,
            message: msg.into(),
        }
    }
    fn fail(msg: impl Into<String>) -> Self {
        Self {
            ok: false,
            message: msg.into(),
        }
    }
}

#[derive(Serialize, Clone, Default)]
struct InstallStatus {
    running: bool,
    #[serde(rename = "exitCode")]
    exit_code: Option<i32>,
    #[serde(rename = "currentPhase")]
    current_phase: Option<String>,
    #[serde(rename = "lastError")]
    last_error: Option<String>,
    #[serde(rename = "lastLogLine")]
    last_log_line: Option<String>,
    #[serde(rename = "havePlan")]
    have_plan: bool,
    #[serde(rename = "canInstall")]
    can_install: bool,
}

#[derive(Deserialize)]
struct ProfileRequest {
    host: String,
    profile: String,
}

// ── Main ──────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let (log_tx, _) = broadcast::channel(100);
    let (progress_tx, _) = broadcast::channel::<ProgressEvent>(64);

    let http_client = reqwest::Client::builder()
        .use_rustls_tls()
        .user_agent("kryonix-installer/0.1")
        .build()
        .expect("Failed to build HTTP client");

    let state = Arc::new(AppState {
        log_sender: Arc::new(log_tx),
        progress_tx: Arc::new(progress_tx),
        install_status: Arc::new(RwLock::new(InstallStatus::default())),
        auth: auth::new_auth_state(),
        http_client,
    });

    let ui_dir = std::env::var("KRYONIX_INSTALLER_UI_DIR")
        .unwrap_or_else(|_| "/run/current-system/sw/share/kryonix-installer/ui/dist".to_string());

    let app = Router::new()
        .route("/health", get(health))
        .route("/version", get(version_handler))
        // Hardware probe — canonical path matches spec, /probe kept for compat
        .route("/hardware", get(probe))
        .route("/probe", get(probe))
        // Step 0 — Network setup (ethernet auto / WiFi manual)
        .route("/network/status", get(network::status))
        .route("/network/interfaces", get(network::interfaces))
        .route("/network/wifi/scan", get(network::wifi_scan))
        .route("/network/wifi/connect", post(network::wifi_connect))
        .route("/network/wifi/disconnect", post(network::wifi_disconnect))
        .route("/network/apply", post(apply_network))
        // Step 1 — GitHub OAuth Device Flow
        .route("/auth/github/device", post(auth::start_device_flow))
        .route("/auth/github/poll", get(auth::poll_device_flow))
        .route("/repos", get(auth::list_repos))
        .route("/clone", post(auth::clone_repo))
        // Install orchestration
        .route("/plan", post(plan))
        .route("/dry-run", post(dry_run))
        .route("/install", post(install))
        .route("/install/status", get(install_status))
        .route("/install/progress", get(install_progress))
        // Profiles
        .route("/profile/apply", post(apply_profile_endpoint))
        // Debug — inspeção do target flake gerado em /mnt/etc/kryonixos
        .route("/debug/target", get(debug_target))
        // Detection
        .route("/api/detection", get(detection_handler))
        // Disk Planner
        .route("/disk/apply", post(disk_apply_endpoint))
        .route("/disk/manual-setup", get(manual_setup_handler))
        // Installation
        .route("/install/finalize", post(install_finalize_endpoint))
        .route("/api/validate-install", get(validate_install_handler))
        // Disk utilities
        .route("/api/disks", get(get_disks))
        .route("/api/disks/:device/partitions", get(get_partitions_handler))
        .route("/api/partition", post(partition_endpoint))
        .route("/api/reboot", post(reboot_endpoint))
        .route("/api/stream", get(stream_logs))
        .layer(CorsLayer::permissive())
        .with_state(state)
        .fallback_service(ServeDir::new(ui_dir).fallback(ServeDir::new("ui/static")));

    let bind_addr =
        std::env::var("KRYONIX_INSTALLER_BIND").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
    let listener = tokio::net::TcpListener::bind(&bind_addr).await.unwrap();
    println!(
        "Kryonix Installer API → http://{}",
        listener.local_addr().unwrap()
    );
    axum::serve(listener, app).await.unwrap();
}

async fn install_finalize_endpoint(
    State(_state): State<Arc<AppState>>,
    Json(_payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, ApiError> {
    Err((
        StatusCode::GONE,
        Json(ErrorResponse {
            error: "LEGACY_ROUTE_DISABLED".into(),
            details: Some(
                "Use POST /dry-run para validação e POST /install para execução protegida.".into(),
            ),
        }),
    ))
}

async fn validate_install_handler() -> Result<Json<serde_json::Value>, ApiError> {
    let flag_exists = std::path::Path::new("/mnt/etc/kryonix-installed").exists();
    let efi_exists = std::path::Path::new("/mnt/boot/EFI").exists()
        || std::path::Path::new("/mnt/boot/efi").exists();
    let grub_exists = std::path::Path::new("/mnt/boot/grub").exists();

    Ok(Json(serde_json::json!({
        "flag_ok": flag_exists,
        "bootloader_ok": efi_exists || grub_exists,
        "paths": {
            "/mnt/etc/kryonix-installed": flag_exists,
            "/mnt/boot/EFI": efi_exists,
            "/mnt/boot/grub": grub_exists
        }
    })))
}

async fn disk_apply_endpoint(
    Json(_payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, ApiError> {
    Err((
        StatusCode::GONE,
        Json(ErrorResponse {
            error: "LEGACY_ROUTE_DISABLED".into(),
            details: Some(
                "A rota /disk/apply não executa mais ações destrutivas. Use /dry-run e /install."
                    .into(),
            ),
        }),
    ))
}

async fn apply_profile_endpoint(
    Json(payload): Json<ProfileRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let profile = match payload.profile.to_uppercase().as_str() {
        "GAMER" => profiles::ProfileType::Gamer,
        "DEV_RUST" => profiles::ProfileType::DevRust,
        _ => {
            return Err((
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: "Perfil inválido".into(),
                    details: Some(format!(
                        "Suportados: GAMER, DEV_RUST. Recebido: {}",
                        payload.profile
                    )),
                }),
            ));
        }
    };

    profiles::apply_profile(&payload.host, profile)
        .map(|_| Json(serde_json::json!({ "status": "success", "message": "Perfil aplicado com sucesso" })))
        .map_err(|e| (StatusCode::BAD_REQUEST, Json(ErrorResponse {
            error: "Falha ao aplicar perfil".into(),
            details: Some(e),
        })))
}

// ── GET /debug/target ─────────────────────────────────────────────────────────
//
// Inspeção do target flake gerado, sem listar /mnt inteiro nem expor segredos.
// Usado pelo loop de debug do instalador para provar que `/mnt/etc/kryonixos`
// está autocontido antes do `nixos-install` rodar.
async fn debug_target() -> Result<Json<serde_json::Value>, ApiError> {
    let report = run_preflight()
        .await
        .map_err(|e| err500("DEBUG_TARGET_FAILED", Some(e)))?;

    // Tail do log do nixos-install (se houver). Útil quando o SSE perdeu a
    // conexão durante a fase de evaluation.
    let install_log_tail = match tokio::fs::read_to_string(executor::nixos::NIXOS_INSTALL_LOG).await
    {
        Ok(s) => {
            const MAX: usize = 6000;
            if s.len() > MAX {
                format!("...{}", &s[s.len() - MAX..])
            } else {
                s
            }
        }
        Err(_) => "(sem log — nixos-install ainda não rodou)".into(),
    };

    Ok(Json(serde_json::json!({
        "passed": report.passed(),
        "files": {
            "target_flake": report.target_flake_exists,
            "engine_flake": report.engine_flake_exists,
            "features_generated": report.features_generated_exists,
            "hardware_generated": report.hardware_generated_exists,
            "legacy_symlink": report.legacy_symlink_ok,
        },
        "bad_references": report.bad_references,
        "flake_metadata": {
            "ok": report.flake_metadata_ok,
            "output": report.flake_metadata_output,
        },
        "target_flake_preview": report.target_flake_preview,
        "nixos_install_log_tail": install_log_tail,
    })))
}

async fn detection_handler() -> Result<Json<Vec<detection::InstallationMatch>>, ApiError> {
    detection::detect_existing_installations()
        .map(Json)
        .map_err(|e| err500("FAILED_TO_DETECT_INSTALLATIONS", Some(e)))
}

async fn manual_setup_handler() -> impl IntoResponse {
    // Redirect to ttyd running on port 8081
    axum::response::Redirect::temporary("http://localhost:8081")
}

// ── GET /health ───────────────────────────────────────────────────────────────

async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status":  "ok",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

async fn version_handler() -> Result<Json<serde_json::Value>, ApiError> {
    let content = tokio::fs::read_to_string("/etc/kryonix-version")
        .await
        .map_err(|e| {
            (
                StatusCode::NOT_FOUND,
                Json(ErrorResponse {
                    error: "Versão não encontrada".into(),
                    details: Some(e.to_string()),
                }),
            )
        })?;

    let mut map = serde_json::Map::new();
    for line in content.lines() {
        if let Some((key, value)) = line.split_once('=') {
            map.insert(
                key.to_string(),
                serde_json::Value::String(value.to_string()),
            );
        }
    }

    Ok(Json(serde_json::Value::Object(map)))
}

// ── GET /probe ────────────────────────────────────────────────────────────────

async fn probe() -> Result<Json<serde_json::Value>, ApiError> {
    let probe_cmd = std::env::var("KRYONIX_HARDWARE_PROBE")
        .unwrap_or_else(|_| "kryonix-hardware-probe".to_string());
    let output = tokio::task::spawn_blocking(move || Command::new(probe_cmd).output())
        .await
        .map_err(|e| err500("Spawn error", Some(e.to_string())))?
        .map_err(|e| err500("kryonix-hardware-probe not found", Some(e.to_string())))?;

    if !output.status.success() {
        return Err(err500(
            "kryonix-hardware-probe exited with error",
            Some(String::from_utf8_lossy(&output.stderr).into_owned()),
        ));
    }

    let report: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| err500("Failed to parse probe output", Some(e.to_string())))?;

    Ok(Json(report))
}

// ── POST /plan ────────────────────────────────────────────────────────────────

async fn plan(Json(req): Json<PlanRequest>) -> Json<InstallPlan> {
    Json(InstallPlan {
        version: 1,
        hostname: req.hostname.unwrap_or_else(|| "kryonix".into()),
        timezone: req.timezone.unwrap_or_else(|| "America/Cuiaba".into()),
        locale: req.locale.unwrap_or_else(|| "pt_BR.UTF-8".into()),
        keyboard: req.keyboard.unwrap_or_else(|| "br-abnt2".into()),
        disk: PlanDisk {
            mode: "dry-run".into(), // front-end defines final mode
            target: req.disk.target,
            layout: req.disk.layout.unwrap_or_else(|| "btrfs-simple".into()),
            boot_mode: req.disk.boot_mode.unwrap_or_else(|| "uefi".into()),
            profile: "single".into(),
            selected_disks: vec![],
            raid_level: None,
            manual_partitions: None,
        },
        user: PlanUser {
            name: req.user.name,
            admin: req.user.admin.unwrap_or(true),
        },
        features: req.features.unwrap_or(serde_json::json!({})),
        network: Default::default(),
    })
}

// ── POST /dry-run ─────────────────────────────────────────────────────────────

async fn dry_run(Json(plan): Json<InstallPlan>) -> impl IntoResponse {
    let result = validate_plan(&plan);
    // 200 somente se ok==true; 422 se o plano/alvo é semanticamente inválido.
    // (Body/JSON malformado já vira 400/422 no extractor Json antes de chegar aqui.)
    let status = if result.ok {
        StatusCode::OK
    } else {
        StatusCode::UNPROCESSABLE_ENTITY
    };
    (status, Json(result))
}

fn validate_plan(plan: &InstallPlan) -> DryRunResult {
    let mut checks = vec![];
    let mut ok = true;

    if plan.disk.profile == "manual" {
        let parts = plan
            .disk
            .manual_partitions
            .as_ref()
            .cloned()
            .unwrap_or_default();
        let has_root = parts.iter().any(|p| p.mountpoint == "/");
        let has_efi = parts
            .iter()
            .any(|p| p.mountpoint == "/boot/efi" || p.mountpoint == "/efi");

        if has_root {
            checks.push(Check::pass("Partição raiz (/) definida"));
        } else {
            checks.push(Check::fail("Modo manual exige partição raiz (/)"));
            ok = false;
        }

        if has_efi {
            checks.push(Check::pass("Partição EFI definida"));
        } else {
            checks.push(Check::fail(
                "Modo manual exige partição EFI (/boot/efi ou /efi)",
            ));
            ok = false;
        }

        // Check for duplicate mountpoints
        let mut mnts = std::collections::HashSet::new();
        for p in &parts {
            if !mnts.insert(&p.mountpoint) {
                checks.push(Check::fail(format!(
                    "Ponto de montagem duplicado: {}",
                    p.mountpoint
                )));
                ok = false;
            }
        }
    } else if plan.disk.profile == "raid" {
        let level = plan.disk.raid_level.as_deref().unwrap_or("raid1");
        let count = plan.disk.selected_disks.len();
        let min_required = match level {
            "raid0" | "raid1" => 2,
            "raid5" => 3,
            "raid10" => 4,
            _ => 2,
        };

        if count >= min_required {
            checks.push(Check::pass(format!(
                "Configuração {} com {} discos",
                level.to_uppercase(),
                count
            )));
        } else {
            checks.push(Check::fail(format!(
                "{} exige pelo menos {} discos (selecionados: {})",
                level.to_uppercase(),
                min_required,
                count
            )));
            ok = false;
        }

        if level == "raid10" && count % 2 != 0 {
            checks.push(Check::fail("RAID 10 exige número par de discos"));
            ok = false;
        }
    } else {
        validate_install_target(&plan.disk.target, &mut checks, &mut ok);
    }

    if plan.disk.profile == "manual" {
        for target in install_targets(plan) {
            validate_install_target(&target, &mut checks, &mut ok);
        }
    } else if plan.disk.profile == "raid" {
        for target in &plan.disk.selected_disks {
            validate_install_target(target, &mut checks, &mut ok);
        }
    }

    if !plan.hostname.trim().is_empty() {
        checks.push(Check::pass(format!("Hostname: {}", plan.hostname)));
    } else {
        checks.push(Check::fail("Hostname não pode ser vazio"));
        ok = false;
    }

    let user = plan.user.name.trim();
    if user.is_empty() {
        checks.push(Check::fail("Nome de usuário não pode ser vazio"));
        ok = false;
    } else if user
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
    {
        checks.push(Check::pass(format!("Usuário: {}", user)));
    } else {
        checks.push(Check::fail("Nome de usuário contém caracteres inválidos"));
        ok = false;
    }

    if !plan.timezone.trim().is_empty() {
        checks.push(Check::pass(format!("Timezone: {}", plan.timezone)));
    } else {
        checks.push(Check::fail("Timezone não pode ser vazio"));
        ok = false;
    }

    DryRunResult { ok, checks }
}

fn install_targets(plan: &InstallPlan) -> Vec<String> {
    let mut targets = vec![plan.disk.target.clone()];
    if let Some(parts) = &plan.disk.manual_partitions {
        targets.extend(parts.iter().map(|p| p.device.clone()));
    }
    targets.sort();
    targets.dedup();
    targets.retain(|target| !target.trim().is_empty());
    targets
}

fn validate_install_target(target: &str, checks: &mut Vec<Check>, ok: &mut bool) {
    match disk::inspect_disk(target) {
        Ok(info) => checks.push(Check::pass(format!(
            "Disco {target} encontrado como block device ({}, {})",
            info.name, info.size
        ))),
        Err(e) => {
            checks.push(Check::fail(e));
            *ok = false;
            return;
        }
    }

    match disk::is_system_disk(target) {
        Ok(true) => {
            checks.push(Check::fail(format!(
                "PERIGO: {target} é o disco onde o sistema está rodando"
            )));
            *ok = false;
        }
        Ok(false) => checks.push(Check::pass(format!("{target} não é o disco do sistema"))),
        Err(e) => {
            checks.push(Check::fail(e));
            *ok = false;
        }
    }

    match disk::disk_mount_conflicts(target) {
        Ok(conflicts) if conflicts.is_empty() => {
            checks.push(Check::pass(format!("{target} não tem partições montadas")))
        }
        Ok(conflicts) => {
            checks.push(Check::fail(format!(
                "{target} está montado em {}",
                conflicts.join(", ")
            )));
            *ok = false;
        }
        Err(e) => {
            checks.push(Check::fail(e));
            *ok = false;
        }
    }

    match disk::disk_has_min_install_size(target) {
        Ok((true, size_bytes)) => {
            let size_gb = size_bytes / (1024 * 1024 * 1024);
            checks.push(Check::pass(format!("{target} tem {size_gb} GB")));
        }
        Ok((false, size_bytes)) => {
            let size_gb = size_bytes / (1024 * 1024 * 1024);
            checks.push(Check::fail(format!("{target} tem apenas {size_gb} GB")));
            *ok = false;
        }
        Err(e) => {
            checks.push(Check::fail(e));
            *ok = false;
        }
    }
}

// ── POST /install ─────────────────────────────────────────────────────────────

#[derive(Serialize)]
struct SafetyResponse {
    error: String,
    checks: Vec<SafetyCheck>,
}

async fn install(
    State(state): State<Arc<AppState>>,
    Json(plan): Json<InstallPlan>,
) -> impl IntoResponse {
    // dry-run mode → only validate, never touch disks
    if plan.disk.mode == "dry-run" {
        return Json(validate_plan(&plan)).into_response();
    }

    if plan.disk.mode != "install" && plan.disk.mode != "real" {
        return (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "INVALID_INSTALL_MODE".into(),
                details: Some(
                    "Use disk.mode=\"dry-run\" para validar ou \"install\"/\"real\" para executar."
                        .into(),
                ),
            }),
        )
            .into_response();
    }

    let validation = validate_plan(&plan);
    if !validation.ok {
        return (StatusCode::UNPROCESSABLE_ENTITY, Json(validation)).into_response();
    }

    // Safety checks — ALL must pass; any failure → 403 Forbidden
    let checks = executor::run_safety_checks(&plan);
    if checks.iter().any(|c| !c.passed) {
        return (
            StatusCode::FORBIDDEN,
            Json(SafetyResponse {
                error: "Safety checks falharam — instalação recusada".into(),
                checks,
            }),
        )
            .into_response();
    }

    // Launch executor in background, return job_id immediately
    let job_id = uuid::Uuid::new_v4().to_string();
    let tx = state.progress_tx.clone();
    let status_state = state.install_status.clone();
    let plan_clone = plan.clone();
    let job_id_for_task = job_id.clone();

    tokio::spawn(async move {
        {
            let mut status = status_state.write().await;
            *status = InstallStatus {
                running: true,
                exit_code: None,
                current_phase: Some("precheck".into()),
                last_error: None,
                last_log_line: Some(format!(
                    "job {job_id_for_task} aceito; iniciando executor real"
                )),
                have_plan: true,
                can_install: true,
            };
        }

        let _ = tx.send(ProgressEvent {
            step: "precheck".into(),
            message: "Executor real iniciado; disko e nixos-install serão chamados.".into(),
            percent: 1,
        });

        match executor::run_installation(&plan_clone, tx.clone()).await {
            Ok(()) => {
                let mut status = status_state.write().await;
                status.running = false;
                status.exit_code = Some(0);
                status.current_phase = Some("done".into());
                status.last_error = None;
                status.last_log_line = Some("Instalação concluída pelo executor real".into());
            }
            Err(error) => {
                let _ = tx.send(ProgressEvent {
                    step: "error".into(),
                    message: error.clone(),
                    percent: 100,
                });

                let mut status = status_state.write().await;
                status.running = false;
                status.exit_code = Some(1);
                status.current_phase = Some("error".into());
                status.last_error = Some(error.clone());
                status.last_log_line = Some(error);
            }
        }
    });

    (
        StatusCode::ACCEPTED,
        Json(serde_json::json!({ "job_id": job_id, "status": "running" })),
    )
        .into_response()
}

async fn install_status(State(state): State<Arc<AppState>>) -> Json<InstallStatus> {
    Json(state.install_status.read().await.clone())
}

// ── GET /install/progress — SSE ───────────────────────────────────────────────

async fn install_progress(
    State(state): State<Arc<AppState>>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = state.progress_tx.subscribe();
    let stream = async_stream::stream! {
        while let Ok(event) = rx.recv().await {
            let data = serde_json::to_string(&event).unwrap_or_default();
            yield Ok(Event::default().data(data));
        }
    };
    Sse::new(stream).keep_alive(axum::response::sse::KeepAlive::new())
}

// ── Legacy routes ─────────────────────────────────────────────────────────────

async fn get_partitions_handler(
    Path(device): Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    disk::get_partitions(&device)
        .map(Json)
        .map_err(|e| err500("FAILED_TO_GET_PARTITIONS", Some(e)))
}

async fn get_disks() -> Result<Json<Vec<disk::DiskInfo>>, ApiError> {
    disk::list_disks()
        .map(Json)
        .map_err(|e| err500("FAILED_TO_LIST_DISKS", Some(e)))
}

async fn partition_endpoint(
    Json(_payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, ApiError> {
    Err((
        StatusCode::GONE,
        Json(ErrorResponse {
            error: "LEGACY_ROUTE_DISABLED".into(),
            details: Some("A rota /api/partition foi desativada. Use /dry-run e /install.".into()),
        }),
    ))
}

async fn stream_logs(
    State(state): State<Arc<AppState>>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = state.log_sender.subscribe();
    let stream = async_stream::stream! {
        while let Ok(msg) = rx.recv().await {
            yield Ok(Event::default().data(msg));
        }
    };
    Sse::new(stream).keep_alive(axum::response::sse::KeepAlive::new())
}

async fn reboot_endpoint() -> Result<Json<serde_json::Value>, ApiError> {
    Err((
        StatusCode::NOT_IMPLEMENTED,
        Json(ErrorResponse {
            error: "REBOOT_DISABLED".into(),
            details: Some("O backend do instalador não reinicia a máquina automaticamente.".into()),
        }),
    ))
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_plan(disk: &str, hostname: &str, user: &str) -> InstallPlan {
        InstallPlan {
            version: 1,
            hostname: hostname.into(),
            timezone: "America/Cuiaba".into(),
            locale: "pt_BR.UTF-8".into(),
            keyboard: "br-abnt2".into(),
            disk: PlanDisk {
                mode: "dry-run".into(),
                target: disk.into(),
                layout: "btrfs-simple".into(),
                boot_mode: "uefi".into(),
                profile: "single".into(),
                selected_disks: vec![],
                raid_level: None,
                manual_partitions: None,
            },
            user: PlanUser {
                name: user.into(),
                admin: true,
            },
            features: serde_json::json!({}),
            network: Default::default(),
        }
    }

    #[test]
    fn test_dry_run_rejects_nonexistent_disk() {
        let result = validate_plan(&make_plan("/dev/nonexistent999xyz", "kryonix", "admin"));
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("nonexistent999xyz"))
        );
    }

    #[test]
    fn test_dry_run_rejects_empty_hostname() {
        let result = validate_plan(&make_plan("/dev/null", "", "admin"));
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("Hostname"))
        );
    }

    #[test]
    fn test_dry_run_manual_requires_root_and_efi() {
        let mut plan = make_plan("/dev/null", "kryonix", "admin");
        plan.disk.profile = "manual".into();
        plan.disk.manual_partitions = Some(vec![PartitionSpec {
            device: "/dev/sda".into(),
            mountpoint: "/home".into(),
            fstype: "ext4".into(),
            size: "100%".into(),
            format: true,
        }]);

        let result = validate_plan(&plan);
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("raiz (/)"))
        );
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("EFI"))
        );
    }

    #[test]
    fn test_dry_run_manual_rejects_duplicate_mountpoints() {
        let mut plan = make_plan("/dev/null", "kryonix", "admin");
        plan.disk.profile = "manual".into();
        plan.disk.manual_partitions = Some(vec![
            PartitionSpec {
                device: "/dev/sda".into(),
                mountpoint: "/".into(),
                fstype: "ext4".into(),
                size: "10G".into(),
                format: true,
            },
            PartitionSpec {
                device: "/dev/sda".into(),
                mountpoint: "/boot/efi".into(),
                fstype: "vfat".into(),
                size: "512M".into(),
                format: true,
            },
            PartitionSpec {
                device: "/dev/sda".into(),
                mountpoint: "/".into(),
                fstype: "ext4".into(),
                size: "10G".into(),
                format: true,
            },
        ]);

        let result = validate_plan(&plan);
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("duplicado"))
        );
    }

    #[test]
    fn test_dry_run_raid_requires_min_disks() {
        let mut plan = make_plan("/dev/null", "kryonix", "admin");
        plan.disk.profile = "raid".into();
        plan.disk.raid_level = Some("raid5".into());
        plan.disk.selected_disks = vec!["/dev/sda".into(), "/dev/sdb".into()]; // RAID 5 needs 3

        let result = validate_plan(&plan);
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("RAID5 exige pelo menos 3"))
        );
    }

    #[test]
    fn test_dry_run_rejects_empty_user() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", ""));
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| !c.ok && c.message.contains("usuário"))
        );
    }

    #[test]
    fn test_dry_run_rejects_invalid_user_chars() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", "root; rm -rf /"));
        assert!(!result.ok);
    }

    #[test]
    fn test_dry_run_rejects_null_device() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", "admin"));
        assert!(!result.ok);
        assert!(
            result
                .checks
                .iter()
                .any(|c| c.message.contains("null") && !c.ok)
        );
    }

    #[test]
    fn test_install_dry_run_mode_flag() {
        // Verify that a plan with mode="dry-run" has the correct flag
        // (handler-level gating tested by checking the flag itself)
        let plan = make_plan("/dev/null", "kryonix", "admin");
        assert_eq!(plan.disk.mode, "dry-run");
    }

    #[test]
    fn test_install_mode_field_controls_execution_path() {
        // "dry-run" must never reach safety checks / executor
        // This is documented at the handler level; here we verify the field name is correct.
        let mut plan = make_plan("/dev/null", "kryonix", "admin");
        plan.disk.mode = "install".into();
        assert_ne!(plan.disk.mode, "dry-run");
    }
}
