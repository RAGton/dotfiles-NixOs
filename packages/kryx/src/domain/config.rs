//! Contrato persistível do plano de instalação Kryonix v2.

use std::collections::BTreeMap;

use serde::{Deserialize, Deserializer, Serialize, de};

/// Topologia física solicitada para o armazenamento.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Topology {
    Single,
    Split,
    Raid,
    Manual,
}

/// Sistemas de arquivos aceitos pelo contrato v2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileSystem {
    Btrfs,
    Zfs,
    Ext4,
    Xfs,
}

/// Estratégia de criptografia aplicável a um ponto de montagem.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Encryption {
    None,
    Luks2,
}

/// Capacidade de filesystem e criptografia associada a um volume lógico.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct MountPlan {
    pub filesystem: FileSystem,
    pub encryption: Encryption,
}

/// Repositórios que formam a árvore Git do sistema instalado.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RepositoryPlan {
    pub core_url: String,
    pub upstream_url: String,
    pub downstream_url: String,
    pub branch: String,
}

/// Opções obrigatórias quando qualquer volume usa ZFS.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ZfsStoragePlan {
    /// Limite referenciado aplicado ao dataset persistente de usuários.
    pub user_refquota: String,
}

/// Opções obrigatórias quando o volume de dados usa BTRFS.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BtrfsStoragePlan {
    /// Limite qgroup aplicado ao subvolume persistente de usuários.
    pub user_qgroup_limit: String,
}

/// Seleção física e lógica de armazenamento do instalador.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "StoragePlanWire")]
pub struct StoragePlan {
    pub topology: Topology,
    pub system_disks: Vec<String>,
    pub data_disks: Vec<String>,
    pub root: Option<MountPlan>,
    pub data: Option<MountPlan>,
    pub raid_level: Option<String>,
    pub manual_partitions: Vec<String>,
    pub zfs: Option<ZfsStoragePlan>,
    pub btrfs: Option<BtrfsStoragePlan>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct StoragePlanWire {
    topology: Topology,
    system_disks: Vec<String>,
    data_disks: Vec<String>,
    root: Option<MountPlan>,
    data: Option<MountPlan>,
    raid_level: Option<String>,
    manual_partitions: Vec<String>,
    zfs: Option<ZfsStoragePlan>,
    btrfs: Option<BtrfsStoragePlan>,
}

impl TryFrom<StoragePlanWire> for StoragePlan {
    type Error = String;

    fn try_from(value: StoragePlanWire) -> Result<Self, Self::Error> {
        let uses_zfs = value
            .root
            .as_ref()
            .is_some_and(|mount| mount.filesystem == FileSystem::Zfs)
            || value
                .data
                .as_ref()
                .is_some_and(|mount| mount.filesystem == FileSystem::Zfs);
        let uses_btrfs_data = value
            .data
            .as_ref()
            .is_some_and(|mount| mount.filesystem == FileSystem::Btrfs);

        match (&value.zfs, uses_zfs) {
            (None, true) => {
                return Err("storage.zfs is required when a filesystem uses ZFS".to_string());
            }
            (Some(_), false) => {
                return Err("storage.zfs is only valid when root or data uses ZFS".to_string());
            }
            (Some(zfs), true) if !valid_zfs_refquota(&zfs.user_refquota) => {
                return Err(
                    "storage.zfs.userRefquota must use a positive ZFS size such as 100G"
                        .to_string(),
                );
            }
            _ => {}
        }

        match (&value.btrfs, uses_btrfs_data) {
            (None, true) => {
                return Err(
                    "storage.btrfs is required when the data filesystem uses BTRFS".to_string(),
                );
            }
            (Some(_), false) => {
                return Err(
                    "storage.btrfs is only valid when the data filesystem uses BTRFS".to_string(),
                );
            }
            (Some(btrfs), true) if !valid_storage_quota(&btrfs.user_qgroup_limit) => {
                return Err(
                    "storage.btrfs.userQgroupLimit must use a positive size such as 100G"
                        .to_string(),
                );
            }
            _ => {}
        }

        Ok(Self {
            topology: value.topology,
            system_disks: value.system_disks,
            data_disks: value.data_disks,
            root: value.root,
            data: value.data,
            raid_level: value.raid_level,
            manual_partitions: value.manual_partitions,
            zfs: value.zfs,
            btrfs: value.btrfs,
        })
    }
}

fn valid_zfs_refquota(value: &str) -> bool {
    valid_storage_quota(value)
}

fn valid_storage_quota(value: &str) -> bool {
    let digit_count = value.bytes().take_while(u8::is_ascii_digit).count();
    let (number, suffix) = value.split_at(digit_count);

    !number.is_empty()
        && !number.starts_with('0')
        && number.bytes().all(|byte| byte.is_ascii_digit())
        && matches!(
            suffix,
            "K" | "M"
                | "G"
                | "T"
                | "P"
                | "KB"
                | "MB"
                | "GB"
                | "TB"
                | "PB"
                | "KiB"
                | "MiB"
                | "GiB"
                | "TiB"
                | "PiB"
        )
}

/// Plano de instalação v2, livre de senhas e outros segredos.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct InstallPlanV2 {
    #[serde(deserialize_with = "deserialize_version_two")]
    pub version: u8,
    pub is_think_server: bool,
    pub repository: RepositoryPlan,
    pub storage: StoragePlan,
    pub features: BTreeMap<String, BTreeMap<String, bool>>,
}

