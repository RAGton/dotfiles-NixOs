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
    Deploy {
        /// Caminho para a configuração gerada do instalador
        config_path: Option<String>,
        /// Ignora a verificação do Environment Guard e força o deploy em sistemas instalados
        #[arg(long, short)]
        force: bool,
    },
    /// Reseta o sistema físico para as configurações originais
    FactoryReset {
        /// Preserva os dados do usuário em partições separadas (/home ou subvolumes persistentes)
        #[arg(long, default_value_t = true)]
        preserve_home: bool,
    },
    /// Gestão de estado do sistema e telemetria
    System,
    /// Diagnóstico do ambiente e configurações
    Doctor,
    /// Gerenciamento de temas
    Theme,
    /// Gerenciamento de Nodos (RAGOS Clientes)
    Node {
        #[command(subcommand)]
        command: NodeSubcommand,
    },
}

#[derive(Subcommand)]
pub enum NodeSubcommand {
    /// Publica uma nova geração de imagem para os nodos (RAGOS)
    Publish {
        #[arg(long)]
        channel: Option<String>,
    },
    /// Reverte os nodos para a geração anterior
    Rollback,
    /// Exibe o status atual dos nodos conectados
    Status,
    /// Limpa imagens e gerações antigas não utilizadas
    Gc,
}
