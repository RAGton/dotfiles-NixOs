use tokio::process::Command;
use serde_json::Value;

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

pub async fn incus_launch(name: &str, image: &str, is_vm: bool) -> Result<(), String> {
    let mut cmd = Command::new("incus");
    cmd.arg("launch").arg(image).arg(name);

    if is_vm {
        cmd.arg("--vm");
    } else {
        // Para containers (não-VM), impor perfil estrito AppArmor
        cmd.arg("-c");
        cmd.arg("raw.lxc=lxc.apparmor.profile=kryonix-incus-container");
    }

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
