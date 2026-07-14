use std::process::{Command, Stdio};
use colored::Colorize;

pub enum NodeAction {
    Publish { channel: Option<String> },
    Rollback,
    Status,
    Gc,
}

pub fn run_node_command(action: NodeAction) -> Result<(), String> {
    println!("{} Modo de Transição: Delegando para o executor 'ragc'...", "[INFO]".cyan());

    // Localizamos o script ragc provisoriamente
    // O caminho pode depender de onde o kryx é executado, mas para dev tentamos caminho relativo.
    // Em produção, `ragc` pode estar no PATH.
    let ragc_path = if std::path::Path::new("modules/ragos/core/ragc/ragc").exists() {
        "modules/ragos/core/ragc/ragc"
    } else if std::path::Path::new("../../modules/ragos/core/ragc/ragc").exists() {
        "../../modules/ragos/core/ragc/ragc"
    } else {
        "ragc"
    };

    let mut cmd = Command::new(ragc_path);

    match action {
        NodeAction::Publish { channel } => {
            cmd.arg("publish");
            if let Some(ch) = channel {
                cmd.arg("--channel").arg(ch);
            }
        }
        NodeAction::Rollback => {
            cmd.arg("rollback");
        }
        NodeAction::Status => {
            cmd.arg("status");
        }
        NodeAction::Gc => {
            cmd.arg("gc");
        }
    }

    let status = cmd
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(|e| format!("Falha ao executar script ragc: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Comando de nodo (ragc) falhou.".to_string())
    }
}
