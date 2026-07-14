mod cli;
use kryx::services;


use clap::Parser;
use cli::{Cli, Commands};
use std::process::exit;

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Switch => {
            if let Err(e) = services::modules::run_switch() {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
        Commands::Deploy { config_path, force } => {
            // Environment Guard
            if !force && !services::env::check_is_live_iso() {
                eprintln!("ERRO: O comando 'deploy' é exclusivo para Live ISOs. Use 'kryx factory-reset' para restaurar o sistema instalado.");
                exit(1);
            }

            if let Err(e) = services::deployment::run_deploy(config_path.as_deref()) {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
        Commands::FactoryReset { preserve_home } => {
            if let Err(e) = services::deployment::run_factory_reset(preserve_home) {
                eprintln!("Erro Crítico no Reset: {}", e);
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
        Commands::Node { command } => {
            let action = match command {
                cli::NodeSubcommand::Publish { channel } => services::node::NodeAction::Publish { channel },
                cli::NodeSubcommand::Rollback => services::node::NodeAction::Rollback,
                cli::NodeSubcommand::Status => services::node::NodeAction::Status,
                cli::NodeSubcommand::Gc => services::node::NodeAction::Gc,
            };
            if let Err(e) = services::node::run_node_command(action) {
                eprintln!("Erro Crítico: {}", e);
                exit(1);
            }
        }
    }
}
