mod cli;
mod domain;
mod services;

use clap::Parser;
use cli::{Cli, Commands};
use std::process::exit;

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Switch => {
            if let Err(_) = services::modules::run_switch() {
                if let Err(e) = services::fallback::run_legacy_fallback("kryonix-switch", &[]) {
                    eprintln!("{}", e);
                    exit(1);
                }
            }
        }
        Commands::Deploy => {
            if let Err(_) = services::deployment::run_deploy() {
                if let Err(e) = services::fallback::run_legacy_fallback("ragos-install", &[]) {
                    eprintln!("{}", e);
                    exit(1);
                }
            }
        }
        Commands::Doctor => match services::diagnostics::run_doctor() {
            Ok(_) => {}
            Err(e) if e == "not_implemented" => {
                if let Err(err) = services::fallback::run_legacy_fallback("glacier-doctor.sh", &[])
                {
                    eprintln!("{}", err);
                    exit(1);
                }
            }
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
            println!("Gerenciamento de tema (stub)");
        }
    }
}
