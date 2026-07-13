use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "kryx", version = "0.1.0", author, about = "Kryonix Unified CLI", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Operação atômica de reconstrução e transição do sistema
    Switch,
    /// Gerencia deploy de imagens diskless (RAGOS)
    Deploy,
    /// Gestão de estado do sistema e telemetria
    System,
    /// Diagnóstico do ambiente e configurações
    Doctor,
    /// Gerenciamento de temas
    Theme,
}
