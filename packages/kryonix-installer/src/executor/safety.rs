use serde::Serialize;
use std::process::Command;

use crate::{InstallPlan, disk};

#[derive(Serialize, Clone, Debug)]
pub struct SafetyCheck {
    pub name: String,
    pub passed: bool,
    pub reason: String,
}

impl SafetyCheck {
    fn pass(name: impl Into<String>, reason: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            passed: true,
            reason: reason.into(),
        }
    }
    fn fail(name: impl Into<String>, reason: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            passed: false,
            reason: reason.into(),
        }
    }
}

pub fn run_safety_checks(plan: &InstallPlan) -> Vec<SafetyCheck> {
    let mut checks = vec![
        check_nixos_install_available(),
        check_disko_available(),
        check_network_for_nix(),
    ];

    if plan.disk.profile == "manual" {
        checks.push(check_manual_layout(plan));
        for target in manual_targets(plan) {
            checks.extend(check_installable_disk(&target));
        }
    } else if plan.disk.profile == "raid" {
        checks.push(check_raid_layout(plan));
        for target in &plan.disk.selected_disks {
            checks.extend(check_installable_disk(target));
        }
    } else {
        checks.extend(check_installable_disk(&plan.disk.target));
    }

    checks
}

fn manual_targets(plan: &InstallPlan) -> Vec<String> {
    let mut targets = vec![plan.disk.target.clone()];
    if let Some(parts) = &plan.disk.manual_partitions {
        targets.extend(parts.iter().map(|p| p.device.clone()));
    }
    targets.sort();
    targets.dedup();
    targets.retain(|target| !target.trim().is_empty());
    targets
}

fn check_installable_disk(target: &str) -> Vec<SafetyCheck> {
    vec![
        check_disk_is_block_device(target),
        check_disk_not_system(target),
        check_disk_not_mounted(target),
        check_disk_has_space(target),
    ]
}

fn check_manual_layout(plan: &InstallPlan) -> SafetyCheck {
    let name = "layout_manual_valido";
    let parts = plan
        .disk
        .manual_partitions
        .as_ref()
        .cloned()
        .unwrap_or_default();

    let has_root = parts.iter().any(|p| p.mountpoint == "/");
    let has_efi = parts
        .iter()
        .any(|p| p.mountpoint == "/boot/efi" || p.mountpoint == "/efi");

    if !has_root {
        return SafetyCheck::fail(name, "Modo manual exige partição raiz (/)");
    }
    if !has_efi {
        return SafetyCheck::fail(name, "Modo manual exige partição EFI (/boot/efi ou /efi)");
    }

    SafetyCheck::pass(name, "Layout manual contém partições obrigatórias")
}

fn check_raid_layout(plan: &InstallPlan) -> SafetyCheck {
    let name = "layout_raid_valido";
    let level = plan.disk.raid_level.as_deref().unwrap_or("raid1");
    let count = plan.disk.selected_disks.len();

    let min_required = match level {
        "raid0" | "raid1" => 2,
        "raid5" => 3,
        "raid10" => 4,
        _ => 2,
    };

    if count < min_required {
        return SafetyCheck::fail(
            name,
            format!(
                "{} exige {} discos (selecionados: {})",
                level.to_uppercase(),
                min_required,
                count
            ),
        );
    }

    SafetyCheck::pass(
        name,
        format!(
            "Configuração {} válida com {} discos",
            level.to_uppercase(),
            count
        ),
    )
}

fn check_disk_is_block_device(target: &str) -> SafetyCheck {
    let name = "disco_block_device_valido";
    match disk::inspect_disk(target) {
        Ok(info) => SafetyCheck::pass(
            name,
            format!(
                "{target} detectado como disco ({}, {})",
                info.name, info.size
            ),
        ),
        Err(e) => SafetyCheck::fail(name, e),
    }
}

// CRÍTICO — nunca remover. Impede particionar o disco onde o sistema está rodando.
fn check_disk_not_system(target: &str) -> SafetyCheck {
    let name = "disco_nao_e_sistema";
    match disk::is_system_disk(target) {
        Ok(true) => SafetyCheck::fail(
            name,
            format!("PERIGO: {target} é o disco onde o sistema está rodando!"),
        ),
        Ok(false) => SafetyCheck::pass(name, format!("{target} não é o disco do sistema")),
        Err(e) => SafetyCheck::fail(name, e),
    }
}

