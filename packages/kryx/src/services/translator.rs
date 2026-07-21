use crate::domain::config::{InstallPlanV2, Topology};

/// Gera a configuração Nix declarativa baseada no plano de instalação.
pub fn generate_nix_config(plan: &InstallPlanV2) -> Result<String, String> {
    let mut config = String::new();

    // 1. Cabecalho
    config.push_str("{ config, lib, ... }:\n");
    config.push_str("{\n");

    // 2. Think Server
    if plan.is_think_server {
        config.push_str("  kryonix.thinkServer.enable = true;\n");
    }

    // 3. Storage Topology
    let topology_str = match plan.storage.topology {
        Topology::Single => "single",
        Topology::Split => "split",
        Topology::Raid => "raid",
        Topology::Manual => "manual",
    };
    config.push_str(&format!(
        "  kryonix.storage.topology = \"{}\";\n",
        topology_str
    ));

    // System Disks
    if !plan.storage.system_disks.is_empty() {
        let disks = plan
            .storage
            .system_disks
            .iter()
            .map(|d| format!("\"{}\"", d))
            .collect::<Vec<_>>()
            .join(" ");
        config.push_str(&format!("  kryonix.storage.systemDisks = [ {} ];\n", disks));
    }

    // Data Disks
    if !plan.storage.data_disks.is_empty() {
        let disks = plan
            .storage
            .data_disks
            .iter()
            .map(|d| format!("\"{}\"", d))
            .collect::<Vec<_>>()
            .join(" ");
        config.push_str(&format!("  kryonix.storage.dataDisks = [ {} ];\n", disks));
    }

    // Filesystems
    if let Some(root) = &plan.storage.root {
        let fs_str = format!("{:?}", root.filesystem).to_lowercase();
        config.push_str(&format!(
            "  kryonix.storage.root.filesystem = \"{}\";\n",
            fs_str
        ));
    }

    if let Some(data) = &plan.storage.data {
        let fs_str = format!("{:?}", data.filesystem).to_lowercase();
        config.push_str(&format!(
            "  kryonix.storage.data.filesystem = \"{}\";\n",
            fs_str
        ));
    }

    // Quotas (ZFS / BTRFS)
    if let Some(zfs) = &plan.storage.zfs {
        config.push_str(&format!(
            "  kryonix.storage.zfs.userRefquota = \"{}\";\n",
            zfs.user_refquota
        ));
    }

    if let Some(btrfs) = &plan.storage.btrfs {
        config.push_str(&format!(
            "  kryonix.storage.btrfs.userQgroupLimit = \"{}\";\n",
            btrfs.user_qgroup_limit
        ));
    }

    // 4. Features
    for (category, feature_map) in &plan.features {
        for (feature, enabled) in feature_map {
            if *enabled {
                config.push_str(&format!(
                    "  kryonix.features.{}.{} = true;\n",
                    category, feature
                ));
            }
        }
    }

    // Fim do módulo
    config.push_str("}\n");

    Ok(config)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::config::{
        BtrfsStoragePlan, Encryption, FileSystem, MountPlan, RepositoryPlan, StoragePlan,
        ZfsStoragePlan,
    };
    use std::collections::BTreeMap;

    #[test]
    fn test_think_server_translation() {
        let mut features = BTreeMap::new();
        let mut server_features = BTreeMap::new();
        server_features.insert("containers".to_string(), true);
        features.insert("server".to_string(), server_features);

        let plan = InstallPlanV2 {
            version: 2,
            is_think_server: true,
            repository: RepositoryPlan {
                core_url: "url".to_string(),
                upstream_url: "url".to_string(),
                downstream_url: "url".to_string(),
                branch: "main".to_string(),
            },
            storage: StoragePlan {
                topology: Topology::Split,
                system_disks: vec!["/dev/sda".to_string()],
                data_disks: vec!["/dev/sdb".to_string()],
                root: Some(MountPlan {
                    filesystem: FileSystem::Ext4,
                    encryption: Encryption::None,
                }),
                data: Some(MountPlan {
                    filesystem: FileSystem::Zfs,
                    encryption: Encryption::Luks2,
                }),
                raid_level: None,
                manual_partitions: vec![],
                zfs: Some(ZfsStoragePlan {
                    user_refquota: "100G".to_string(),
                }),
                btrfs: None,
            },
            features,
        };

        let result = generate_nix_config(&plan).unwrap();

        assert!(result.contains("kryonix.thinkServer.enable = true;"));
        assert!(result.contains("kryonix.storage.topology = \"split\";"));
        assert!(result.contains("kryonix.storage.systemDisks = [ \"/dev/sda\" ];"));
        assert!(result.contains("kryonix.storage.dataDisks = [ \"/dev/sdb\" ];"));
        assert!(result.contains("kryonix.storage.root.filesystem = \"ext4\";"));
        assert!(result.contains("kryonix.storage.data.filesystem = \"zfs\";"));
        assert!(result.contains("kryonix.storage.zfs.userRefquota = \"100G\";"));
        assert!(result.contains("kryonix.features.server.containers = true;"));
    }
}
