pub mod kryonixos;
pub mod nixos;
pub mod partition;
pub mod progress;
pub mod safety;
pub mod target_tree;
pub mod verify;

pub use progress::ProgressEvent;
pub use safety::{SafetyCheck, run_safety_checks};
pub use target_tree::{run_preflight, run_preflight_install_gate};

use std::sync::Arc;
use tokio::sync::broadcast;

use crate::InstallPlan;

pub async fn run_installation(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    partition::run_disko(plan, tx.clone()).await?;
    kryonixos::generate_kryonixos_tree(plan, tx.clone()).await?;

    // Target Flake v2: rejeita instalação se o target ainda referenciar
    // `/nix/store/kryonix`, `path:/nix/store`, `self.outPath` ou se algum
    // dos arquivos generated estiver ausente.
    //
    // Usamos a variante LEVE (sem `nix flake metadata`): chamar `nix flake
    // metadata` aqui mexe em `lastModified` e gravava `flake.lock`, o que
    // fazia o `nixos-install` falhar com `NAR hash mismatch` logo depois.
    // `/debug/target` continua chamando o preflight completo.
    let _ = tx.send(ProgressEvent {
        step: "preflight".into(),
        message: "Validando target flake (arquivos + bad refs)...".into(),
        percent: 45,
    });
    let report = target_tree::run_preflight_install_gate().await?;
    if !report.passed() {
        return Err(format!(
            "Preflight do target falhou: bad_refs={:?} target_flake_exists={} engine_flake_exists={} features_generated_exists={} hardware_generated_exists={}",
            report.bad_references,
            report.target_flake_exists,
            report.engine_flake_exists,
            report.features_generated_exists,
            report.hardware_generated_exists,
        ));
    }

    // NÃO removemos /mnt/etc/kryonixos/flake.lock aqui: ele foi gerado
    // explicitamente em target_tree::pre_lock_target() para imobilizar o
    // tree antes do nixos-install. Sem este lock pré-existente, nixos-install
    // escreveria um durante a avaliação e provocaria "NAR hash mismatch".
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
