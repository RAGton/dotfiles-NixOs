use clap::{CommandFactory, FromArgMatches, Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(name = "kryx")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmds,
}

#[derive(Subcommand, Debug)]
enum Cmds {
    Deploy,
    Status,
    FactoryReset,
}

fn main() {
    let mut cmd = Cli::command();
    cmd = cmd.mut_subcommand("deploy", |c| c.hide(true));
    cmd = cmd.mut_subcommand("factory-reset", |c| c.hide(true));
    
    // Just print help
    cmd.print_help().unwrap();
}
