use tokio::process::Command;
use serde_json::Value;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct InstanceConfig {
    pub name: String,
    pub is_vm: bool,
    pub image: String,
    pub cpu: u16,
    pub ram_mb: u32,
    pub disk_gb: u32,
}

pub async fn incus_list() -> Result<Value, String> {
    let output = Command::new("incus")
        .arg("list")
        .arg("--format=json")
        .output()
        .await
        .map_err(|e| format!("Failed to run incus list: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "incus list failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let json: Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse incus list JSON: {}", e))?;

    Ok(json)
}

pub async fn incus_launch(config: &InstanceConfig) -> Result<(), String> {
    let mut cmd = Command::new("incus");
    cmd.arg("launch").arg(&config.image).arg(&config.name);

    if config.is_vm {
        cmd.arg("--vm");
    } else {
        // Para containers (não-VM), impor perfil estrito AppArmor
        cmd.arg("-c");
        cmd.arg("raw.lxc=lxc.apparmor.profile=kryonix-incus-container");
    }

    cmd.arg("-c").arg(format!("limits.cpu={}", config.cpu));
    cmd.arg("-c").arg(format!("limits.memory={}MB", config.ram_mb));
    cmd.arg("-d").arg(format!("root,size={}GB", config.disk_gb));

    let output = cmd
        .output()
        .await
        .map_err(|e| format!("Failed to spawn incus launch: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "incus launch failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(())
}

pub async fn incus_stop(name: &str) -> Result<(), String> {
    let output = Command::new("incus")
        .arg("stop")
        .arg(name)
        .output()
        .await
        .map_err(|e| format!("Failed to spawn incus stop: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "incus stop failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(())
}
