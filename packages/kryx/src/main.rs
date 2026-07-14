mod cli;
use kryx::services;


use clap::Parser;
use cli::{Cli, Commands};
use std::process::exit;

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Switch => {
            if let Err(e) = services::modules::run_switch() {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
        Commands::Deploy { config_path } => {
            if let Err(e) = services::deployment::run_deploy(config_path.as_deref()) {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
        Commands::Doctor => match services::diagnostics::run_doctor() {
            Ok(_) => {}
            Err(e) => {
                eprintln!("Erro: {}", e);
                exit(1);
            }
        },
        Commands::System => {
            if let Err(e) = services::fallback::run_legacy_fallback("kryonix-monitors.sh", &[]) {
                eprintln!("{}", e);
                exit(1);
            }
        }
        Commands::Theme => {
            if let Err(e) = services::theme::run_apply_theme() {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
    }
}
