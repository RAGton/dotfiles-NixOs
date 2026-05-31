use std::process::Command;
use std::path::Path;
use tokio::sync::broadcast;
use tracing::{info, error};

pub async fn orchestrate_installation(host: &str, progress_tx: broadcast::Sender<String>) -> Result<(), String> {
    let repo_path = "/etc/kryonixos";
    let disks_nix = format!("{}/hosts/{}/disks.nix", repo_path, host);
    
    // 1. Validate disks.nix existence
    if !Path::new(&disks_nix).exists() {
        return Err(format!("Configuração de disco não encontrada para o host {}. Execute o Disk Planner primeiro.", host));
    }

    let send_update = |msg: &str| {
        info!("{}", msg);
        let _ = progress_tx.send(msg.to_string());
    };

    // 2. Execute Disko
    send_update("🚀 Iniciando particionamento e formatação (Disko)...");
    let disko_status = Command::new("sudo")
        .arg("disko")
        .arg("--mode")
        .arg("disko")
        .arg(&disks_nix)
        .status()
        .map_err(|e| format!("Falha ao iniciar disko: {}", e))?;

    if !disko_status.success() {
        return Err("O particionamento via Disko falhou. Verifique os logs do console.".to_string());
    }
    send_update("✅ Particionamento concluído com sucesso.");

    // 3. Execute nixos-install
    send_update(&format!("📦 Iniciando nixos-install para o host '{}'...", host));
    let install_status = Command::new("sudo")
        .arg("nixos-install")
        .arg("--flake")
        .arg(format!("{}#{}", repo_path, host))
        .arg("--no-channel-copy")
        .status()
        .map_err(|e| format!("Falha ao iniciar nixos-install: {}", e))?;

    if !install_status.success() {
        return Err("A instalação do NixOS falhou. Verifique os logs do console.".to_string());
    }
    send_update("✅ NixOS instalado com sucesso.");

    // 4. Create flag file
    send_update("🚩 Finalizando ambiente...");
    let flag_path = "/mnt/etc/kryonix-installed";
    let create_flag = Command::new("sudo")
        .arg("touch")
        .arg(flag_path)
        .status()
        .map_err(|e| format!("Falha ao criar flag de instalação: {}", e))?;

    if !create_flag.success() {
        error!("Aviso: Não foi possível criar o arquivo de flag em {}", flag_path);
    }

    // 5. Final message
    send_update("🎉 Instalação concluída. Sistema pronto para o primeiro boot.");

    Ok(())
}
