use crate::disk;
use serde::Serialize;
use std::path::Path;
use std::process::Command;

#[derive(Serialize, Debug, Clone)]
pub struct InstallationMatch {
    pub device: String,
    pub hostname: String,
    pub version: Option<String>,
    pub is_kryonix: bool,
}

pub fn detect_existing_installations() -> Result<Vec<InstallationMatch>, String> {
    let disks = disk::list_disks()?;
    let mut matches = Vec::new();

    for disk in disks {
        // Obter todas as partições do disco
        let partitions_json = disk::get_partitions(&disk.name)?;

        // Extrair nomes de partições (ex: sda1, nvme0n1p2)
        if let Some(blockdevices) = partitions_json.get("blockdevices") {
            if let Some(children) = blockdevices.get(0).and_then(|d| d.get("children")) {
                if let Some(parts) = children.as_array() {
                    for part in parts {
                        if let Some(name) = part.get("name").and_then(|n| n.as_str()) {
                            if let Ok(Some(found)) = check_partition_for_kryonix(name) {
                                matches.push(found);
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(matches)
}

fn check_partition_for_kryonix(name: &str) -> Result<Option<InstallationMatch>, String> {
    let dev_path = format!("/dev/{}", name);
    let mount_point = format!("/run/kryonix/detect/{}", name);

    // Criar ponto de montagem
    std::fs::create_dir_all(&mount_point).map_err(|e| e.to_string())?;

    // Tentar montar (read-only)
    let mount_status = Command::new("mount")
        .args(["-o", "ro", &dev_path, &mount_point])
        .status();

    if let Ok(status) = mount_status {
        if status.success() {
            let result = (|| {
                let flake_lock = Path::new(&mount_point).join("etc/kryonixos/flake.lock");
                let installed_flag = Path::new(&mount_point).join("etc/kryonix-installed");
                let hostname_file = Path::new(&mount_point).join("etc/hostname");

                if flake_lock.exists() || installed_flag.exists() {
                    let hostname = std::fs::read_to_string(hostname_file)
                        .map(|s| s.trim().to_string())
                        .unwrap_or_else(|_| "unknown".to_string());

                    let version = std::fs::read_to_string(
                        Path::new(&mount_point).join("etc/kryonix-version"),
                    )
                    .ok()
                    .and_then(|s| {
                        s.lines()
                            .find(|l| l.starts_with("VERSION="))
                            .map(|l| l.replace("VERSION=", "").replace("\"", ""))
                    });

                    return Some(InstallationMatch {
                        device: dev_path.clone(),
                        hostname,
                        version,
                        is_kryonix: true,
                    });
                }
                None
            })();

            // Desmontar
            let _ = Command::new("umount").arg(&mount_point).status();
            return Ok(result);
        }
    }

    Ok(None)
}
