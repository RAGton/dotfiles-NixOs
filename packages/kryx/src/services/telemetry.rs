use crate::domain::manifest::SystemManifest;
use std::fs;

pub fn report_heartbeat() -> Result<(), String> {
    println!("[INFO] Lendo manifesto do sistema...");
    let manifest_content = fs::read_to_string("/var/lib/kryonix/manifest.json")
        .map_err(|e| format!("Falha ao ler /var/lib/kryonix/manifest.json: {}", e))?;

    let manifest: SystemManifest = serde_json::from_str(&manifest_content)
        .map_err(|e| format!("Falha ao parsear manifest.json: {}", e))?;

    println!("[PASS] Manifesto lido com sucesso.");
    println!("UUID: {}", manifest.uuid);
    println!("Status: {:?}", manifest.status);
    println!("Último Deploy: {}", manifest.timestamp);
    
    // Futuro: Coletar métricas básicas de hardware (ZFS, CPU, etc) e enviar POST via ureq/reqwest
    println!("[INFO] Coleta de hardware e envio de telemetria pendentes de implementação.");

    Ok(())
}
