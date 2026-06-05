use axum::{Json, extract::State, http::StatusCode, response::IntoResponse};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::AppState;

// ── Public auth sub-state (held inside AppState) ──────────────────────────────

#[derive(Debug, Default)]
pub struct AuthState {
    /// Raw device_code returned by GitHub — never sent to the UI.
    device_code: Option<String>,
    /// How long to wait between polls (seconds). GitHub may increase this.
    poll_interval: u64,
    /// Bearer token — stored in memory only, never written to disk or store.
    access_token: Option<String>,
}

pub type SharedAuthState = Arc<Mutex<AuthState>>;

pub fn new_auth_state() -> SharedAuthState {
    Arc::new(Mutex::new(AuthState::default()))
}

// ── GitHub API response types (internal) ─────────────────────────────────────

#[derive(Deserialize)]
struct GhDeviceCode {
    device_code: String,
    user_code: String,
    verification_uri: String,
    expires_in: u64,
    interval: u64,
}

#[derive(Deserialize)]
struct GhToken {
    #[serde(default)]
    access_token: Option<String>,
    #[serde(default)]
    error: Option<String>,
    #[serde(default)]
    error_description: Option<String>,
}

// ── Public response shapes (sent to the UI) ───────────────────────────────────

#[derive(Serialize)]
pub struct DeviceFlowStarted {
    user_code: String,
    verification_uri: String,
    expires_in: u64,
    interval: u64,
}

#[derive(Serialize)]
pub struct PollResult {
    status: PollStatus,
    /// Only present when status == Authorized. Contains basic profile info
    /// fetched with the token so the UI can greet the user — NOT the token itself.
    #[serde(skip_serializing_if = "Option::is_none")]
    user: Option<GhUser>,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
enum PollStatus {
    Pending,
    Authorized,
    SlowDown,
    Expired,
    Denied,
}

#[derive(Serialize, Deserialize)]
pub struct GhUser {
    pub login: String,
    pub name: Option<String>,
    pub avatar_url: String,
}

// ── POST /auth/github/device ──────────────────────────────────────────────────
//
// Starts the GitHub OAuth Device Authorization Flow.
// Returns the user_code and verification_uri for the UI to display.
// The device_code (secret) is stored server-side only.

pub async fn start_device_flow(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let client_id = match std::env::var("GITHUB_CLIENT_ID") {
        Ok(id) if !id.is_empty() => id,
        _ => {
            return (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(serde_json::json!({
                    "error": "GITHUB_CLIENT_ID not configured",
                    "details": "Set GITHUB_CLIENT_ID env var before starting the installer"
                })),
            )
                .into_response();
        }
    };

    let resp = match state
        .http_client
        .post("https://github.com/login/device/code")
        .header("Accept", "application/json")
        .form(&[("client_id", &client_id), ("scope", &"repo".to_string())])
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(
                    serde_json::json!({ "error": "GitHub unreachable", "details": e.to_string() }),
                ),
            )
                .into_response();
        }
    };

    let gh: GhDeviceCode = match resp.json().await {
        Ok(d) => d,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(serde_json::json!({ "error": "Unexpected GitHub response", "details": e.to_string() })),
            )
                .into_response();
        }
    };

    let interval = gh.interval;
    {
        let mut auth = state.auth.lock().await;
        auth.device_code = Some(gh.device_code);
        auth.poll_interval = interval;
        auth.access_token = None;
    }

    Json(DeviceFlowStarted {
        user_code: gh.user_code,
        verification_uri: gh.verification_uri,
        expires_in: gh.expires_in,
        interval,
    })
    .into_response()
}

// ── GET /auth/github/poll ─────────────────────────────────────────────────────
//
// Polls GitHub for the access token.  The UI should call this every
// `interval` seconds (from the /device response) and stop when it gets
// status "authorized" or a terminal error (expired / denied).

pub async fn poll_device_flow(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let client_id = std::env::var("GITHUB_CLIENT_ID").unwrap_or_default();

    let (device_code, _interval) = {
        let auth = state.auth.lock().await;
        match auth.device_code.clone() {
            Some(dc) => (dc, auth.poll_interval),
            None => {
                return (
                    StatusCode::BAD_REQUEST,
                    Json(serde_json::json!({ "error": "No active device flow — call /auth/github/device first" })),
                )
                    .into_response();
            }
        }
    };

    // GitHub requires form-encoded body for the token endpoint
    let resp = match state
        .http_client
        .post("https://github.com/login/oauth/access_token")
        .header("Accept", "application/json")
        .form(&[
            ("client_id", client_id.as_str()),
            ("device_code", device_code.as_str()),
            ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
        ])
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(
                    serde_json::json!({ "error": "GitHub unreachable", "details": e.to_string() }),
                ),
            )
                .into_response();
        }
    };

    let token: GhToken = match resp.json().await {
        Ok(t) => t,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(serde_json::json!({ "error": "Unexpected token response", "details": e.to_string() })),
            )
                .into_response();
        }
    };

    // Terminal success: store token, fetch basic user info for the UI greeting
    if let Some(access_token) = token.access_token {
        let user_info = fetch_github_user(&state.http_client, &access_token).await;

        {
            let mut auth = state.auth.lock().await;
            auth.access_token = Some(access_token);
            // Device code is one-shot; clear it so stale polls error cleanly
            auth.device_code = None;
        }

        return Json(PollResult {
            status: PollStatus::Authorized,
            user: user_info,
            message: None,
        })
        .into_response();
    }

    // Map GitHub error codes to our enum
    let result = match token.error.as_deref() {
        Some("authorization_pending") | None => PollResult {
            status: PollStatus::Pending,
            user: None,
            message: None,
        },
        Some("slow_down") => PollResult {
            status: PollStatus::SlowDown,
            user: None,
            message: token.error_description,
        },
        Some("expired_token") => PollResult {
            status: PollStatus::Expired,
            user: None,
            message: Some("Device code expired — restart the flow".into()),
        },
        Some("access_denied") => PollResult {
            status: PollStatus::Denied,
            user: None,
            message: Some("User denied authorization".into()),
        },
        Some(other) => PollResult {
            status: PollStatus::Denied,
            user: None,
            message: Some(format!("Unexpected GitHub error: {other}")),
        },
    };

    Json(result).into_response()
}

