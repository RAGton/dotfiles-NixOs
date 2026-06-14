use std::sync::Arc;
use tokio::sync::broadcast;

use super::progress::ProgressEvent;
use crate::InstallPlan;

pub async fn run_disko(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    let config = generate_disko_config(plan);
    let config_path = "/tmp/kryonix-disko-config.nix";

    tokio::fs::write(config_path, config)
        .await
        .map_err(|e| format!("Falha ao escrever config disko: {e}"))?;

    let _ = tx.send(ProgressEvent {
        step: "partition".into(),
        message: format!("Particionando {}...", plan.disk.target),
        percent: 10,
    });

    let result = tokio::process::Command::new("disko")
        .args(["--mode", "disko", config_path])
        .output()
        .await
        .map_err(|e| format!("disko não encontrado: {e}"))?;

    if !result.status.success() {
        return Err(format!(
            "disko falhou: {}",
            String::from_utf8_lossy(&result.stderr)
        ));
    }

    let _ = tx.send(ProgressEvent {
        step: "partition".into(),
        message: "Particionamento concluído".into(),
        percent: 30,
    });

    Ok(())
}

fn generate_disko_config(plan: &InstallPlan) -> String {
    if plan.disk.profile == "manual" {
        return generate_disko_config_manual(plan);
    }

    match plan.disk.layout.as_str() {
        "lvm-simple" => generate_lvm_simple(&plan.disk.target, &plan.disk.boot_mode),
        _ => generate_btrfs_simple(&plan.disk.target, &plan.disk.boot_mode),
    }
}

fn generate_disko_config_manual(plan: &InstallPlan) -> String {
    use std::collections::HashMap;
    let parts = plan
        .disk
        .manual_partitions
        .as_ref()
        .cloned()
        .unwrap_or_default();

    let mut disks: HashMap<String, Vec<crate::PartitionSpec>> = HashMap::new();
    for p in parts {
        disks.entry(p.device.clone()).or_default().push(p);
    }

    let mut disk_configs = Vec::new();
    for (device, p_list) in disks {
        let name = device
            .split('/')
            .next_back()
            .unwrap_or("disk")
            .replace('.', "_");
        let mut part_configs = Vec::new();

        for (idx, p) in p_list.iter().enumerate() {
            let part_name = format!("p{}", idx + 1);
            let content = if p.format {
                format!(
                    r#"content = {{ type = "filesystem"; format = "{}"; mountpoint = "{}"; }};"#,
                    p.fstype, p.mountpoint
                )
            } else {
                format!(
                    r#"content = {{ type = "filesystem"; mountpoint = "{}"; }};"#,
                    p.mountpoint
                )
            };

            part_configs.push(format!(
                r#"          {} = {{
            size = "{}";
            {}
          }};"#,
                part_name, p.size, content
            ));
        }

        disk_configs.push(format!(
            r#"    {} = {{
      type = "disk";
      device = "{}";
      content = {{
        type = "gpt";
        partitions = {{
{}
        }};
      }};
    }};"#,
            name,
            device,
            part_configs.join("\n")
        ));
    }

    format!(
        r#"{{
  disko.devices.disk = {{
{}
  }};
}}
"#,
        disk_configs.join("\n")
    )
}

fn generate_btrfs_simple(target: &str, boot_mode: &str) -> String {
    let efi_part = if boot_mode == "uefi" {
        r#"
        esp = {
          size = "512M";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
        };"#
    } else {
        ""
    };

    format!(
        r#"{{
  disko.devices.disk.main = {{
    type = "disk";
    device = "{target}";
    content = {{
      type = "gpt";
      partitions = {{{efi_part}
        root = {{
          size = "100%";
          content = {{
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {{
              "@"          = {{ mountpoint = "/"; }};
              "@home"      = {{ mountpoint = "/home"; }};
              "@nix"       = {{ mountpoint = "/nix"; mountOptions = [ "noatime" ]; }};
              "@var"       = {{ mountpoint = "/var"; }};
              "@snapshots" = {{ mountpoint = "/.snapshots"; }};
            }};
          }};
        }};
      }};
    }};
  }};
}}
"#
    )
}

fn generate_lvm_simple(target: &str, boot_mode: &str) -> String {
    let efi_part = if boot_mode == "uefi" {
        r#"
        esp = {
          size = "512M";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
        };"#
    } else {
        ""
    };

    format!(
        r#"{{
  disko.devices.disk.main = {{
    type = "disk";
    device = "{target}";
    content = {{
      type = "gpt";
      partitions = {{{efi_part}
        root = {{
          size = "100%";
          content = {{
            type = "lvm_pv";
            vg = "vg0";
          }};
        }};
      }};
    }};
  }};
  disko.devices.lvm_vg.vg0 = {{
    type = "lvm_vg";
    lvs = {{
      root = {{
        size = "80%FREE";
        content = {{
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        }};
      }};
      home = {{
        size = "100%FREE";
        content = {{
          type = "filesystem";
          format = "ext4";
          mountpoint = "/home";
        }};
      }};
    }};
  }};
}}
"#
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_btrfs_config_contains_target() {
        let cfg = generate_btrfs_simple("/dev/vdb", "uefi");
        assert!(cfg.contains("/dev/vdb"));
        assert!(cfg.contains("EF00"));
        assert!(cfg.contains("@home"));
    }

    #[test]
    fn test_lvm_config_bios_no_efi() {
        let cfg = generate_lvm_simple("/dev/sdb", "bios");
        assert!(!cfg.contains("EF00"));
        assert!(cfg.contains("lvm_pv"));
        assert!(cfg.contains("vg0"));
    }

    #[test]
    fn test_btrfs_bios_no_efi_partition() {
        let cfg = generate_btrfs_simple("/dev/vdb", "bios");
        assert!(!cfg.contains("EF00"));
    }
}
