pub mod nixos;
pub mod partition;
pub mod progress;
pub mod safety;

pub use progress::ProgressEvent;
pub use safety::{run_safety_checks, SafetyCheck};

use std::sync::Arc;
use tokio::sync::broadcast;

use crate::InstallPlan;

pub async fn run_installation(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    partition::run_disko(plan, tx.clone()).await?;
    nixos::run_nixos_install(plan, tx).await
}
