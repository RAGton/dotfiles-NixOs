use anyhow::Result;
use notify::{Config, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::process::Command;
use tokio::sync::{broadcast, mpsc};
use tracing::{error, info, warn};

pub async fn run_watcher(sse_tx: broadcast::Sender<String>) -> Result<()> {
    // Canonical path in downstream repo
    // The user mentioned /etc/kryonixos/user/caelestia/shell.json
    let repo_path = "/etc/kryonixos";
    let target_file = format!("{}/user/caelestia/shell.json", repo_path);
    let target_path = Path::new(&target_file);

    if !target_path.exists() {
        warn!("Target file {} does not exist. Waiting for it...", target_file);
        // In a real scenario, we might want to watch the parent directory if the file doesn't exist.
    }

    let (tx, mut rx) = mpsc::channel(100);

    // Bridge notify (sync) to tokio (async)
    let mut watcher = RecommendedWatcher::new(
        move |res| {
            if let Ok(_) = res {
                let _ = tx.blocking_send(());
            }
        },
        Config::default(),
    )?;

    // We watch the caelestia directory specifically if it exists, otherwise the repo.
    let watch_dir = format!("{}/user/caelestia", repo_path);
    if Path::new(&watch_dir).exists() {
        watcher.watch(Path::new(&watch_dir), RecursiveMode::Recursive)?;
    } else {
        watcher.watch(Path::new(repo_path), RecursiveMode::Recursive)?;
    }

    info!("Watcher started on {}", watch_dir);

    let mut is_debouncing = false;
    let sleep_duration = std::time::Duration::from_secs(2);
    let mut sleep = Box::pin(tokio::time::sleep(sleep_duration));

    loop {
        tokio::select! {
            Some(_) = rx.recv() => {
                if !is_debouncing {
                    info!("Change detected, starting debounce...");
                    let _ = sse_tx.send("Saving...".into());
                }
                is_debouncing = true;
                sleep = Box::pin(tokio::time::sleep(sleep_duration));
            }
            _ = &mut sleep, if is_debouncing => {
                is_debouncing = false;
                info!("Debounce finished. Validating and committing...");
                
                match validate_and_commit(&target_file, repo_path).await {
                    Ok(_) => {
                        info!("Changes committed successfully.");
                        let _ = sse_tx.send("Salvo".into());
                    }
                    Err(e) => {
                        error!("Failed to commit changes: {}", e);
                        let _ = sse_tx.send(format!("Erro: {}", e));
                    }
                }
            }
        }
    }
}

async fn validate_and_commit(file_path: &str, repo_path: &str) -> Result<()> {
    // 1. Validate JSON (ensure we don't commit garbage)
    let content = tokio::fs::read_to_string(file_path).await?;
    let _: serde_json::Value = serde_json::from_str(&content)?;

    // 2. Git Operations with Lock Handling
    // We use a retry loop to handle potential 'index.lock' from concurrent manual 'kryonix' commands
    let mut attempts = 0;
    let max_attempts = 5;
    let retry_delay = std::time::Duration::from_millis(500);

    loop {
        // Check for index.lock
        let lock_path = Path::new(repo_path).join(".git/index.lock");
        if lock_path.exists() {
            if attempts >= max_attempts {
                return Err(anyhow::anyhow!("Git repository is locked after {} attempts. Aborting auto-save.", max_attempts));
            }
            warn!("Git lock detected, retrying in {:?}...", retry_delay);
            tokio::time::sleep(retry_delay).await;
            attempts += 1;
            continue;
        }

        // git add
        let add_status = Command::new("git")
            .arg("-C")
            .arg(repo_path)
            .arg("add")
            .arg("user/caelestia/")
            .status()?;

        if !add_status.success() {
            return Err(anyhow::anyhow!("git add failed"));
        }

        // Check for changes (don't commit if nothing changed)
        let diff_status = Command::new("git")
            .arg("-C")
            .arg(repo_path)
            .arg("diff")
            .arg("--cached")
            .arg("--quiet")
            .status()?;

        if diff_status.success() {
            info!("No changes to commit.");
            return Ok(());
        }

        // git commit
        let msg = format!("caelestia: auto-save settings {}", chrono::Local::now().format("%Y-%m-%d %H:%M:%S"));
        let commit_status = Command::new("git")
            .arg("-C")
            .arg(repo_path)
            .arg("commit")
            .arg("-m")
            .arg(msg)
            .status()?;

        if commit_status.success() {
            return Ok(());
        } else {
            // It might have been locked right before the commit
            if attempts >= max_attempts {
                return Err(anyhow::anyhow!("git commit failed after multiple attempts"));
            }
            attempts += 1;
            tokio::time::sleep(retry_delay).await;
        }
    }
}
