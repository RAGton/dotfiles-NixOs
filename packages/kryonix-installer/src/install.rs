#![allow(dead_code)] // Phase 2 — used by PROMPT_04 executor

use serde::{Deserialize, Serialize};
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct InstallConfig {
    pub locale: String,
    pub keyboard: String,
    pub user: String,
    pub network: String,
}

pub async fn generate_configs(config: &InstallConfig) -> Result<(), String> {
    // Generate installer-config.nix dynamically
    let nix_content = format!(
        r#"
{{ config, pkgs, ... }}:
{{
  i18n.defaultLocale = "{}";
  console.keyMap = "{}";
  networking.hostName = "{}";
  users.users.{} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  }};
}}
"#,
        config.locale, config.keyboard, config.network, config.user
    );

    tokio::fs::create_dir_all("/mnt/etc/kryonix")
        .await
        .unwrap_or(());

    tokio::fs::write("/mnt/etc/kryonix/installer-config.nix", nix_content)
        .await
        .map_err(|e| format!("Failed to write installer-config.nix: {}", e))?;

    // Hardware config Generation
    let output = Command::new("nixos-generate-config")
        .args(["--root", "/mnt", "--dir", "/mnt/etc/kryonix"])
        .output()
        .await
        .map_err(|e| format!("nixos-generate-config failed: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    Ok(())
}

pub async fn execute_nixos_install(sender: Arc<broadcast::Sender<String>>) -> Result<(), String> {
    let mut child = Command::new("nixos-install")
        .args([
            "--flake",
            "/mnt/etc/kryonix#target-host",
            "--no-root-passwd",
            "--root",
            "/mnt",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to invoke nixos-install: {}", e))?;

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();

    let sender_out = sender.clone();
    let sender_err = sender.clone();

    let out_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = sender_out.send(line);
        }
    });

    let err_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = sender_err.send(line);
        }
    });

    out_task.await.unwrap();
    err_task.await.unwrap();

    let status = child.wait().await.map_err(|e| e.to_string())?;

    if !status.success() {
        let _ = sender.send("INSTALLATION FAILED".to_string());
        return Err("nixos-install exited with non-zero status".to_string());
    }

    let _ = sender.send("INSTALLATION SUCCESS".to_string());
    Ok(())
}
