use serde::Serialize;
use std::process::Command;

use crate::InstallPlan;

#[derive(Serialize, Clone, Debug)]
pub struct SafetyCheck {
    pub name: String,
    pub passed: bool,
    pub reason: String,
}

impl SafetyCheck {
    fn pass(name: impl Into<String>, reason: impl Into<String>) -> Self {
        Self { name: name.into(), passed: true, reason: reason.into() }
    }
    fn fail(name: impl Into<String>, reason: impl Into<String>) -> Self {
        Self { name: name.into(), passed: false, reason: reason.into() }
    }
}

pub fn run_safety_checks(plan: &InstallPlan) -> Vec<SafetyCheck> {
    vec![
        check_disk_not_system(&plan.disk.target),
        check_disk_not_mounted(&plan.disk.target),
        check_disk_has_space(&plan.disk.target),
        check_nixos_install_available(),
        check_disko_available(),
        check_network_for_nix(),
    ]
}

// CRÍTICO — nunca remover. Impede particionar o disco onde o sistema está rodando.
fn check_disk_not_system(target: &str) -> SafetyCheck {
    let name = "disco_nao_e_sistema";

    let output = match Command::new("findmnt")
        .args(["--target", "/", "--output", "SOURCE", "--noheadings"])
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            return SafetyCheck::fail(
                name,
                format!("Não foi possível executar findmnt: {e}"),
            );
        }
    };

    if !output.status.success() {
        return SafetyCheck::fail(
            name,
            format!(
                "findmnt falhou: {}",
                String::from_utf8_lossy(&output.stderr)
            ),
        );
    }

    let source = String::from_utf8_lossy(&output.stdout);
    // target = "/dev/sda" → base = "sda"; root source = "/dev/sda2" → contains "sda"
    // target = "/dev/nvme0n1" → base = "nvme0n1"; root source = "/dev/nvme0n1p2" → contains "nvme0n1"
    let target_base = target.trim_start_matches("/dev/");

    let is_system = source.lines().any(|line| {
        let line = line.trim().trim_start_matches("/dev/");
        // Exact match (partition IS target) or partition starts with target base
        line == target_base || line.starts_with(target_base)
    });

    if is_system {
        SafetyCheck::fail(
            name,
            format!("PERIGO: {target} é o disco onde o sistema está rodando!"),
        )
    } else {
        SafetyCheck::pass(name, format!("{target} não é o disco do sistema"))
    }
}

fn check_disk_not_mounted(target: &str) -> SafetyCheck {
    let name = "disco_nao_montado";
    let target_base = target.trim_start_matches("/dev/");

    let output = match Command::new("findmnt")
        .args(["--output", "SOURCE,TARGET", "--noheadings"])
        .output()
    {
        Ok(o) => o,
        Err(e) => return SafetyCheck::fail(name, format!("findmnt falhou: {e}")),
    };

    let text = String::from_utf8_lossy(&output.stdout);

    for line in text.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }
        let source = parts[0].trim_start_matches("/dev/");
        let mountpoint = parts[1];

        // Check if this source is a partition of our target disk
        if source == target_base || source.starts_with(target_base) {
            // /iso is the live media — that's expected and acceptable
            if mountpoint == "/iso" || mountpoint.starts_with("/iso/") {
                continue;
            }
            return SafetyCheck::fail(
                name,
                format!("{target} está montado em {mountpoint} — desmonte antes de instalar"),
            );
        }
    }

    SafetyCheck::pass(name, format!("{target} não tem partições montadas (exceto /iso)"))
}

fn check_disk_has_space(target: &str) -> SafetyCheck {
    let name = "disco_tem_espaco";
    const MIN_BYTES: u64 = 10 * 1024 * 1024 * 1024; // 10 GB

    let output = match Command::new("lsblk")
        .args(["-b", "-d", "-o", "SIZE", "--noheadings", target])
        .output()
    {
        Ok(o) => o,
        Err(e) => return SafetyCheck::fail(name, format!("lsblk falhou: {e}")),
    };

    if !output.status.success() {
        return SafetyCheck::fail(
            name,
            format!("lsblk error: {}", String::from_utf8_lossy(&output.stderr)),
        );
    }

    let size_str = String::from_utf8_lossy(&output.stdout);
    let size_bytes: u64 = match size_str.trim().parse() {
        Ok(n) => n,
        Err(_) => {
            return SafetyCheck::fail(
                name,
                format!("Não foi possível ler o tamanho de {target}"),
            )
        }
    };

    let size_gb = size_bytes / (1024 * 1024 * 1024);
    if size_bytes >= MIN_BYTES {
        SafetyCheck::pass(name, format!("{target} tem {size_gb} GB (≥ 10 GB requerido)"))
    } else {
        SafetyCheck::fail(
            name,
            format!("{target} tem apenas {size_gb} GB — mínimo 10 GB requerido"),
        )
    }
}

fn check_nixos_install_available() -> SafetyCheck {
    let name = "nixos_install_disponivel";
    match Command::new("which").arg("nixos-install").output() {
        Ok(o) if o.status.success() => {
            SafetyCheck::pass(name, "nixos-install encontrado no PATH")
        }
        _ => SafetyCheck::fail(name, "nixos-install não encontrado — execute a partir da ISO Kryonix"),
    }
}

fn check_disko_available() -> SafetyCheck {
    let name = "disko_disponivel";
    match Command::new("which").arg("disko").output() {
        Ok(o) if o.status.success() => SafetyCheck::pass(name, "disko encontrado no PATH"),
        _ => SafetyCheck::fail(name, "disko não encontrado — execute a partir da ISO Kryonix"),
    }
}

fn check_network_for_nix() -> SafetyCheck {
    let name = "rede_disponivel";
    match Command::new("curl")
        .args(["-s", "--max-time", "5", "--head", "https://cache.nixos.org"])
        .output()
    {
        Ok(o) if o.status.success() => {
            SafetyCheck::pass(name, "cache.nixos.org acessível")
        }
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
    fn test_check_disk_not_system_null_is_not_system() {
        // Skip if findmnt is not available (e.g., Nix build sandbox)
        if std::process::Command::new("findmnt").arg("--help").output().is_err() {
            return;
        }
        // /dev/null is never the root disk
        let check = check_disk_not_system("/dev/null");
        assert!(check.passed, "expected /dev/null to not be system disk: {}", check.reason);
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
            },
            user: PlanUser { name: "admin".into(), admin: true },
            features: serde_json::json!({}),
        };
        let checks = run_safety_checks(&plan);
        assert_eq!(checks.len(), 6);
        let names: std::collections::HashSet<_> = checks.iter().map(|c| &c.name).collect();
        assert_eq!(names.len(), 6, "all check names must be unique");
    }
}