// ── GET /auth/github/repos ────────────────────────────────────────────────────
//
// Lists the authenticated user's repos (public + private).
// Requires a completed OAuth flow (access_token in memory).

#[derive(Serialize)]
pub struct RepoEntry {
    full_name: String,
    private: bool,
    html_url: String,
    clone_url: String,
    description: Option<String>,
}

pub async fn list_repos(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let token = {
        let auth = state.auth.lock().await;
        match auth.access_token.clone() {
            Some(t) => t,
            None => {
                return (
                    StatusCode::UNAUTHORIZED,
                    Json(
                        serde_json::json!({ "error": "Not authenticated — complete OAuth first" }),
                    ),
                )
                    .into_response();
            }
        }
    };

    let resp = match state
        .http_client
        .get("https://api.github.com/user/repos")
        .header("Authorization", format!("Bearer {token}"))
        .header("Accept", "application/vnd.github+json")
        .header("User-Agent", "kryonix-installer/0.1")
        .query(&[("per_page", "100"), ("sort", "updated")])
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(serde_json::json!({ "error": "GitHub API unreachable", "details": e.to_string() })),
            )
                .into_response();
        }
    };

    #[derive(Deserialize)]
    struct GhRepo {
        full_name: String,
        private: bool,
        html_url: String,
        clone_url: String,
        description: Option<String>,
    }

    let repos: Vec<GhRepo> = match resp.json().await {
        Ok(r) => r,
        Err(e) => {
            return (
                StatusCode::BAD_GATEWAY,
                Json(serde_json::json!({ "error": "Failed to parse repos", "details": e.to_string() })),
            )
                .into_response();
        }
    };

    let entries: Vec<RepoEntry> = repos
        .into_iter()
        .map(|r| RepoEntry {
            full_name: r.full_name,
            private: r.private,
            html_url: r.html_url,
            clone_url: r.clone_url,
            description: r.description,
        })
        .collect();

    Json(entries).into_response()
}

// ── POST /clone ───────────────────────────────────────────────────────────────
//
// Clones a repo to /etc/kryonixos using the OAuth token as HTTPS credential.
// Token is injected into the URL as a transient credential (https://<token>@...).
// It NEVER touches disk — the git process inherits it from memory via env/args.

#[derive(Deserialize)]
pub struct CloneRequest {
    /// e.g. "https://github.com/user/kryonixos.git"
    clone_url: String,
    dest: Option<String>,
}

pub async fn clone_repo(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CloneRequest>,
) -> impl IntoResponse {
    let token = {
        let auth = state.auth.lock().await;
        match auth.access_token.clone() {
            Some(t) => t,
            None => {
                return (
                    StatusCode::UNAUTHORIZED,
                    Json(serde_json::json!({ "error": "Not authenticated" })),
                )
                    .into_response();
            }
        }
    };

    // Build authenticated URL without storing it anywhere persistent
    let authed_url = inject_token_into_url(&req.clone_url, &token);
    let dest = req.dest.unwrap_or_else(|| "/etc/kryonixos".into());

    let output = tokio::process::Command::new("git")
        .args(["clone", "--depth=1", &authed_url, &dest])
        // Disable git credential helpers — token is ephemeral
        .env("GIT_CONFIG_NOSYSTEM", "1")
        .env("HOME", "/nonexistent")
        .output()
        .await;

    match output {
        Ok(o) if o.status.success() => Json(serde_json::json!({
            "status": "cloned",
            "dest": dest
        }))
        .into_response(),
        Ok(o) => {
            // Sanitize stderr: strip the token before logging
            let stderr = String::from_utf8_lossy(&o.stderr);
            let sanitized = stderr.replace(&token, "***");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "git clone failed", "details": sanitized })),
            )
                .into_response()
        }
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": "Failed to spawn git", "details": e.to_string() })),
        )
            .into_response(),
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Injects an OAuth token into an HTTPS URL as a transient credential.
/// Result is only ever held in memory for the duration of the git spawn.
fn inject_token_into_url(url: &str, token: &str) -> String {
    if let Some(rest) = url.strip_prefix("https://") {
        format!("https://x-access-token:{token}@{rest}")
    } else {
        url.to_string()
    }
}

async fn fetch_github_user(client: &reqwest::Client, token: &str) -> Option<GhUser> {
    client
        .get("https://api.github.com/user")
        .header("Authorization", format!("Bearer {token}"))
        .header("Accept", "application/vnd.github+json")
        .header("User-Agent", "kryonix-installer/0.1")
        .send()
        .await
        .ok()?
        .json::<GhUser>()
        .await
        .ok()
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inject_token_into_https_url() {
        let url = "https://github.com/user/repo.git";
        let authed = inject_token_into_url(url, "ghp_tok123");
        assert_eq!(
            authed,
            "https://x-access-token:ghp_tok123@github.com/user/repo.git"
        );
    }

    #[test]
    fn inject_token_leaves_non_https_unchanged() {
        let url = "git@github.com:user/repo.git";
        let authed = inject_token_into_url(url, "tok");
        assert_eq!(authed, url);
    }
}
