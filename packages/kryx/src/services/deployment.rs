use colored::Colorize;
use std::path::Path;
use std::process::{Command, Stdio};
use std::fs;

// Abstração simples para comandos de sistema para facilitar a testabilidade.
pub trait CommandRunner {
    fn run(&self, cmd: &str, args: &[&str]) -> Result<bool, String>;
    fn copy_config(&self, src: &Path) -> Result<(), String>;
}

pub struct RealCommandRunner;
impl CommandRunner for RealCommandRunner {
    fn run(&self, cmd: &str, args: &[&str]) -> Result<bool, String> {
        let status = Command::new(cmd)
            .args(args)
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
            .map_err(|e| format!("Falha ao invocar comando '{}': {}", cmd, e))?;
        Ok(status.success())
    }
    
    fn copy_config(&self, src: &Path) -> Result<(), String> {
        let dest_dir = Path::new("/mnt/etc/kryonixos");
        if !dest_dir.exists() {
            fs::create_dir_all(dest_dir).map_err(|e| format!("Falha ao criar diretório /mnt/etc/kryonixos: {}", e))?;
        }
        let dest_file = dest_dir.join("generated-install-config.nix");
        fs::copy(src, &dest_file)
            .map_err(|e| format!("Falha ao injetar configuração Nix em {}: {}", dest_file.display(), e))?;
        Ok(())
    }
}

pub fn run_deploy(config_path: Option<&str>) -> Result<(), String> {
    run_deploy_inner(config_path, &RealCommandRunner)
}

fn run_deploy_inner(config_path: Option<&str>, runner: &dyn CommandRunner) -> Result<(), String> {
    println!("{} Iniciando pipeline de Deploy (Orquestração Rust)...", "[INFO]".cyan());

    let path_str = config_path.ok_or_else(|| "Caminho da configuração não fornecido.".to_string())?;
    let path = Path::new(path_str);

    if !path.exists() {
        return Err(format!("Arquivo de configuração não encontrado: {}", path_str));
    }

    println!("{} Acionando o disko para particionamento...", "[INFO]".cyan());
    
    // 1. Particionamento Disko
    let disko_success = runner.run("sudo", &["nix", "run", "github:nix-community/disko", "--", "--mode", "disko", "--flake", ".#installer"])?;
    
    // Blindagem de Erro: Interromper imediatamente
    if !disko_success {
        return Err("Disko falhou. O particionamento não foi concluído. Abortando deploy.".to_string());
    }

    // Preparação do destino determinístico em /mnt/etc/kryonixos/
    println!("{} Copiando configuração gerada para /mnt...", "[INFO]".cyan());
    runner.copy_config(path)?;

    println!("{} Instalando o NixOS no alvo...", "[INFO]".cyan());
    
    // 2. Instalação do Sistema
    let install_success = runner.run("sudo", &["nixos-install", "--target-directory", "/mnt", "--flake", ".#srv-rag", "--no-root-passwd"])?;

    if install_success {
        println!("{} Deploy concluído com sucesso!", "[PASS]".green());
        Ok(())
    } else {
        Err("nixos-install falhou.".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::io::Write;
    use tempfile::NamedTempFile;

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
            self.commands_run.borrow_mut().push("COPY_CONFIG".to_string());
            Ok(())
        }
    }

    #[test]
    fn test_deploy_fails_if_disko_fails() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "mock").unwrap();
        let path = temp_file.path().to_str().unwrap();

        let runner = MockRunner {
            disko_result: Ok(false), // Simula falha do disko
            install_result: Ok(true),
            commands_run: RefCell::new(vec![]),
        };

        let result = run_deploy_inner(Some(path), &runner);
        
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Disko falhou. O particionamento não foi concluído. Abortando deploy.");
        
        let cmds = runner.commands_run.borrow();
        // A cópia pro FS e o nixos-install não devem rodar.
        assert!(!cmds.contains(&"COPY_CONFIG".to_string()));
        assert!(!cmds.iter().any(|c| c.contains("nixos-install")));
    }

    #[test]
    fn test_deploy_success() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "mock").unwrap();
        let path = temp_file.path().to_str().unwrap();

        let runner = MockRunner {
            disko_result: Ok(true),
            install_result: Ok(true),
            commands_run: RefCell::new(vec![]),
        };

        let result = run_deploy_inner(Some(path), &runner);
        
        assert!(result.is_ok());
        
        let cmds = runner.commands_run.borrow();
        assert!(cmds.iter().any(|c| c.contains("disko")));
        assert!(cmds.contains(&"COPY_CONFIG".to_string()));
        assert!(cmds.iter().any(|c| c.contains("nixos-install")));
    }
}
