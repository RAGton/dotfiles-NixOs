use colored::Colorize;
use std::path::Path;
use std::process::{Command, Stdio};

pub fn run_deploy(plan_file: Option<&String>) -> Result<(), String> {
    println!(
        "{} Iniciando pipeline de Deploy (Orquestração Rust)...",
        "[INFO]".cyan()
    );

    // Validation
    let plan_path = plan_file
        .map(|s| s.as_str())
        .unwrap_or("./install-plan.json");
    if !Path::new(plan_path).exists() {
        println!(
            "{} Plano de instalação não encontrado: {}. Ignorando etapa de validação estrita.",
            "[WARN]".yellow(),
            plan_path
        );
    } else {
        println!(
            "{} Validando configuração com kryonix-disk-planner...",
            "[INFO]".cyan()
        );
        let planner_status = Command::new("nix")
            .arg("run")
            .arg(".#kryonix-disk-planner")
            .arg("--")
            .arg("validate")
            .arg(plan_path)
            .status()
            .map_err(|e| format!("Falha ao invocar kryonix-disk-planner: {}", e))?;

        if !planner_status.success() {
            return Err("Validação do disk-planner falhou. Abortando deploy.".to_string());
        }
    }

    println!(
        "{} Acionando o disko para particionamento...",
        "[INFO]".cyan()
    );
    let disko_status = Command::new("sudo")
        .arg("nix")
        .arg("run")
        .arg("github:nix-community/disko")
        .arg("--")
        .arg("--mode")
        .arg("disko")
        .arg("--flake")
        .arg(".#installer")
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(|e| format!("Falha ao invocar o disko: {}", e))?;

    if !disko_status.success() {
        return Err("Disko falhou. O particionamento não foi concluído.".to_string());
    }

    println!("{} Instalando o NixOS no alvo...", "[INFO]".cyan());
    let install_status = Command::new("sudo")
        .arg("nixos-install")
        .arg("--flake")
        .arg(".#srv-rag")
        .arg("--no-root-passwd")
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(|e| format!("Falha ao invocar nixos-install: {}", e))?;

    if install_status.success() {
        println!("{} Deploy concluído com sucesso!", "[PASS]".green());
        Ok(())
    } else {
        Err("nixos-install falhou.".to_string())
    }
}
