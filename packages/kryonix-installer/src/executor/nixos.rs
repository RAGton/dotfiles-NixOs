use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

use super::progress::ProgressEvent;
use crate::InstallPlan;

/// Arquivo de log do `nixos-install` — escrito linha-a-linha conforme stdout/stderr
/// chegam. Exposto via `/debug/target` para diagnóstico mesmo quando o SSE perde
/// a conexão.
pub const NIXOS_INSTALL_LOG: &str = "/tmp/kryonix-nixos-install.log";

pub async fn run_nixos_install(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    let hostname = plan.hostname.trim();
    let flake = "/mnt/etc/kryonixos";
    let flake_ref = format!("{flake}#{hostname}");

    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: "Instalando NixOS (pode demorar)...".into(),
        percent: 50,
    });

    let _ = tx.send(ProgressEvent {
        step: "nixos-install".into(),
        message: format!("Usando flake {flake_ref}"),
        percent: 55,
    });

    // Zera o log antes de spawn para que /debug/target sempre reflita a run
    // mais recente, não acumule histórico de attempts anteriores.
    let _ = tokio::fs::remove_file(NIXOS_INSTALL_LOG).await;
    let log_file = std::sync::Arc::new(tokio::sync::Mutex::new(
        tokio::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(NIXOS_INSTALL_LOG)
            .await
            .map_err(|e| format!("Falha ao abrir log {NIXOS_INSTALL_LOG}: {e}"))?,
    ));

    // Flags canônicas v2: sem --impure, sem --accept-flake-config.
    // --show-trace + --verbose para depuração quando o target falhar.
    let mut child = Command::new("nixos-install")
        .args([
            "--root",
            "/mnt",
            "--no-root-passwd",
            "--no-channel-copy",
            "--show-trace",
            "--verbose",
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
    let log_out = log_file.clone();
    let log_err = log_file.clone();

    let out_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            {
                let mut f = log_out.lock().await;
                let _ = f.write_all(line.as_bytes()).await;
                let _ = f.write_all(b"\n").await;
            }
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
            {
                let mut f = log_err.lock().await;
                let _ = f.write_all(b"[stderr] ").await;
                let _ = f.write_all(line.as_bytes()).await;
                let _ = f.write_all(b"\n").await;
            }
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
    {
        let mut f = log_file.lock().await;
        let _ = f
            .write_all(format!("\n[exit] code={:?}\n", status.code()).as_bytes())
            .await;
        let _ = f.flush().await;
    }

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
        // Anexa o tail do log no erro para que /install/status mostre algo útil
        // mesmo quando o cliente do SSE perdeu a conexão.
        let tail = read_log_tail(NIXOS_INSTALL_LOG, 4000).await;
        Err(format!(
            "nixos-install falhou com código {:?}.\n--- tail {NIXOS_INSTALL_LOG} ---\n{tail}",
            status.code()
        ))
    }
}

async fn read_log_tail(path: &str, max_bytes: usize) -> String {
    match tokio::fs::read_to_string(path).await {
        Ok(content) => {
            if content.len() <= max_bytes {
                content
            } else {
                let start = content.len() - max_bytes;
                format!("...{}", &content[start..])
            }
        }
        Err(e) => format!("(falha ao ler log: {e})"),
    }
}
