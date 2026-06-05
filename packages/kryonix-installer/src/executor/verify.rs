//! Verificação estrutural pós-instalação.
//!
//! Garante que `nixos-install` realmente produziu um sistema bootável antes de
//! declarar sucesso. Sem esta prova de disco, um QCOW2 vazio (disko nunca
//! executou) poderia ser reportado como PASS — o falso positivo que este
//! módulo elimina.

use std::path::Path;
use tokio::process::Command;

use crate::InstallPlan;

/// Alvos de disco que devem conter tabela de partição GPT após o disko.
fn partition_targets(plan: &InstallPlan) -> Vec<String> {
    match plan.disk.profile.as_str() {
        "raid" => plan.disk.selected_disks.clone(),
        "manual" => {
            let mut targets = vec![plan.disk.target.clone()];
            if let Some(parts) = &plan.disk.manual_partitions {
                targets.extend(parts.iter().map(|p| p.device.clone()));
            }
            targets.sort();
            targets.dedup();
            targets.retain(|t| !t.trim().is_empty());
            targets
        }
        _ => vec![plan.disk.target.clone()],
    }
}

/// Lê o tipo de tabela de partição de um device via `lsblk -no PTTYPE`.
async fn partition_table_type(device: &str) -> Result<String, String> {
    let out = Command::new("lsblk")
        .args(["-ndo", "PTTYPE", device])
        .output()
        .await
        .map_err(|e| format!("lsblk não encontrado: {e}"))?;

    if !out.status.success() {
        return Err(format!(
            "lsblk falhou em {device}: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }

    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

/// `/mnt/nix/store` precisa existir e conter ao menos uma entrada — prova de
/// que o root foi formatado, montado e populado pelo nixos-install.
async fn nix_store_populated() -> bool {
    match tokio::fs::read_dir("/mnt/nix/store").await {
        Ok(mut entries) => matches!(entries.next_entry().await, Ok(Some(_))),
        Err(_) => false,
    }
}

/// Verificação estrutural completa. Retorna `Ok(())` somente com prova de:
/// GPT em todos os alvos, root montado e populado, e bootloader presente
/// (ESP para UEFI, grub para BIOS).
pub async fn verify_disk_install(plan: &InstallPlan) -> Result<(), String> {
    let mut failures = Vec::new();

    // 1. Tabela GPT em todos os alvos.
    for target in partition_targets(plan) {
        match partition_table_type(&target).await {
            Ok(pt) if pt.eq_ignore_ascii_case("gpt") => {}
            Ok(pt) if pt.is_empty() => {
                failures.push(format!(
                    "{target}: sem tabela de partição (disko não particionou)"
                ));
            }
            Ok(pt) => failures.push(format!("{target}: tabela '{pt}', esperado 'gpt'")),
            Err(e) => failures.push(e),
        }
    }

    // 2. Root montado e populado.
    if !Path::new("/mnt").exists() {
        failures.push("/mnt não existe (root não montado)".into());
    } else if !nix_store_populated().await {
        failures.push("/mnt/nix/store vazio ou ausente (root não populado)".into());
    }

    // 3. Bootloader.
    let uefi = plan.disk.boot_mode == "uefi";
    let efi_ok = Path::new("/mnt/boot/EFI").exists() || Path::new("/mnt/boot/efi").exists();
    let grub_ok = Path::new("/mnt/boot/grub").exists();

    if uefi && !efi_ok {
        failures.push("/mnt/boot/EFI ausente (ESP/bootloader UEFI não instalado)".into());
    }
    if !uefi && !grub_ok {
        failures.push("/mnt/boot/grub ausente (bootloader BIOS não instalado)".into());
    }

    if failures.is_empty() {
        Ok(())
    } else {
        Err(format!(
            "Verificação estrutural do disco FALHOU — instalação não persistiu: {}",
            failures.join("; ")
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{PlanDisk, PlanUser};

    fn plan_with(profile: &str, target: &str, selected: Vec<&str>) -> InstallPlan {
        InstallPlan {
            version: 1,
            hostname: "iso".into(),
            timezone: "America/Cuiaba".into(),
            locale: "pt_BR.UTF-8".into(),
            keyboard: "br-abnt2".into(),
            disk: PlanDisk {
                mode: "install".into(),
                target: target.into(),
                layout: "btrfs-simple".into(),
                boot_mode: "uefi".into(),
                profile: profile.into(),
                selected_disks: selected.into_iter().map(String::from).collect(),
                raid_level: None,
                manual_partitions: None,
            },
            user: PlanUser {
                name: "admin".into(),
                admin: true,
            },
            features: serde_json::json!({}),
        }
    }

    #[test]
    fn single_profile_targets_only_main_disk() {
        let p = plan_with("single", "/dev/vda", vec![]);
        assert_eq!(partition_targets(&p), vec!["/dev/vda".to_string()]);
    }

    #[test]
    fn raid_profile_targets_all_selected_disks() {
        let p = plan_with("raid", "/dev/vda", vec!["/dev/vda", "/dev/vdb"]);
        assert_eq!(
            partition_targets(&p),
            vec!["/dev/vda".to_string(), "/dev/vdb".to_string()]
        );
    }
}

/// Cria a flag de instalação no caminho vivo, somente após a verificação passar.
/// Antes, esta flag só existia em `install.rs` (código morto), tornando o gate
/// `/api/validate-install` inalcançável.
pub async fn write_install_flag() -> Result<(), String> {
    tokio::fs::create_dir_all("/mnt/etc")
        .await
        .map_err(|e| format!("Falha ao criar /mnt/etc: {e}"))?;
    tokio::fs::write("/mnt/etc/kryonix-installed", "ok\n")
        .await
        .map_err(|e| format!("Falha ao criar flag /mnt/etc/kryonix-installed: {e}"))
}
