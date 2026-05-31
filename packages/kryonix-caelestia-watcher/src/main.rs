mod watcher;

use axum::{
    extract::State,
    response::sse::{Event, Sse},
    routing::{get, post},
    Json, Router,
};
use futures::stream::Stream;
use serde::Deserialize;
use std::{convert::Infallible, net::SocketAddr, sync::Arc, time::Duration};
use tokio::sync::broadcast;
use tokio_stream::wrappers::BroadcastStream;
use tokio_stream::StreamExt as _;
use tracing::info;
use tower_http::cors::{Any, CorsLayer};

#[derive(Clone)]
struct AppState {
    tx: broadcast::Sender<String>,
}

#[derive(Deserialize)]
struct ProfileRequest {
    profile: String,
    host: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let (tx, _rx) = broadcast::channel::<String>(100);
    let state = Arc::new(AppState { tx: tx.clone() });

    // Spawn watcher task
    let watcher_tx = tx.clone();
    tokio::spawn(async move {
        if let Err(e) = watcher::run_watcher(watcher_tx).await {
            tracing::error!("Watcher error: {}", e);
        }
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/caelestia/events", get(sse_handler))
        .route("/profile/apply", post(apply_profile_handler))
        .layer(cors)
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3030));
    info!("Caelestia Watcher API listening on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn apply_profile_handler(
    State(_state): State<Arc<AppState>>,
    Json(payload): Json<ProfileRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, String)> {
    info!("Applying profile '{}' to host '{}'", payload.profile, payload.host);
    
    // TODO: Implement nix-edit or text replacement logic for flake.nix imports
    // This will involve modifying /etc/kryonixos/hosts/<host>/default.nix or similar.
    
    Ok(Json(serde_json::json!({
        "status": "success",
        "message": format!("Profile {} scheduled for application on {}", payload.profile, payload.host)
    })))
}

async fn sse_handler(
    State(state): State<Arc<AppState>>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let rx = state.tx.subscribe();
    let stream = BroadcastStream::new(rx).map(|msg| {
        match msg {
            Ok(m) => Ok(Event::default().data(m)),
            Err(_) => Ok(Event::default().data("error")),
        }
    });

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keep-alive"),
    )
}
