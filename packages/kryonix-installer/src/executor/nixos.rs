use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

use super::progress::ProgressEvent;
use crate::InstallPlan;

pub async fn run_nixos_install(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Instalando NixOS (pode demorar)...".into(),
        percent: 50,
    });

    let flake =
        std::env::var("KRYONIX_INSTALLER_FLAKE").unwrap_or_else(|_| "/mnt/etc/kryonixos".to_string());
    let flake_ref = format!("{flake}#{}", plan.hostname);

    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: format!("Usando flake {flake_ref}"),
        percent: 55,
    });

    let mut child = Command::new("nixos-install")
        .args([
            "--root",
            "/mnt",
            "--no-root-passwd",
            "--no-channel-copy",
            "--flake",
            &flake_ref,
        ])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("nixos-install não encontrado: {e}"))?;

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();

    let tx_out = tx.clone();
    let tx_err = tx.clone();

    let out_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = tx_out.send(ProgressEvent {
                step: "nixos-install".into(),
                message: line,
                percent: 60,
            });
        }
    });

    let err_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = tx_err.send(ProgressEvent {
                step: "nixos-install".into(),
                message: line,
                percent: 60,
            });
        }
    });

    out_task.await.map_err(|e| e.to_string())?;
    err_task.await.map_err(|e| e.to_string())?;

    let status = child.wait().await.map_err(|e| e.to_string())?;

    if status.success() {
        // Não declarar "done" aqui: o sucesso só é válido após a verificação
        // estrutural do disco em executor::run_installation.
        let _ = tx.send(ProgressEvent {
            step: "nixos-install".into(),
            message: "nixos-install concluído; aguardando verificação do disco...".into(),
            percent: 90,
        });
        Ok(())
    } else {
        Err("nixos-install falhou com código de erro não-zero".into())
    }
}