fn check_disk_not_mounted(target: &str) -> SafetyCheck {
    let name = "disco_nao_montado";
    match disk::disk_mount_conflicts(target) {
        Ok(conflicts) if conflicts.is_empty() => SafetyCheck::pass(
            name,
            format!("{target} não tem partições montadas (exceto /iso)"),
        ),
        Ok(conflicts) => SafetyCheck::fail(
            name,
            format!("{target} está montado em {}", conflicts.join(", ")),
        ),
        Err(e) => SafetyCheck::fail(name, e),
    }
}

fn check_disk_has_space(target: &str) -> SafetyCheck {
    let name = "disco_tem_espaco";
    match disk::disk_has_min_install_size(target) {
        Ok((true, size_bytes)) => {
            let size_gb = size_bytes / (1024 * 1024 * 1024);
            SafetyCheck::pass(
                name,
                format!("{target} tem {size_gb} GB (>= 10 GB requerido)"),
            )
        }
        Ok((false, size_bytes)) => {
            let size_gb = size_bytes / (1024 * 1024 * 1024);
            SafetyCheck::fail(
                name,
                format!("{target} tem apenas {size_gb} GB — mínimo 10 GB requerido"),
            )
        }
        Err(e) => SafetyCheck::fail(name, e),
    }
}

fn check_nixos_install_available() -> SafetyCheck {
    let name = "nixos_install_disponivel";
    match Command::new("which").arg("nixos-install").output() {
        Ok(o) if o.status.success() => SafetyCheck::pass(name, "nixos-install encontrado no PATH"),
        _ => SafetyCheck::fail(
            name,
            "nixos-install não encontrado — execute a partir da ISO Kryonix",
        ),
    }
}

fn check_disko_available() -> SafetyCheck {
    let name = "disko_disponivel";
    match Command::new("which").arg("disko").output() {
        Ok(o) if o.status.success() => SafetyCheck::pass(name, "disko encontrado no PATH"),
        _ => SafetyCheck::fail(
            name,
            "disko não encontrado — execute a partir da ISO Kryonix",
        ),
    }
}

fn check_network_for_nix() -> SafetyCheck {
    let name = "rede_disponivel";
    match Command::new("curl")
        .args(["-s", "--max-time", "5", "--head", "https://cache.nixos.org"])
        .output()
    {
        Ok(o) if o.status.success() => SafetyCheck::pass(name, "cache.nixos.org acessível"),
        Ok(o) => SafetyCheck::fail(
            name,
            format!(
                "Sem acesso ao cache.nixos.org (código {})",
                o.status.code().unwrap_or(-1)
            ),
        ),
        Err(e) => SafetyCheck::fail(name, format!("curl falhou: {e}")),
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_check_disk_block_device_rejects_null() {
        let check = check_disk_is_block_device("/dev/null");
        assert!(
            !check.passed,
            "/dev/null must not be accepted as an install disk"
        );
    }

    #[test]
    fn test_check_disk_has_space_null_fails() {
        // /dev/null reports 0 bytes — should fail the 10 GB check
        let check = check_disk_has_space("/dev/null");
        assert!(!check.passed, "/dev/null should fail space check");
    }

    #[test]
    fn test_safety_check_names_are_unique() {
        // Dummy plan — target /dev/null (never system disk, 0 bytes)
        use crate::{PlanDisk, PlanUser};
        let plan = crate::InstallPlan {
            version: 1,
            hostname: "test".into(),
            timezone: "UTC".into(),
            locale: "en_US.UTF-8".into(),
            keyboard: "us".into(),
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
                name: "admin".into(),
                admin: true,
            },
            features: serde_json::json!({}),
            network: Default::default(),
        };
        let checks = run_safety_checks(&plan);
        assert_eq!(checks.len(), 7);
        let names: std::collections::HashSet<_> = checks.iter().map(|c| &c.name).collect();
        assert_eq!(
            names.len(),
            7,
            "all check names must be unique for a single target"
        );
    }
}
