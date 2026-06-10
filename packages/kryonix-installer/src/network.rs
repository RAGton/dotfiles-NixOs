use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
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

#[derive(Serialize)]
pub struct WifiScanResponse {
    interface: String,
    networks: Vec<WifiEntry>,
    #[serde(skip_serializing_if = "Option::is_none")]
    warning: Option<String>,
}

#[derive(Serialize, PartialEq, Debug, Clone)]
pub struct InterfaceEntry {
    pub name: String,
    /// "ethernet" | "wifi" | "other"
    #[serde(rename = "type")]
    pub kind: String,
    /// estado do nmcli: connected | disconnected | unavailable | ...
    pub state: String,
    pub connection: Option<String>,
    pub managed: bool,
}

#[derive(Serialize)]
pub struct InterfacesResponse {
    pub interfaces: Vec<InterfaceEntry>,
}

#[derive(Deserialize)]
pub struct ConnectRequest {
    pub interface: String,
    pub ssid: String,
    pub password: Option<String>,
}

#[derive(Serialize)]
pub struct ConnectResult {
    pub status: ConnectStatus,
    pub message: String,
}

#[derive(Serialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ConnectStatus {
    Ok,
    Failed,
}

// ── GET /network/status ───────────────────────────────────────────────────────

pub async fn status(_: State<Arc<AppState>>) -> impl IntoResponse {
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

// ── GET /network/interfaces ─────────────────────────────────────────────────

pub async fn interfaces(_: State<Arc<AppState>>) -> impl IntoResponse {
    // Tenta com MANAGED (NM recente)
    let mut raw = nmcli(&["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION,MANAGED", "device"]).await;
    let mut managed_supported = true;

    if raw.is_empty() || raw.contains("Unknown parameter") || raw.contains("Error:") {
        // Fallback para versões mais antigas ou erro de parsing
        raw = nmcli(&["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).await;
        managed_supported = false;
    }

    Json(InterfacesResponse {
        interfaces: parse_interfaces(&raw, managed_supported),
    })
    .into_response()
}

fn parse_interfaces(raw: &str, managed_in_input: bool) -> Vec<InterfaceEntry> {
    raw.lines()
        .filter_map(|line| {
            // nmcli -t usa '\:' para colons nos valores
            let parts: Vec<String> = line.split(':').map(|s| s.replace("\\:", ":")).collect();

            let min_expected = if managed_in_input { 5 } else { 4 };
            if parts.len() < min_expected {
                return None;
            }

            let name = parts[0].trim().to_string();
            let raw_type = parts[1].trim();
            let state = parts[2].trim().to_string();
            let connection = parts[3].trim().to_string();
            let connection = if connection.is_empty() || connection == "--" {
                None
            } else {
                Some(connection)
            };

            let managed = if managed_in_input {
                parts[4].trim().to_lowercase() == "yes"
            } else {
                true
            };

            if name.is_empty() || raw_type == "loopback" {
                return None;
            }

            let kind = match raw_type {
                "ethernet" | "802-3-ethernet" => "ethernet",
                "wifi" | "802-11-wireless" => "wifi",
                _ => "other",
            }
            .to_string();

            Some(InterfaceEntry {
                name,
                kind,
                state,
                connection,
                managed,
            })
        })
        .collect()
}

// ── GET /network/wifi/scan ────────────────────────────────────────────────────

pub async fn wifi_scan(
    _: State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
) -> impl IntoResponse {
    let iface = params
        .get("interface")
        .cloned()
        .unwrap_or_else(|| "wlan0".to_string());
    let mut warning = None;

    // Rescan é best-effort; se falhar (ex: VM sem wifi), prosseguimos para list.
    let rescan_res = Command::new("nmcli")
        .args(["device", "wifi", "rescan", "ifname", &iface])
        .output()
        .await;

    if let Err(e) = rescan_res {
        warning = Some(format!("Falha ao invocar nmcli rescan: {e}"));
    } else if !rescan_res.unwrap().status.success() {
        warning = Some("Interface Wi-Fi não suporta rescan imediato.".into());
    }

    let raw = nmcli(&[
        "-t",
        "-f",
        "SSID,SIGNAL,SECURITY,IN-USE",
        "device",
        "wifi",
        "list",
        "ifname",
        &iface,
    ])
    .await;

    let mut entries: Vec<WifiEntry> = raw
        .lines()
        .filter_map(|line| {
            let parts: Vec<String> = line.split(':').map(|s| s.replace("\\:", ":")).collect();
            if parts.len() < 4 {
                return None;
            }

            let mut ssid = parts[0].trim().to_string();
            if ssid.is_empty() {
                ssid = "Rede oculta".to_string();
            }
            let signal: u8 = parts[1].trim().parse().unwrap_or(0);
            let security = parts[2].trim().to_string();
            let in_use = parts[3].trim() == "*";

            Some(WifiEntry {
                ssid,
                signal,
                security,
                in_use,
            })
        })
        .collect();

    entries.sort_by(|a, b| b.signal.cmp(&a.signal));
    entries.dedup_by(|a, b| {
        if a.ssid == b.ssid {
            b.in_use = b.in_use || a.in_use;
            true
        } else {
            false
        }
    });

    Json(WifiScanResponse {
        interface: iface,
        networks: entries,
        warning,
    })
}

// ── POST /network/wifi/connect ────────────────────────────────────────────────

pub async fn wifi_connect(
    _: State<Arc<AppState>>,
    Json(req): Json<ConnectRequest>,
) -> impl IntoResponse {
    // SEGURANÇA: NUNCA logar req.password ou o corpo da requisição.

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

    args.push("ifname".into());
    args.push(req.interface.clone());

    let output = Command::new("nmcli").args(&args).output().await;

    match output {
        Ok(o) if o.status.success() => Json(ConnectResult {
            status: ConnectStatus::Ok,
            message: format!("Conectado a {}", req.ssid),
        })
        .into_response(),

        Ok(o) => {
            let stderr = String::from_utf8_lossy(&o.stderr).into_owned();
            let stdout = String::from_utf8_lossy(&o.stdout).into_owned();
            let combined = format!("{}{}", stdout, stderr);

            // Sanitização: remove a senha de qualquer saída acidental
            let sanitized = if let Some(ref pw) = req.password {
                if !pw.is_empty() {
                    combined.replace(pw, "***")
                } else {
                    combined
                }
            } else {
                combined
            };

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

pub async fn wifi_disconnect(
    _: State<Arc<AppState>>,
    Json(req): Json<HashMap<String, String>>,
) -> impl IntoResponse {
    let iface = req
        .get("interface")
        .cloned()
        .unwrap_or_else(|| "wlan0".to_string());

    let output = Command::new("nmcli")
        .args(["device", "disconnect", &iface])
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
    let line = raw.lines().next().unwrap_or("").trim();
    let mut parts = line.splitn(2, ':');
    let state = parts.next().unwrap_or("").to_string();
    let connectivity = parts.next().map(str::to_string);
    (state, connectivity)
}

fn parse_active_connection(raw: &str) -> (ConnType, Option<String>, Option<String>) {
    for line in raw.lines() {
        let parts: Vec<String> = line.split(':').map(|s| s.replace("\\:", ":")).collect();
        if parts.len() < 3 {
            continue;
        }
        let name = parts[0].trim();
        let conn_type_str = parts[1].trim();
        let ip = parts
            .get(3)
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());

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
    fn test_parse_interfaces_full() {
        let raw =
            "enp1s0:ethernet:connected:Wired connection 1:yes\nwlan0:wifi:disconnected:--:yes\n";
        let list = parse_interfaces(raw, true);
        assert_eq!(list.len(), 2);
        assert_eq!(list[0].name, "enp1s0");
        assert_eq!(list[0].connection, Some("Wired connection 1".into()));
        assert!(list[0].managed);
    }

    #[test]
    fn test_parse_interfaces_fallback() {
        let raw = "enp1s0:ethernet:connected:Wired connection 1\n";
        let list = parse_interfaces(raw, false);
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].name, "enp1s0");
        assert!(list[0].managed);
    }

    #[test]
    fn test_parse_wifi_hidden() {
        // nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE ...
        // ":70:WPA2:*"
        let raw = ":70:WPA2:*\nMySSID:90:WPA1: \n";
        // Simulando o parsing interno que faremos em wifi_scan
        let entries: Vec<WifiEntry> = raw
            .lines()
            .filter_map(|line| {
                let parts: Vec<String> = line.split(':').map(|s| s.replace("\\:", ":")).collect();
                if parts.len() < 4 {
                    return None;
                }
                let mut ssid = parts[0].trim().to_string();
                if ssid.is_empty() {
                    ssid = "Rede oculta".into();
                }
                let signal: u8 = parts[1].trim().parse().unwrap_or(0);
                let security = parts[2].trim().to_string();
                let in_use = parts[3].trim() == "*";
                Some(WifiEntry {
                    ssid,
                    signal,
                    security,
                    in_use,
                })
            })
            .collect();

        assert_eq!(entries[0].ssid, "Rede oculta");
        assert_eq!(entries[1].ssid, "MySSID");
    }
}
