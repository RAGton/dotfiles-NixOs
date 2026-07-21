use std::path::Path;
use std::process::{Command, Stdio};

pub fn run_legacy_fallback(script_name: &str, args: &[String]) -> Result<(), String> {
    let script_path = Path::new("./scripts").join(script_name);
    if script_path.exists() {
        println!("[LEGACY MODE] Executando script legado: {}...", script_name);
        Command::new(&script_path)
            .args(args)
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
            .map_err(|e| e.to_string())?;
        Ok(())
    } else {
        Err(format!(
            "Comando não implementado em Rust nem encontrado como script legado: {}",
            script_name
        ))
    }
}
