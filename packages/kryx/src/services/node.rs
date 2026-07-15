use colored::Colorize;
use std::process::{Command, Stdio};

pub enum NodeAction {
    Publish { channel: Option<String> },
    Rollback,
    Status,
    Gc,
}

pub fn run_node_command(action: NodeAction) -> Result<(), String> {
    println!(
        "{} Modo de Transição: Delegando para o executor 'knyc'...",
        "[INFO]".cyan()
    );

    // Localizamos o script knyc provisoriamente
    // O caminho pode depender de onde o kryx é executado, mas para dev tentamos caminho relativo.
    // Em produção, `knyc` pode estar no PATH.
    let knyc_path = if std::path::Path::new("modules/node/core/knyc/knyc").exists() {
        "modules/node/core/knyc/knyc"
    } else if std::path::Path::new("../../modules/node/core/knyc/knyc").exists() {
        "../../modules/node/core/knyc/knyc"
    } else {
        "knyc"
    };

    let mut cmd = Command::new(knyc_path);

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
        .map_err(|e| format!("Falha ao executar script knyc: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("Comando de nodo (knyc) falhou.".to_string())
    }
}
