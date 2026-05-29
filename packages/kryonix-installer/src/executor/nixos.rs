use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

use crate::InstallPlan;
use super::progress::ProgressEvent;

pub async fn run_nixos_install(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Gerando configuração NixOS...".into(),
        percent: 40,
    });

    write_nixos_config(plan).await?;

    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Instalando NixOS (pode demorar)...".into(),
        percent: 50,
    });

    let mut child = Command::new("nixos-install")
        .args([
            "--root", "/mnt",
            "--no-root-passwd",
            "--flake", &format!("/etc/kryonix#{}", plan.hostname),
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
        let _ = tx.send(ProgressEvent {
            step: "done".into(),
            message: "Instalação concluída! Reinicie para usar o Kryonix.".into(),
            percent: 100,
        });
        Ok(())
    } else {
        Err("nixos-install falhou com código de erro não-zero".into())
    }
}

async fn write_nixos_config(plan: &InstallPlan) -> Result<(), String> {
    let config = format!(
        r#"{{ config, pkgs, ... }}:
{{
  i18n.defaultLocale = "{locale}";
  console.keyMap = "{keyboard}";
  time.timeZone = "{timezone}";
  networking.hostName = "{hostname}";
  users.users.{user} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  }};
}}
"#,
        locale = plan.locale,
        keyboard = plan.keyboard,
        timezone = plan.timezone,
        hostname = plan.hostname,
        user = plan.user.name,
    );

    tokio::fs::create_dir_all("/mnt/etc/nixos")
        .await
        .map_err(|e| format!("Falha ao criar /mnt/etc/nixos: {e}"))?;

    tokio::fs::write("/mnt/etc/nixos/configuration.nix", config)
        .await
        .map_err(|e| format!("Falha ao escrever configuration.nix: {e}"))
}
