pub mod kryonixos;
pub mod nixos;
pub mod partition;
pub mod progress;
pub mod safety;
pub mod verify;

pub use progress::ProgressEvent;
pub use safety::{SafetyCheck, run_safety_checks};

use std::sync::Arc;
use tokio::sync::broadcast;

use crate::InstallPlan;

pub async fn run_installation(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    partition::run_disko(plan, tx.clone()).await?;
    kryonixos::generate_kryonixos_tree(plan, tx.clone()).await?;
    nixos::run_nixos_install(plan, tx.clone()).await?;

    // Prova estrutural antes de declarar sucesso: GPT + root populado +
    // bootloader. Sem isto, um disco intocado seria reportado como PASS.
    let _ = tx.send(ProgressEvent {
        step: "verify".into(),
        message: "Verificando estrutura do disco (GPT/ESP/root)...".into(),
        percent: 95,
    });
    verify::verify_disk_install(plan).await?;

    // Só agora marcamos a instalação como concluída (caminho vivo).
    verify::write_install_flag().await?;

    let _ = tx.send(ProgressEvent {
        step: "done".into(),
        message: "Disco verificado: GPT, root e bootloader presentes.".into(),
        percent: 100,
    });

    Ok(())
}
