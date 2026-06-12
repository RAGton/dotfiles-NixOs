//! Compat shim: delega para [`super::target_tree`] (layout v2).
//!
//! O orquestrador (`super::mod`) ainda chama `generate_kryonixos_tree`, mas
//! toda a lógica vive agora em `target_tree.rs`. O nome antigo é preservado
//! para manter outros call sites estáveis enquanto a migração não termina.

use std::sync::Arc;
use tokio::sync::broadcast;

use super::progress::ProgressEvent;
use super::target_tree;
use crate::InstallPlan;

pub async fn generate_kryonixos_tree(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    target_tree::generate_target_tree(plan, tx).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{InstallPlan, PlanDisk, PlanUser};

    fn make_test_plan() -> InstallPlan {
        InstallPlan {
            version: 1,
            hostname: "test-host".into(),
            timezone: "America/Sao_Paulo".into(),
            locale: "pt_BR.UTF-8".into(),
            keyboard: "br-abnt2".into(),
            disk: PlanDisk {
                mode: "install".into(),
                target: "/dev/null".into(),
                layout: "btrfs-simple".into(),
                boot_mode: "uefi".into(),
                profile: "single".into(),
                selected_disks: vec![],
                raid_level: None,
                manual_partitions: None,
            },
            user: PlanUser {
                name: "test-user".into(),
                admin: true,
            },
            features: serde_json::json!({}),
            network: Default::default(),
        }
    }

    #[tokio::test]
    async fn missing_engine_source_fails_before_nixos_install() {
        unsafe {
            std::env::set_var("KRYONIX_ENGINE_SOURCE", "/path/that/does/not/exist/surely");
        }
        let (tx, _) = broadcast::channel(10);
        let plan = make_test_plan();
        let res = generate_kryonixos_tree(&plan, Arc::new(tx)).await;
        assert!(res.is_err());
        let err = res.unwrap_err();
        assert!(
            err.contains("KRYONIX_ENGINE_SOURCE não encontrado")
                || err.contains("KRYONIX_ENGINE_SOURCE")
        );
    }
}
