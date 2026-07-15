use std::path::Path;
use std::process::Command;

/// Verifica se o ambiente de execução atual é um Live ISO / Ambiente de Instalação.
pub fn check_is_live_iso() -> bool {
    // 1. Verificação explícita do Kryonix (Flag injetada pela ISO)
    if Path::new("/run/kryonix-live").exists() {
        return true;
    }

    // 2. Verificação Heurística via filesystem da raiz
    // Live ISOs do NixOS montam a raiz primária como `overlay` sob um `squashfs`.
    if let Ok(output) = Command::new("findmnt")
        .args(&["-n", "-o", "FSTYPE", "/"])
        .output()
    {
        let fstype = String::from_utf8_lossy(&output.stdout)
            .trim()
            .to_lowercase();
        if fstype == "overlay" || fstype == "iso9660" || fstype == "squashfs" {
            return true;
        }
    }

    false
}
