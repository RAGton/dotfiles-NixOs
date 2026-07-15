use colored::Colorize;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

// Abstração simples para comandos de sistema para facilitar a testabilidade.
pub trait CommandRunner {
    fn run(&self, cmd: &str, args: &[&str]) -> Result<bool, String>;
    fn copy_config(&self, src: &Path) -> Result<(), String>;
}

pub struct RealCommandRunner;
impl CommandRunner for RealCommandRunner {
    fn run(&self, cmd: &str, args: &[&str]) -> Result<bool, String> {
        let output = Command::new(cmd)
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .map_err(|e| format!("Falha ao invocar comando '{}': {}", cmd, e))?;

        if !output.status.success() {
            let err_msg = String::from_utf8_lossy(&output.stderr);
            return Err(format!(
                "Deploy falhou com código {}: {}",
                output.status, err_msg
            ));
        }
        Ok(true)
    }

    fn copy_config(&self, src: &Path) -> Result<(), String> {
        let dest_dir = Path::new("/mnt/etc/kryonixos/systems");
        if !dest_dir.exists() {
            fs::create_dir_all(dest_dir).map_err(|e| {
                format!("Falha ao criar diretório /mnt/etc/kryonixos/systems: {}", e)
            })?;
        }
        let dest_file = dest_dir.join("generated-install-config.nix");
        fs::copy(src, &dest_file).map_err(|e| {
            format!(
                "Falha ao injetar configuração Nix em {}: {}",
                dest_file.display(),
                e
            )
        })?;
        Ok(())
    }
}

pub fn run_deploy(config_path: Option<&str>, hostname: Option<&str>) -> Result<(), String> {
    run_deploy_inner(config_path, hostname, &RealCommandRunner)
}

