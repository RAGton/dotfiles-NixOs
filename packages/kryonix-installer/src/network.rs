use axum::{Json, extract::State, http::StatusCode, response::IntoResponse};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::process::Command;

use crate::AppState;

// ── Response types ────────────────────────────────────────────────────────────

#[derive(Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ConnType {
    Ethernet,
    Wifi,
    None,
}

#[derive(Serialize)]
pub struct NetworkStatus {
    connected: bool,
    conn_type: ConnType,
    ip: Option<String>,
    /// Set when connected via WiFi
    ssid: Option<String>,
    /// "full" | "portal" | "limited" | "none" (from nmcli general)
    connectivity: String,
}

#[derive(Serialize)]
pub struct WifiEntry {
    ssid: String,
    signal: u8,
    security: String,
    in_use: bool,
}

#[derive(Deserialize)]
pub struct ConnectRequest {
    ssid: String,
    password: Option<String>,
}

#[derive(Serialize)]
pub struct ConnectResult {
    status: ConnectStatus,
    message: String,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
enum ConnectStatus {
    Ok,
    Failed,
}

// ── GET /network/status ───────────────────────────────────────────────────────
//
// Returns current connectivity.  The UI polls this after a connect attempt.
// Uses `nmcli` (NetworkManager CLI) which is always present in the ISO.

pub async fn status(_: State<Arc<AppState>>) -> impl IntoResponse {
    // nmcli -t -f STATE,CONNECTIVITY general
    // e.g.  "connected:full"
    let general = nmcli(&["-t", "-f", "STATE,CONNECTIVITY", "general"]).await;

    let (nm_state, connectivity) = parse_general(&general);
    let connected = nm_state == "connected" || nm_state == "connected (site only)";

    if !connected {
        return Json(NetworkStatus {
            connected: false,
            conn_type: ConnType::None,
            ip: None,
            ssid: None,
            connectivity: connectivity.unwrap_or_else(|| "none".into()),
        })
        .into_response();
    }

    // nmcli -t -f NAME,TYPE,DEVICE,IP4.ADDRESS connection show --active
    let active = nmcli(&[
        "-t",
        "-f",
        "NAME,TYPE,DEVICE,IP4.ADDRESS",
        "connection",
        "show",
        "--active",
    ])
    .await;

    let (conn_type, ip, ssid) = parse_active_connection(&active);

    Json(NetworkStatus {
        connected,
        conn_type,
        ip,
        ssid,
        connectivity: connectivity.unwrap_or_else(|| "full".into()),
    })
    .into_response()
}

// ── GET /network/wifi/scan ────────────────────────────────────────────────────
//
// Triggers a fresh scan and returns visible access points.
// Requires the WiFi radio to be on (enabled by the NixOS module via rfkill).

pub async fn wifi_scan(_: State<Arc<AppState>>) -> impl IntoResponse {
    // Trigger a rescan (best-effort; ignore failures)
    let _ = Command::new("nmcli")
        .args(["device", "wifi", "rescan"])
        .output()
        .await;

    // nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list
    let raw = nmcli(&["-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list"]).await;

    let mut entries: Vec<WifiEntry> = raw
        .lines()
        .filter_map(|line| {
            // Fields separated by ':'; SSID may contain ':' so split at most 3 times from right
            let parts: Vec<&str> = line.rsplitn(4, ':').collect();
            if parts.len() < 4 {
                return None;
            }
            // rsplitn reverses order: [in_use, security, signal, ssid]
            let in_use = parts[0].trim() == "*";
            let security = parts[1].trim().to_string();
            let signal: u8 = parts[2].trim().parse().unwrap_or(0);
            let ssid = parts[3].trim().to_string();

            if ssid.is_empty() {
                return None;
            }

            Some(WifiEntry { ssid, signal, security, in_use })
        })
        .collect();

    // Sort by signal descending, then dedup by SSID (nmcli may list same SSID
    // on multiple BSSIDs)
    entries.sort_by(|a, b| b.signal.cmp(&a.signal));
    entries.dedup_by(|a, b| {
        if a.ssid == b.ssid {
            // keep the in_use one or the higher-signal one (already sorted)
            b.in_use = b.in_use || a.in_use;
            true
        } else {
            false
        }
    });

    Json(entries).into_response()
}

// ── POST /network/wifi/connect ────────────────────────────────────────────────
//
// Connects to a WiFi network using nmcli.  The password is passed as a
// command argument (not written to any file).  If the network is open
// (no password), `password` may be omitted.
//
// This call blocks until nmcli succeeds or fails (typically < 10 s).
// The UI should poll /network/status afterwards to confirm IP assignment.

pub async fn wifi_connect(
    _: State<Arc<AppState>>,
    Json(req): Json<ConnectRequest>,
) -> impl IntoResponse {
    // Build nmcli args; avoid shell interpolation entirely
    let mut args = vec![
        "--wait".to_string(),
        "15".to_string(),
        "device".to_string(),
        "wifi".to_string(),
        "connect".to_string(),
        req.ssid.clone(),
    ];

    if let Some(ref pw) = req.password {
        if !pw.is_empty() {
            args.push("password".into());
            args.push(pw.clone());
        }
    }

    let output = Command::new("nmcli")
        .args(&args)
        .output()
        .await;

    match output {
        Ok(o) if o.status.success() => Json(ConnectResult {
            status: ConnectStatus::Ok,
            message: format!("Conectado a {}", req.ssid),
        })
        .into_response(),

        Ok(o) => {
            // Sanitize: strip the password from stderr before returning it
            let stderr = String::from_utf8_lossy(&o.stderr).into_owned();
            let sanitized = req
                .password
                .as_deref()
                .filter(|p| !p.is_empty())
                .map(|pw| stderr.replace(pw, "***"))
                .unwrap_or(stderr);

            (
                StatusCode::BAD_REQUEST,
                Json(ConnectResult {
                    status: ConnectStatus::Failed,
                    message: sanitized.trim().to_string(),
                }),
            )
                .into_response()
        }

        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ConnectResult {
                status: ConnectStatus::Failed,
                message: format!("Falha ao invocar nmcli: {e}"),
            }),
        )
            .into_response(),
    }
}

