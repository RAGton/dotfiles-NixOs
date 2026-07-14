// MIGRATION STATUS:
// - run_switch: NATIVO (Rust)

use colored::Colorize;
use std::fs;
use std::process::{Command, Stdio};

pub fn run_switch() -> Result<(), String> {
    println!(
        "{} Iniciando operação atômica de switch...",
        "[INFO]".cyan()
    );

    // 1. Validate if the git tree is clean
    let git_status = Command::new("git")
        .arg("status")
        .arg("--porcelain")
        .output()
        .map_err(|e| format!("Falha ao executar 'git status': {}", e))?;

    if !git_status.stdout.is_empty() {
        return Err(format!(
            "{}\n{}",
            "A árvore do git não está limpa. Faça commit ou stash das suas alterações antes de executar o switch.",
            String::from_utf8_lossy(&git_status.stdout)
        ));
    }

    // 2. Identify the target hostname
    let hostname = fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "default".to_string())
        .trim()
        .to_string();

    println!("{} Flake target: .#{}", "[INFO]".cyan(), hostname);

    // 3. Run nixos-rebuild switch
    println!("{} Executando nixos-rebuild switch...", "[INFO]".cyan());

    let status = Command::new("nixos-rebuild")
        .arg("switch")
        .arg("--flake")
        .arg(&format!(".#{}", hostname))
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(|e| format!("Falha ao invocar 'nixos-rebuild': {}", e))?;

    if status.success() {
        println!(
            "{} Switch do sistema concluído com sucesso!",
            "[PASS]".green()
        );
        Ok(())
    } else {
        Err(format!(
            "nixos-rebuild switch abortado ou falhou com status: {}",
            status
        ))
    }
}