fn run_deploy_inner(
    config_path: Option<&str>,
    hostname: Option<&str>,
    runner: &dyn CommandRunner,
) -> Result<(), String> {
    println!(
        "{} Iniciando pipeline de Deploy (Orquestração Rust)...",
        "[INFO]".cyan()
    );

    let path_str =
        config_path.ok_or_else(|| "Caminho da configuração não fornecido.".to_string())?;
    let path = Path::new(path_str);

    if !path.exists() {
        return Err(format!(
            "Arquivo de configuração não encontrado: {}",
            path_str
        ));
    }

    println!(
        "{} Acionando o disko para particionamento...",
        "[INFO]".cyan()
    );

    // 1. Particionamento Disko via arquivo direto (sem --flake)
    let disko_success = runner.run(
        "sudo",
        &[
            "nix",
            "run",
            "github:nix-community/disko",
            "--",
            "--mode",
            "destroy,format,mount",
            path_str,
        ],
    )?;

    // Blindagem de Erro: Interromper imediatamente
    if !disko_success {
        return Err(
            "Disko falhou. O particionamento não foi concluído. Abortando deploy.".to_string(),
        );
    }

    // Preparação do destino determinístico em /mnt/etc/kryonixos/
    println!(
        "{} Copiando configuração gerada para /mnt...",
        "[INFO]".cyan()
    );
    runner.copy_config(path)?;

    println!("{} Instalando o NixOS no alvo...", "[INFO]".cyan());

    // 2. Instalação do Sistema
    let host_target = format!(".#{}", hostname.unwrap_or("thinkServer"));
    let install_success = runner.run(
        "sudo",
        &[
            "nixos-install",
            "--target-directory",
            "/mnt",
            "--flake",
            &host_target,
            "--no-root-passwd",
        ],
    )?;

    if install_success {
        println!("{} Deploy concluído com sucesso!", "[PASS]".green());

        println!(
            "{} Gravando estado de instalação (state.json)...",
            "[INFO]".cyan()
        );
        let state_json = format!(
            r#"{{"status": "installed", "timestamp": "{}"}}"#,
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        );
        let _ = fs::write("/mnt/etc/kryonixos/state.json", state_json);

        println!(
            "{} Gerando manifesto de estado da máquina...",
            "[INFO]".cyan()
        );
        use crate::domain::manifest::{SystemManifest, SystemStatus};
        use chrono::Utc;
        let uuid = crate::services::identity::check_identity()
            .map(|i| i.uuid)
            .unwrap_or_else(|_| "unknown".to_string());

        let manifest = SystemManifest {
            uuid,
            timestamp: Utc::now(),
            flake_revision: "unknown".to_string(), // TODO: ler do git
            features_enabled: vec![],              // TODO: coletar do /etc/kryonix/features.json
            status: SystemStatus::Healthy,
        };

        if let Ok(json_str) = serde_json::to_string_pretty(&manifest) {
            let manifest_dir = Path::new("/mnt/var/lib/kryonix");
            if !manifest_dir.exists() {
                let _ = fs::create_dir_all(manifest_dir);
            }
            let _ = fs::write("/mnt/var/lib/kryonix/manifest.json", json_str);
        }

        Ok(())
    } else {
        Err("nixos-install falhou.".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::fs;

    struct MockRunner {
        disko_result: Result<bool, String>,
        install_result: Result<bool, String>,
        commands_run: RefCell<Vec<String>>,
    }

    impl CommandRunner for MockRunner {
        fn run(&self, cmd: &str, args: &[&str]) -> Result<bool, String> {
            let full_cmd = format!("{} {}", cmd, args.join(" "));
            self.commands_run.borrow_mut().push(full_cmd.clone());

            if full_cmd.contains("disko") {
                self.disko_result.clone()
            } else if full_cmd.contains("nixos-install") {
                self.install_result.clone()
            } else {
                Ok(true)
            }
        }

        fn copy_config(&self, _src: &Path) -> Result<(), String> {
            self.commands_run
                .borrow_mut()
                .push("COPY_CONFIG".to_string());
            Ok(())
        }
    }

    #[test]
    fn test_deploy_fails_if_disko_fails() {
        let path_buf = std::env::temp_dir().join("mock");
        fs::write(&path_buf, "mock").unwrap();
        let path = path_buf.to_str().unwrap();

        let runner = MockRunner {
            disko_result: Ok(false), // Simula falha do disko
            install_result: Ok(true),
            commands_run: RefCell::new(vec![]),
        };

        let result = run_deploy_inner(Some(path), Some("testServer"), &runner);

        assert!(result.is_err());
        assert_eq!(
            result.unwrap_err(),
            "Disko falhou. O particionamento não foi concluído. Abortando deploy."
        );

        let cmds = runner.commands_run.borrow();
        // A cópia pro FS e o nixos-install não devem rodar.
        assert!(!cmds.contains(&"COPY_CONFIG".to_string()));
        assert!(!cmds.iter().any(|c| c.contains("nixos-install")));
    }

    #[test]
    fn test_deploy_success() {
        let path_buf = std::env::temp_dir().join("mock");
        fs::write(&path_buf, "mock").unwrap();
        let path = path_buf.to_str().unwrap();

        let runner = MockRunner {
            disko_result: Ok(true),
            install_result: Ok(true),
            commands_run: RefCell::new(vec![]),
        };

        let result = run_deploy_inner(Some(path), Some("testServer"), &runner);

        assert!(result.is_ok());

        let cmds = runner.commands_run.borrow();
        assert!(cmds.iter().any(|c| c.contains("disko")));
        assert!(cmds.contains(&"COPY_CONFIG".to_string()));
        assert!(cmds.iter().any(|c| c.contains("nixos-install")));
    }
}

pub fn run_factory_reset(preserve_home: bool) -> Result<(), String> {
    println!("{} Iniciando modo Factory Reset...", "[WARN]".yellow());

    // Confirmação interativa
    println!(
        "{} ATENÇÃO: Isso apagará dados e reconfigurará o sistema.",
        "[CRITICAL]".red()
    );
    if preserve_home {
        println!("{} (A partição /home será PRESERVADA)", "[INFO]".cyan());
    } else {
        println!("{} (A partição /home será DESTRUÍDA)", "[CRITICAL]".red());
    }

    print!("Tem certeza que deseja continuar? [y/N]: ");
    use std::io::{self, Write};
    io::stdout()
        .flush()
        .map_err(|e| format!("Erro IO: {}", e))?;
    let mut input = String::new();
    io::stdin()
        .read_line(&mut input)
        .map_err(|e| format!("Erro IO: {}", e))?;
    if input.trim().to_lowercase() != "y" {
        return Err("Reset cancelado pelo usuário.".to_string());
    }

    let runner = RealCommandRunner;

    // Se `--preserve-home` for falso, usamos `zap_create_mount` para destruir e recriar.
    // Caso contrário, `disko` fará um remount seguro.
    let mode = if preserve_home {
        "disko"
    } else {
        "zap_create_mount"
    };

    println!("{} Executando Disko [modo: {}]...", "[INFO]".cyan(), mode);
    let disko_success = runner.run(
        "sudo",
        &[
            "nix",
            "run",
            "github:nix-community/disko",
            "--",
            "--mode",
            mode,
            "--flake",
            ".#installer",
        ],
    )?;

    if !disko_success {
        return Err("Disko falhou durante o reset.".to_string());
    }

    println!("{} Reinstalando NixOS (Factory Reset)...", "[INFO]".cyan());
    let install_success = runner.run(
        "sudo",
        &[
            "nixos-install",
            "--target-directory",
            "/mnt",
            "--flake",
            ".#srv-rag",
            "--no-root-passwd",
        ],
    )?;

    if install_success {
        println!("{} Factory Reset concluído com sucesso!", "[PASS]".green());
        let state_json = format!(
            r#"{{"status": "installed", "timestamp": "{}"}}"#,
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        );
        let _ = fs::write("/mnt/etc/kryonixos/state.json", state_json);
        Ok(())
    } else {
        Err("nixos-install falhou no Factory Reset.".to_string())
    }
}