fn deserialize_version_two<'de, D>(deserializer: D) -> Result<u8, D::Error>
where
    D: Deserializer<'de>,
{
    let version = u8::deserialize(deserializer)?;
    if version == 2 {
        Ok(version)
    } else {
        Err(de::Error::custom(format!(
            "install plan version must be 2, received {version}"
        )))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_plan_json() -> serde_json::Value {
        serde_json::json!({
            "version": 2,
            "isThinkServer": true,
            "repository": {
                "coreUrl": "https://github.com/RAGton/kryonix.git",
                "upstreamUrl": "https://github.com/RAGton/Kryonixos.git",
                "downstreamUrl": "https://github.com/example/kryonixos.git",
                "branch": "main"
            },
            "storage": {
                "topology": "single",
                "systemDisks": ["/dev/nvme0n1"],
                "dataDisks": [],
                "root": {
                    "filesystem": "zfs",
                    "encryption": "none"
                },
                "data": null,
                "raidLevel": null,
                "manualPartitions": [],
                "zfs": {
                    "userRefquota": "100G"
                }
            },
            "features": {
                "server": {
                    "containers": true
                },
                "desktop": {
                    "plasma": false
                }
            }
        })
    }

    fn valid_split_btrfs_plan_json() -> serde_json::Value {
        let mut value = valid_plan_json();
        value["storage"]["topology"] = serde_json::json!("split");
        value["storage"]["dataDisks"] = serde_json::json!(["/dev/nvme1n1"]);
        value["storage"]["root"] = serde_json::json!({
            "filesystem": "ext4",
            "encryption": "none"
        });
        value["storage"]["data"] = serde_json::json!({
            "filesystem": "btrfs",
            "encryption": "none"
        });
        value["storage"].as_object_mut().unwrap().remove("zfs");
        value["storage"]["btrfs"] = serde_json::json!({
            "userQgroupLimit": "100G"
        });
        value
    }

    #[test]
    fn deserializes_complete_v2_plan() {
        let plan: InstallPlanV2 = serde_json::from_value(valid_plan_json()).unwrap();
        assert_eq!(plan.version, 2);
        assert_eq!(plan.storage.topology, Topology::Single);
        assert_eq!(
            plan.storage.root.as_ref().map(|root| root.filesystem),
            Some(FileSystem::Zfs)
        );
        assert_eq!(plan.repository.branch, "main");
        assert!(plan.features["server"]["containers"]);
    }

    #[test]
    fn serializes_storage_fields_as_camel_case() {
        let plan: InstallPlanV2 = serde_json::from_value(valid_plan_json()).unwrap();
        let serialized = serde_json::to_value(plan).unwrap();

        assert_eq!(serialized["storage"]["systemDisks"][0], "/dev/nvme0n1");
        assert_eq!(serialized["storage"]["zfs"]["userRefquota"], "100G");
        assert!(serialized["storage"].get("system_disks").is_none());
    }

    #[test]
    fn rejects_any_version_other_than_two() {
        let mut value = valid_plan_json();
        value["version"] = serde_json::json!(1);
        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("version must be 2"));
    }

    #[test]
    fn rejects_unknown_top_level_field() {
        let mut value = valid_plan_json();
        value["unexpected"] = serde_json::json!(true);
        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("unknown field"));
    }

    #[test]
    fn rejects_unknown_nested_field() {
        let mut value = valid_plan_json();
        value["storage"]["root"]["password"] = serde_json::json!("forbidden");
        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("unknown field"));
    }

    #[test]
    fn requires_downstream_url() {
        let mut value = valid_plan_json();
        value["repository"]
            .as_object_mut()
            .unwrap()
            .remove("downstreamUrl");
        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("downstreamUrl"));
    }

    #[test]
    fn requires_zfs_options_for_zfs_storage() {
        let mut value = valid_plan_json();
        value["storage"].as_object_mut().unwrap().remove("zfs");

        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("storage.zfs is required"));
    }

    #[test]
    fn rejects_invalid_zfs_refquota() {
        let mut value = valid_plan_json();
        value["storage"]["zfs"]["userRefquota"] = serde_json::json!("unlimited");

        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("userRefquota"));
    }

    #[test]
    fn requires_btrfs_qgroup_limit_for_btrfs_data_volume() {
        let mut value = valid_split_btrfs_plan_json();
        value["storage"].as_object_mut().unwrap().remove("btrfs");

        let error = serde_json::from_value::<InstallPlanV2>(value).unwrap_err();
        assert!(error.to_string().contains("storage.btrfs is required"));
    }

    #[test]
    fn deserializes_btrfs_qgroup_limit() {
        let plan: InstallPlanV2 = serde_json::from_value(valid_split_btrfs_plan_json()).unwrap();

        assert_eq!(
            plan.storage
                .btrfs
                .as_ref()
                .map(|btrfs| btrfs.user_qgroup_limit.as_str()),
            Some("100G")
        );
    }
}