// ── POST /network/wifi/disconnect ────────────────────────────────────────────

pub async fn wifi_disconnect(_: State<Arc<AppState>>) -> impl IntoResponse {
    let output = Command::new("nmcli")
        .args(["device", "disconnect", "wlan0"])
        .output()
        .await;

    match output {
        Ok(o) if o.status.success() => {
            Json(serde_json::json!({ "status": "disconnected" })).into_response()
        }
        Ok(o) => (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({
                "error": String::from_utf8_lossy(&o.stderr).trim().to_string()
            })),
        )
            .into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": e.to_string() })),
        )
            .into_response(),
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async fn nmcli(args: &[&str]) -> String {
    Command::new("nmcli")
        .args(args)
        .output()
        .await
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default()
}

fn parse_general(raw: &str) -> (String, Option<String>) {
    // "connected:full\n"
    let line = raw.lines().next().unwrap_or("").trim();
    let mut parts = line.splitn(2, ':');
    let state = parts.next().unwrap_or("").to_string();
    let connectivity = parts.next().map(str::to_string);
    (state, connectivity)
}

fn parse_active_connection(raw: &str) -> (ConnType, Option<String>, Option<String>) {
    // Each active connection on its own line:
    // "MyWifi:802-11-wireless:wlan0:192.168.1.5/24"
    // "Wired:802-3-ethernet:eth0:10.0.0.2/24"

    for line in raw.lines() {
        let parts: Vec<&str> = line.splitn(4, ':').collect();
        if parts.len() < 3 {
            continue;
        }
        let name = parts[0].trim();
        let conn_type_str = parts[1].trim();
        let ip = parts.get(3).map(|s| s.trim().to_string()).filter(|s| !s.is_empty());

        match conn_type_str {
            "802-11-wireless" | "wifi" => {
                return (ConnType::Wifi, ip, Some(name.to_string()));
            }
            "802-3-ethernet" | "ethernet" => {
                return (ConnType::Ethernet, ip, None);
            }
            _ => continue,
        }
    }

    (ConnType::None, None, None)
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_general_connected() {
        let (state, conn) = parse_general("connected:full\n");
        assert_eq!(state, "connected");
        assert_eq!(conn.as_deref(), Some("full"));
    }

    #[test]
    fn parse_general_disconnected() {
        let (state, conn) = parse_general("disconnected:none\n");
        assert_eq!(state, "disconnected");
        assert_eq!(conn.as_deref(), Some("none"));
    }

    #[test]
    fn parse_active_ethernet() {
        let raw = "Wired:802-3-ethernet:eth0:10.0.0.2/24\n";
        let (t, ip, ssid) = parse_active_connection(raw);
        assert!(matches!(t, ConnType::Ethernet));
        assert_eq!(ip.as_deref(), Some("10.0.0.2/24"));
        assert!(ssid.is_none());
    }

    #[test]
    fn parse_active_wifi() {
        let raw = "HomeNet:802-11-wireless:wlan0:192.168.1.5/24\n";
        let (t, ip, ssid) = parse_active_connection(raw);
        assert!(matches!(t, ConnType::Wifi));
        assert_eq!(ssid.as_deref(), Some("HomeNet"));
        assert_eq!(ip.as_deref(), Some("192.168.1.5/24"));
    }
}
