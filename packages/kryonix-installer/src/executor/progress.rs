use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
pub struct ProgressEvent {
    pub step: String, // "partition" | "nixos-install" | "done" | "error"
    pub message: String,
    pub percent: u8,
}
