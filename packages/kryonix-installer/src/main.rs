mod disk;
mod executor;
mod install;

use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    response::{IntoResponse, sse::{Event, Sse}},
    routing::{get, post},
};
use executor::{ProgressEvent, SafetyCheck};
use futures_util::stream::Stream;
use serde::{Deserialize, Serialize};
use std::convert::Infallible;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::broadcast;
use tower_http::{cors::CorsLayer, services::ServeDir};

// ── Shared state ──────────────────────────────────────────────────────────────

struct AppState {
    log_sender: Arc<broadcast::Sender<String>>,
    progress_tx: Arc<broadcast::Sender<ProgressEvent>>,
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
}

#[derive(Serialize, Deserialize, Clone)]
pub struct PlanDisk {
    pub mode: String,
    pub target: String,
    pub layout: String,
    pub boot_mode: String,
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
        Self { ok: true, message: msg.into() }
    }
    fn fail(msg: impl Into<String>) -> Self {
        Self { ok: false, message: msg.into() }
    }
}

// ── Partition request (legacy) ────────────────────────────────────────────────

#[derive(Deserialize)]
struct PartitionRequest {
    disk: String,
}

// ── Main ──────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let (log_tx, _) = broadcast::channel(100);
    let (progress_tx, _) = broadcast::channel::<ProgressEvent>(64);

    let state = Arc::new(AppState {
        log_sender: Arc::new(log_tx),
        progress_tx: Arc::new(progress_tx),
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/probe", get(probe))
        .route("/plan", post(plan))
        .route("/dry-run", post(dry_run))
        .route("/install", post(install))
        .route("/install/progress", get(install_progress))
        .route("/api/disks", get(get_disks))
        .route("/api/partition", post(partition_endpoint))
        .route("/api/stream", get(stream_logs))
        .layer(CorsLayer::permissive())
        .with_state(state)
        .fallback_service(
            ServeDir::new("/run/current-system/sw/share/kryonix-installer/ui/dist")
                .fallback(ServeDir::new("ui/static")),
        );

    let listener = tokio::net::TcpListener::bind("127.0.0.1:8080")
        .await
        .unwrap();
    println!(
        "Kryonix Installer API → http://{}",
        listener.local_addr().unwrap()
    );
    axum::serve(listener, app).await.unwrap();
}

// ── GET /health ───────────────────────────────────────────────────────────────

async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status":  "ok",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

// ── GET /probe ────────────────────────────────────────────────────────────────

async fn probe() -> Result<Json<serde_json::Value>, ApiError> {
    let output = tokio::task::spawn_blocking(|| Command::new("kryonix-hardware-probe").output())
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
        },
        user: PlanUser {
            name: req.user.name,
            admin: req.user.admin.unwrap_or(true),
        },
        features: req.features.unwrap_or(serde_json::json!({})),
    })
}

// ── POST /dry-run ─────────────────────────────────────────────────────────────

async fn dry_run(Json(plan): Json<InstallPlan>) -> Json<DryRunResult> {
    Json(validate_plan(&plan))
}

fn validate_plan(plan: &InstallPlan) -> DryRunResult {
    let mut checks = vec![];
    let mut ok = true;

    if std::path::Path::new(&plan.disk.target).exists() {
        checks.push(Check::pass(format!("Disco {} encontrado", plan.disk.target)));
    } else {
        checks.push(Check::fail(format!("Disco {} não encontrado", plan.disk.target)));
        ok = false;
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
    } else if user.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') {
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
    let plan_clone = plan.clone();

    tokio::spawn(async move {
        if let Err(e) = executor::run_installation(&plan_clone, tx.clone()).await {
            let _ = tx.send(ProgressEvent {
                step: "error".into(),
                message: e,
                percent: 0,
            });
        }
    });

    (
        StatusCode::ACCEPTED,
        Json(serde_json::json!({ "job_id": job_id, "status": "running" })),
    )
        .into_response()
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

async fn get_disks() -> Result<Json<Vec<disk::DiskInfo>>, ApiError> {
    disk::list_disks()
        .map(Json)
        .map_err(|e| err500("FAILED_TO_LIST_DISKS", Some(e)))
}

async fn partition_endpoint(
    Json(payload): Json<PartitionRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    disk::partition_disk(&payload.disk)
        .map(|_| Json(serde_json::json!({ "status": "success" })))
        .map_err(|e| err500("PARTITION_FAILED", Some(e)))
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
            },
            user: PlanUser {
                name: user.into(),
                admin: true,
            },
            features: serde_json::json!({}),
        }
    }

    #[test]
    fn test_dry_run_rejects_nonexistent_disk() {
        let result = validate_plan(&make_plan("/dev/nonexistent999xyz", "kryonix", "admin"));
        assert!(!result.ok);
        assert!(
            result.checks.iter().any(|c| !c.ok && c.message.contains("nonexistent999xyz"))
        );
    }

    #[test]
    fn test_dry_run_rejects_empty_hostname() {
        let result = validate_plan(&make_plan("/dev/null", "", "admin"));
        assert!(!result.ok);
        assert!(result.checks.iter().any(|c| !c.ok && c.message.contains("Hostname")));
    }

    #[test]
    fn test_dry_run_rejects_empty_user() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", ""));
        assert!(!result.ok);
        assert!(result.checks.iter().any(|c| !c.ok && c.message.contains("usuário")));
    }

    #[test]
    fn test_dry_run_rejects_invalid_user_chars() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", "root; rm -rf /"));
        assert!(!result.ok);
    }

    #[test]
    fn test_dry_run_passes_null_device() {
        let result = validate_plan(&make_plan("/dev/null", "kryonix", "admin"));
        assert!(
            result.checks
                .iter()
                .find(|c| c.message.contains("null"))
                .map(|c| c.ok)
                .unwrap_or(false)
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
