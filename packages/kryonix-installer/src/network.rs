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

// ── POST /network/apply ────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct ApplyNetworkRequest {
    pub interface: String,
    /// "dhcp" | "static"
    pub mode: String,
    /// IPv4 address (required for static mode)
    #[serde(default)]
    pub address: String,
    /// Prefix length 1..32 (required for static mode)
    #[serde(default)]
    pub prefix_length: u8,
    /// Gateway IPv4 (required for static mode, optional for DHCP)
    #[serde(default)]
    pub gateway: String,
    /// DNS servers (comma-separated or array)
    #[serde(default)]
    pub dns: Vec<String>,
}

#[derive(Serialize)]
pub struct ApplyNetworkResponse {
    pub applied: bool,
    pub interface: String,
    pub mode: String,
    pub ip: Option<String>,
    pub gateway: Option<String>,
    pub dns: Vec<String>,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
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

    let (conn_type, mut ip, ssid) = parse_active_connection(&active);

    // Fallback: if connected but no IP from active connection, try device show
    // This handles libvirt/virtio interfaces where IP4.ADDRESS may not appear in active connections
    if ip.is_none() {
        // Get the active interface name from device list
        let devices = nmcli(&["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).await;

        for line in devices.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 4 {
                let device = parts[0].trim();
                let state = parts[2].trim();
                let conn_name = parts[3].trim();
                if state == "connected" && !conn_name.is_empty() && conn_name != "--" {
                    // Found the connected interface, try to get its IP
                    if let Some(device_ip) = get_ip_for_interface(device).await
                        && is_valid_dhcp_ip(&device_ip)
                    {
                        ip = Some(device_ip);
                        break;
                    }
                }
            }
        }
    }

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

    match rescan_res {
        Err(e) => warning = Some(format!("Falha ao invocar nmcli rescan: {e}")),
        Ok(out) if !out.status.success() => {
            warning = Some("Interface Wi-Fi não suporta rescan imediato.".into());
        }
        Ok(_) => {}
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

    entries.sort_by_key(|e| std::cmp::Reverse(e.signal));
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

    if let Some(ref pw) = req.password
        && !pw.is_empty()
    {
        args.push("password".into());
        args.push(pw.clone());
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

// ── POST /network/apply ────────────────────────────────────────────────────────

pub async fn apply_network(
    _: State<Arc<AppState>>,
    Json(req): Json<ApplyNetworkRequest>,
) -> impl IntoResponse {
    // Validação pura — extraída para `validate_apply_network_request` para
    // permitir cobertura por testes unitários sem precisar de runtime axum.
    if let Err((code, msg)) = validate_apply_network_request(&req) {
        return Json(ApplyNetworkResponse {
            interface: req.interface,
            mode: req.mode,
            applied: false,
            ip: None,
            gateway: None,
            dns: req.dns,
            message: msg.into(),
            error: Some(code.into()),
        })
        .into_response();
    }

    let mode = req.mode.to_lowercase();

    // Find the NetworkManager connection name for this interface
    let interface_name = req.interface.clone();
    let connection_name = match find_connection_for_interface(&interface_name).await {
        Some(name) => name,
        None => {
            return Json(ApplyNetworkResponse {
                interface: interface_name.clone(),
                mode: mode.clone(),
                applied: false,
                ip: None,
                gateway: None,
                dns: req.dns,
                message: format!(
                    "Nenhuma conexão NetworkManager encontrada para interface {}",
                    interface_name
                ),
                error: Some("NO_CONNECTION".into()),
            })
            .into_response();
        }
    };

    let dns_str = if req.dns.is_empty() {
        String::new()
    } else {
        req.dns.join(",")
    };

    // Apply configuration
    let apply_result = if mode == "dhcp" {
        apply_dhcp(&connection_name, &interface_name, &dns_str).await
    } else {
        let address_with_prefix = format!("{}/{}", req.address, req.prefix_length);
        apply_static(
            &connection_name,
            &interface_name,
            &address_with_prefix,
            &req.gateway,
            &dns_str,
        )
        .await
    };

    match apply_result {
        Ok((ip, gateway, actual_dns)) => Json(ApplyNetworkResponse {
            interface: interface_name.clone(),
            mode: mode.clone(),
            applied: true,
            ip: Some(ip.clone()),
            gateway: Some(gateway.clone()),
            dns: actual_dns,
            message: format!("Rede aplicada com sucesso: {} ({})", ip, mode),
            error: None,
        })
        .into_response(),
        Err(e) => Json(ApplyNetworkResponse {
            interface: interface_name.clone(),
            mode: mode.clone(),
            applied: false,
            ip: None,
            gateway: None,
            dns: req.dns,
            message: format!("Falha ao aplicar configuração: {}", e),
            error: Some("APPLY_FAILED".into()),
        })
        .into_response(),
    }
}

async fn find_connection_for_interface(interface: &str) -> Option<String> {
    // First try to get the connection name from device show
    let output = Command::new("nmcli")
        .args([
            "-t",
            "-f",
            "GENERAL.CONNECTION",
            "device",
            "show",
            interface,
        ])
        .output()
        .await
        .ok()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        if line.starts_with("GENERAL.CONNECTION:") {
            let conn = line.split(':').nth(1)?.trim();
            if !conn.is_empty() && conn != "--" {
                return Some(conn.to_string());
            }
        }
    }
    // Fallback: try to find by connection list
    let output = Command::new("nmcli")
        .args(["-t", "-f", "NAME,DEVICE", "connection", "show"])
        .output()
        .await
        .ok()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 2 && parts[1].trim() == interface {
            return Some(parts[0].trim().to_string());
        }
    }
    None
}

async fn apply_dhcp(
    connection: &str,
    interface: &str,
    dns: &str,
) -> Result<(String, String, Vec<String>), String> {
    // Set connection to DHCP
    let mut args = vec![
        "con",
        "mod",
        connection,
        "ipv4.method",
        "auto",
        "ipv4.addresses",
        "",
        "ipv4.gateway",
        "",
    ];
    if !dns.is_empty() {
        args.push("ipv4.dns");
        args.push(dns);
        args.push("ipv4.ignore-auto-dns");
        args.push("yes");
    } else {
        args.push("ipv4.dns");
        args.push("");
        args.push("ipv4.ignore-auto-dns");
        args.push("no");
    }

    let output = Command::new("nmcli")
        .args(&args)
        .output()
        .await
        .map_err(|e| format!("nmcli con mod failed: {}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("nmcli con mod failed: {}", stderr));
    }

    // Bring up the connection
    let output = Command::new("nmcli")
        .args(["con", "up", connection])
        .output()
        .await
        .map_err(|e| format!("nmcli con up failed: {}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("nmcli con up failed: {}", stderr));
    }

    // Wait for DHCP to assign IP (up to 30 seconds)
    let ip = wait_for_dhcp_ip(interface, 30).await?;

    // Get gateway and DNS
    let gateway = get_gateway_for_interface(interface)
        .await
        .unwrap_or_default();
    let dns_servers = get_dns_for_interface(interface).await;

    Ok((ip, gateway, dns_servers))
}

async fn apply_static(
    connection: &str,
    interface: &str,
    address_prefix: &str,
    gateway: &str,
    dns: &str,
) -> Result<(String, String, Vec<String>), String> {
    let mut args = vec![
        "con",
        "mod",
        connection,
        "ipv4.method",
        "manual",
        "ipv4.addresses",
        address_prefix,
        "ipv4.gateway",
        gateway,
    ];
    if !dns.is_empty() {
        args.push("ipv4.dns");
        args.push(dns);
        args.push("ipv4.ignore-auto-dns");
        args.push("yes");
    } else {
        args.push("ipv4.dns");
        args.push("");
        args.push("ipv4.ignore-auto-dns");
        args.push("no");
    }

    let output = Command::new("nmcli")
        .args(&args)
        .output()
        .await
        .map_err(|e| format!("nmcli con mod failed: {}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("nmcli con mod failed: {}", stderr));
    }

    // Bring up the connection
    let output = Command::new("nmcli")
        .args(["con", "up", connection])
        .output()
        .await
        .map_err(|e| format!("nmcli con up failed: {}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("nmcli con up failed: {}", stderr));
    }

    // Verify IP is applied
    let ip = get_ip_for_interface(interface)
        .await
        .ok_or_else(|| "IP não configurado na interface".to_string())?;

    let dns_servers = if dns.is_empty() {
        vec![]
    } else {
        dns.split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect()
    };

    Ok((ip, gateway.to_string(), dns_servers))
}

async fn wait_for_dhcp_ip(interface: &str, timeout_seconds: u64) -> Result<String, String> {
    use std::time::Duration;
    use tokio::time::sleep;

    let start = std::time::Instant::now();
    while start.elapsed() < Duration::from_secs(timeout_seconds) {
        if let Some(ip) = get_ip_for_interface(interface).await
            && is_valid_dhcp_ip(&ip)
        {
            return Ok(ip);
        }
        sleep(Duration::from_millis(1000)).await;
    }
    Err("Timeout aguardando DHCP".into())
}

fn is_valid_dhcp_ip(ip: &str) -> bool {
    if ip.is_empty() || ip == "0.0.0.0" {
        return false;
    }
    if ip.starts_with("127.") || ip.starts_with("169.254.") {
        return false;
    }
    is_valid_ipv4(ip)
}

fn is_valid_ipv4(ip: &str) -> bool {
    let parts: Vec<&str> = ip.split('.').collect();
    if parts.len() != 4 {
        return false;
    }
    // `parse::<u8>()` já cobre o range 0..=255; comparação extra é redundante.
    parts.iter().all(|p| p.parse::<u8>().is_ok())
}

async fn get_ip_for_interface(interface: &str) -> Option<String> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "IP4.ADDRESS", "device", "show", interface])
        .output()
        .await
        .ok()?;

    let stdout = String::from_utf8_lossy(&output.stdout);

    for line in stdout.lines() {
        if !line.starts_with("IP4.ADDRESS") {
            continue;
        }

        let (_, value) = line.split_once(':')?;
        let ip = value.trim().split('/').next()?.trim();

        if is_valid_dhcp_ip(ip) {
            return Some(ip.to_string());
        }
    }

    None
}

async fn get_gateway_for_interface(interface: &str) -> Option<String> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "IP4.GATEWAY", "device", "show", interface])
        .output()
        .await
        .ok()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        if line.starts_with("IP4.GATEWAY:") {
            let gw = line.split(':').nth(1)?.trim();
            if !gw.is_empty() && gw != "0.0.0.0" {
                return Some(gw.to_string());
            }
        }
    }
    None
}

