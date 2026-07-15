use crate::domain::identity::HostIdentity;
use std::fs;

pub fn check_identity() -> Result<HostIdentity, String> {
    let path = std::env::var("KRYONIX_IDENTITY_PATH")
        .unwrap_or_else(|_| "/etc/kryonix/identity.json".to_string());

    let content = fs::read_to_string(&path)
        .map_err(|_| format!("HostIdentity not found: {} does not exist", path))?;
    let identity: HostIdentity = serde_json::from_str(&content)
        .map_err(|e| format!("Invalid identity schema in {}: {}", path, e))?;
    Ok(identity)
}
