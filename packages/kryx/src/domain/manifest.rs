use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum SystemStatus {
    Healthy,
    Degraded,
    Updating,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SystemManifest {
    pub uuid: String,
    pub timestamp: DateTime<Utc>,
    pub flake_revision: String,
    pub features_enabled: Vec<String>,
    pub status: SystemStatus,
}
