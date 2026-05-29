mod disk;
mod install;

use axum::{
    extract::State,
    response::sse::{Event, Sse},
    routing::{get, post},
    Json, Router,
};
use futures_util::stream::{self, Stream};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::broadcast;
use tower_http::cors::CorsLayer;
use std::convert::Infallible;

#[derive(Serialize, Deserialize)]
struct Status {
    status: String,
    version: String,
    phase: String,
}

#[derive(Serialize, Deserialize)]
struct ErrorResponse {
    error: String,
    details: Option<String>,
}

#[derive(Deserialize)]
struct PartitionRequest {
    disk: String,
}

struct AppState {
    log_sender: Arc<broadcast::Sender<String>>,
}

#[tokio::main]
async fn main() {
    let (tx, _) = broadcast::channel(100);
    let state = Arc::new(AppState {
        log_sender: Arc::new(tx),
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/api/disks", get(get_disks))
        .route("/api/partition", post(partition_endpoint))
        .route("/api/install", post(install_endpoint))
        .route("/api/stream", get(stream_logs))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
    println!("Kryonix Installer API listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}

async fn health() -> Json<Status> {
    Json(Status {
        status: "ok".to_string(),
        version: "0.1.0".to_string(),
        phase: "2".to_string(),
    })
}

async fn get_disks() -> Result<Json<Vec<disk::DiskInfo>>, (axum::http::StatusCode, Json<ErrorResponse>)> {
    match disk::list_disks() {
        Ok(disks) => Ok(Json(disks)),
        Err(e) => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: "FAILED_TO_LIST_DISKS".to_string(),
                details: Some(e),
            }),
        )),
    }
}

async fn partition_endpoint(Json(payload): Json<PartitionRequest>) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<ErrorResponse>)> {
    match disk::partition_disk(&payload.disk) {
        Ok(_) => Ok(Json(serde_json::json!({
            "status": "success",
            "message": "Disk partitioned and mounted successfully"
        }))),
        Err(e) => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: "PARTITION_FAILED".to_string(),
                details: Some(e),
            }),
        )),
    }
}

async fn install_endpoint(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<install::InstallConfig>
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<ErrorResponse>)> {
    
    if let Err(e) = install::generate_configs(&payload).await {
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: "CONFIG_GENERATION_FAILED".to_string(),
                details: Some(e),
            }),
        ));
    }

    let sender = state.log_sender.clone();
    
    // Roda a instalação de forma assíncrona para não bloquear o endpoint
    tokio::spawn(async move {
        let _ = install::execute_nixos_install(sender).await;
    });

    Ok(Json(serde_json::json!({
        "status": "success",
        "message": "Installation started. Connect to /api/stream for logs."
    })))
}

async fn stream_logs(State(state): State<Arc<AppState>>) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = state.log_sender.subscribe();
    
    let stream = async_stream::stream! {
        while let Ok(msg) = rx.recv().await {
            yield Ok(Event::default().data(msg));
        }
    };
    
    Sse::new(stream).keep_alive(axum::response::sse::KeepAlive::new())
}
