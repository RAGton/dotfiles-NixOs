use crate::domain::manifest::SystemManifest;
use std::fs;
use std::process::Command;

pub fn report_heartbeat() -> Result<(), String> {
    println!("[INFO] Lendo manifesto do sistema...");
    let manifest_content = fs::read_to_string("/var/lib/kryonix/manifest.json")
        .map_err(|e| format!("Falha ao ler /var/lib/kryonix/manifest.json: {}", e))?;

    let manifest: SystemManifest = serde_json::from_str(&manifest_content)
        .map_err(|e| format!("Falha ao parsear manifest.json: {}", e))?;

    println!("[PASS] Manifesto lido com sucesso.");

    let zfs_usage = Command::new("zpool")
        .args(&["list", "-H", "-o", "capacity"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "unknown".to_string());

    let cpu_temp = fs::read_to_string("/sys/class/thermal/thermal_zone0/temp")
        .map(|s| {
            let millidegrees: i32 = s.trim().parse().unwrap_or(0);
            format!("{}C", millidegrees / 1000)
        })
        .unwrap_or_else(|_| "unknown".to_string());

    let net_status = "Online";

    let payload = serde_json::json!({
        "manifest": manifest,
        "metrics": {
            "zfs_capacity": zfs_usage,
            "cpu_temp": cpu_temp,
            "network": net_status,
        }
    });

    println!("[INFO] Enviando telemetria: {}", payload);

    let target_url = "http://thinkserver.local/api/telemetry"; // URL do Core

    match ureq::post(target_url).send_json(&payload) {
        Ok(_) => {
            println!("[PASS] Telemetria enviada com sucesso para {}", target_url);
        }
        Err(e) => {
            eprintln!("[WARN] Falha ao enviar telemetria HTTP: {}", e);
        }
    }

    Ok(())
}