async fn get_dns_for_interface(interface: &str) -> Vec<String> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "IP4.DNS", "device", "show", interface])
        .output()
        .await;
    let Ok(output) = output else {
        return Vec::new();
    };
    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut dns = Vec::new();
    for line in stdout.lines() {
        if line.starts_with("IP4.DNS:") {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() < 2 {
                continue;
            }
            let dns_str = parts[1].trim();
            if !dns_str.is_empty() {
                for d in dns_str.split(',') {
                    let d = d.trim();
                    if !d.is_empty() && is_valid_ipv4(d) {
                        dns.push(d.to_string());
                    }
                }
            }
        }
    }
    dns
}

/// Validação pura para `ApplyNetworkRequest`. Retorna `Ok(())` quando o
/// payload é aceitável; senão um par `(error_code, mensagem)` que o handler
/// `apply_network` repassa em `ApplyNetworkResponse`.
///
/// Erros de DNS rejeitam apenas valores não-vazios mal-formatados; strings
/// vazias no array são ignoradas (compat com o front).
pub(crate) fn validate_apply_network_request(
    req: &ApplyNetworkRequest,
) -> Result<(), (&'static str, &'static str)> {
    if req.interface.trim().is_empty() {
        return Err(("INTERFACE_EMPTY", "Interface não informada"));
    }
    let mode = req.mode.to_lowercase();
    if mode != "dhcp" && mode != "static" {
        return Err(("INVALID_MODE", "Modo deve ser 'dhcp' ou 'static'"));
    }
    if mode == "static" {
        if req.address.trim().is_empty() {
            return Err(("MISSING_ADDRESS", "IP address é obrigatório no modo static"));
        }
        if req.prefix_length == 0 || req.prefix_length > 32 {
            return Err(("INVALID_PREFIX", "Prefix length deve ser entre 1 e 32"));
        }
        if req.gateway.trim().is_empty() {
            return Err(("MISSING_GATEWAY", "Gateway é obrigatório no modo static"));
        }
        if !is_valid_ipv4(&req.address) || !is_valid_ipv4(&req.gateway) {
            return Err((
                "INVALID_IPV4",
                "IP address ou gateway com formato IPv4 inválido",
            ));
        }
    }
    for d in &req.dns {
        let t = d.trim();
        if !t.is_empty() && !is_valid_ipv4(t) {
            return Err(("INVALID_DNS", "DNS contém endereço IPv4 inválido"));
        }
    }
    Ok(())
}

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

    fn make_apply_req(mode: &str) -> ApplyNetworkRequest {
        ApplyNetworkRequest {
            interface: "enp1s0".into(),
            mode: mode.into(),
            address: String::new(),
            prefix_length: 0,
            gateway: String::new(),
            dns: vec![],
        }
    }

    fn make_static_req() -> ApplyNetworkRequest {
        ApplyNetworkRequest {
            interface: "enp1s0".into(),
            mode: "static".into(),
            address: "192.168.1.10".into(),
            prefix_length: 24,
            gateway: "192.168.1.1".into(),
            dns: vec!["1.1.1.1".into(), "8.8.8.8".into()],
        }
    }

    #[test]
    fn test_validate_apply_dhcp_ok() {
        let req = make_apply_req("dhcp");
        assert!(validate_apply_network_request(&req).is_ok());
    }

    #[test]
    fn test_validate_apply_static_ok() {
        let req = make_static_req();
        assert!(validate_apply_network_request(&req).is_ok());
    }

    #[test]
    fn test_validate_apply_rejects_invalid_ipv4_address() {
        let mut req = make_static_req();
        req.address = "999.0.0.1".into();
        let err = validate_apply_network_request(&req).unwrap_err();
        assert_eq!(err.0, "INVALID_IPV4");
    }

    #[test]
    fn test_validate_apply_rejects_invalid_gateway() {
        let mut req = make_static_req();
        req.gateway = "not.an.ip".into();
        let err = validate_apply_network_request(&req).unwrap_err();
        assert_eq!(err.0, "INVALID_IPV4");
    }

    #[test]
    fn test_validate_apply_rejects_invalid_prefix() {
        let mut req = make_static_req();
        req.prefix_length = 33;
        let err = validate_apply_network_request(&req).unwrap_err();
        assert_eq!(err.0, "INVALID_PREFIX");

        req.prefix_length = 0;
        let err = validate_apply_network_request(&req).unwrap_err();
        assert_eq!(err.0, "INVALID_PREFIX");
    }

    #[test]
    fn test_validate_apply_rejects_invalid_dns() {
        let mut req = make_static_req();
        req.dns = vec!["1.1.1.1".into(), "bogus".into()];
        let err = validate_apply_network_request(&req).unwrap_err();
        assert_eq!(err.0, "INVALID_DNS");
    }

    #[test]
    fn test_validate_apply_dns_empty_strings_are_ignored() {
        // Front pode mandar `dns: [""]` quando o usuário deixa o campo em branco.
        // Esses entries vazios não devem disparar INVALID_DNS.
        let mut req = make_apply_req("dhcp");
        req.dns = vec!["".into(), "  ".into()];
        assert!(validate_apply_network_request(&req).is_ok());
    }
}
