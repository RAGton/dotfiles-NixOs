#![allow(clippy::needless_borrows_for_generic_args)]

use regex::Regex;
use serde::{Deserialize, Deserializer, Serialize};
use std::os::unix::fs::FileTypeExt;
use std::process::Command;

const MIN_INSTALL_BYTES: u64 = 10 * 1024 * 1024 * 1024;

#[derive(Serialize, Debug, Clone)]
pub struct DiskInfo {
    pub name: String,
    pub path: String,
    pub size: String,
    pub size_bytes: u64,
    pub r#type: String, // 'type' is a reserved keyword in Rust
    pub mountpoint: Option<String>,
    pub model: Option<String>,
    /// Mídia removível (lsblk RM). Bloqueada como alvo na Fase 0.
    pub removable: bool,
    /// Dispositivo somente-leitura (lsblk RO).
    pub readonly: bool,
    /// Elegível como alvo de instalação (fonte de verdade = backend).
    pub eligible: bool,
    /// Motivos de bloqueio legíveis quando `eligible == false`.
    #[serde(rename = "eligibilityIssues")]
    pub eligibility_issues: Vec<String>,
}

#[derive(Deserialize, Debug, Clone)]
struct LsblkDiskInfo {
    name: String,
    #[serde(deserialize_with = "deserialize_size_bytes")]
    size: u64,
    #[serde(rename = "type")]
    r#type: String,
    mountpoint: Option<String>,
    model: Option<String>,
    #[serde(default, deserialize_with = "deserialize_lsblk_bool")]
    rm: bool,
    #[serde(default, deserialize_with = "deserialize_lsblk_bool")]
    ro: bool,
}

#[derive(Deserialize, Debug)]
struct LsblkOutput {
    blockdevices: Vec<LsblkDiskInfo>,
}

#[derive(Deserialize, Debug)]
struct LsblkMountOutput {
    blockdevices: Vec<LsblkMountNode>,
}

#[derive(Deserialize, Debug)]
struct LsblkMountNode {
    mountpoint: Option<String>,
    #[serde(default)]
    children: Vec<LsblkMountNode>,
}

fn deserialize_size_bytes<'de, D>(deserializer: D) -> Result<u64, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::Number(n) => n
            .as_u64()
            .ok_or_else(|| serde::de::Error::custom("SIZE must be a positive integer")),
        serde_json::Value::String(s) => s
            .trim()
            .parse::<u64>()
            .map_err(|e| serde::de::Error::custom(format!("invalid SIZE value: {e}"))),
        other => Err(serde::de::Error::custom(format!(
            "invalid SIZE type: {other}"
        ))),
    }
}

/// lsblk -J emite RM/RO ora como bool, ora como "0"/"1" (varia por versão).
/// Aceita bool, número e string; null/ausente → false.
fn deserialize_lsblk_bool<'de, D>(deserializer: D) -> Result<bool, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(match value {
        serde_json::Value::Bool(b) => b,
        serde_json::Value::Number(n) => n.as_i64().map(|x| x != 0).unwrap_or(false),
        serde_json::Value::String(s) => matches!(s.trim(), "1" | "true" | "yes" | "Y"),
        _ => false,
    })
}

fn format_size(bytes: u64) -> String {
    const GIB: f64 = 1024.0 * 1024.0 * 1024.0;
    format!("{:.1} GiB", bytes as f64 / GIB)
}

/// Elegibilidade de um disco como ALVO de instalação (Fase 0).
///
/// Bloqueios OBRIGATÓRIOS: read-only, type != disk, loop/cdrom/zram/ram/rom,
/// tamanho desconhecido ou menor que o mínimo. Mídia REMOVÍVEL é bloqueada
/// nesta fase — instalação em USB/removível NÃO é suportada na Fase 0.
/// root/system disk e disco montado são marcados em `list_disks` (best-effort);
/// o gate destrutivo final continua sendo o `/dry-run`.
fn compute_eligibility(
    name: &str,
    dtype: &str,
    size_bytes: u64,
    removable: bool,
    readonly: bool,
) -> Vec<String> {
    let mut reasons = Vec::new();
    if readonly {
        reasons.push("Disco somente-leitura (read-only).".to_string());
    }
    if dtype != "disk" {
        reasons.push(format!("Tipo '{dtype}' não é elegível (esperado: disk)."));
    }
    if name.starts_with("loop")
        || name.starts_with("sr")
        || name.starts_with("zram")
        || name.starts_with("ram")
        || dtype == "rom"
    {
        reasons.push("Loop, CD-ROM, zram e ramdisks não são elegíveis.".to_string());
    }
    if removable {
        reasons.push("Disco removível/USB — não suportado nesta fase (Fase 0).".to_string());
    }
    if size_bytes == 0 {
        reasons.push("Não foi possível determinar o tamanho do disco.".to_string());
    } else if size_bytes < MIN_INSTALL_BYTES {
        reasons.push(format!(
            "Disco muito pequeno (mínimo {} GiB).",
            MIN_INSTALL_BYTES / (1024 * 1024 * 1024)
        ));
    }
    reasons
}

fn to_disk_info(info: LsblkDiskInfo) -> DiskInfo {
    let reasons = compute_eligibility(&info.name, &info.r#type, info.size, info.rm, info.ro);
    DiskInfo {
        path: format!("/dev/{}", info.name),
        size: format_size(info.size),
        size_bytes: info.size,
        removable: info.rm,
        readonly: info.ro,
        eligible: reasons.is_empty(),
        eligibility_issues: reasons,
        name: info.name,
        r#type: info.r#type,
        mountpoint: info.mountpoint,
        model: info.model,
    }
}

pub fn list_disks() -> Result<Vec<DiskInfo>, String> {
    let output = Command::new("lsblk")
        .args([
            "-J",
            "-b",
            "-d",
            "-o",
            "NAME,SIZE,TYPE,MOUNTPOINT,MODEL,RM,RO",
        ])
        .output()
        .map_err(|e| format!("Failed to execute lsblk: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let parsed: LsblkOutput = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse lsblk JSON: {}", e))?;

    // Filter only disks (ignore partitions, loop devices, cdrom, etc) and exclude the live media if mounted at /iso
    let mut disks: Vec<DiskInfo> = parsed
        .blockdevices
        .into_iter()
        .filter(|d| d.r#type == "disk" && !d.name.starts_with("loop"))
        .map(to_disk_info)
        .collect();

    // Marca root/system disk e discos montados como inelegíveis (best-effort).
    // Erros nos utilitários não derrubam o endpoint; o /dry-run é o gate final.
    for d in &mut disks {
        if matches!(is_system_disk(&d.path), Ok(true)) {
            d.eligible = false;
            d.eligibility_issues
                .push("É o disco onde o sistema/Live ISO está rodando.".to_string());
        }
        if matches!(disk_mount_conflicts(&d.path), Ok(ref m) if !m.is_empty()) {
            d.eligible = false;
            d.eligibility_issues
                .push("Disco com partições montadas.".to_string());
        }
    }

    Ok(disks)
}

pub fn is_valid_disk_path(path: &str) -> bool {
    // Allows /dev/sda, /dev/nvme0n1, /dev/vda
    let re = Regex::new(r"^/dev/(sd[a-z]|nvme\d+n\d+|vd[a-z])$").unwrap();
    re.is_match(path)
}

pub fn inspect_disk(path: &str) -> Result<DiskInfo, String> {
    if !is_valid_disk_path(path) {
        return Err(format!("Invalid disk path format: {path}"));
    }

    let metadata =
        std::fs::metadata(path).map_err(|e| format!("Device {path} does not exist: {e}"))?;
    if !metadata.file_type().is_block_device() {
        return Err(format!("Device {path} is not a block device"));
    }

    let output = Command::new("lsblk")
        .args([
            "-J",
            "-b",
            "-d",
            "-o",
            "NAME,SIZE,TYPE,MOUNTPOINT,MODEL,RM,RO",
            path,
        ])
        .output()
        .map_err(|e| format!("Failed to execute lsblk for {path}: {e}"))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let parsed: LsblkOutput = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse lsblk JSON for {path}: {e}"))?;

    let info = parsed
        .blockdevices
        .into_iter()
        .next()
        .ok_or_else(|| format!("lsblk did not return disk info for {path}"))?;

    if info.r#type != "disk" {
        return Err(format!(
            "Device {path} is type {}, expected disk",
            info.r#type
        ));
    }

    Ok(to_disk_info(info))
}

pub fn disk_has_min_install_size(path: &str) -> Result<(bool, u64), String> {
    let disk = inspect_disk(path)?;
    Ok((disk.size_bytes >= MIN_INSTALL_BYTES, disk.size_bytes))
}

pub fn is_system_disk(path: &str) -> Result<bool, String> {
    if !is_valid_disk_path(path) {
        return Err(format!("Invalid disk path format: {path}"));
    }

    let output = Command::new("findmnt")
        .args(["--target", "/", "--output", "SOURCE", "--noheadings"])
        .output()
        .map_err(|e| format!("findmnt failed: {e}"))?;

    if !output.status.success() {
        return Err(format!(
            "findmnt failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let target_base = path.trim_start_matches("/dev/");
    for raw_source in String::from_utf8_lossy(&output.stdout).lines() {
        let source = raw_source.trim();
        if !source.starts_with("/dev/") {
            continue;
        }

        let source_base = source.trim_start_matches("/dev/");
        if source_base == target_base || source_base.starts_with(&format!("{target_base}p")) {
            return Ok(true);
        }
        if (target_base.starts_with("sd") || target_base.starts_with("vd"))
            && source_base.starts_with(target_base)
        {
            return Ok(true);
        }

        let parent = Command::new("lsblk")
            .args(["-no", "PKNAME", source])
            .output()
            .map_err(|e| format!("lsblk PKNAME failed for {source}: {e}"))?;
        if parent.status.success()
            && String::from_utf8_lossy(&parent.stdout)
                .lines()
                .any(|line| line.trim() == target_base)
        {
            return Ok(true);
        }
    }

    Ok(false)
}

fn collect_mounts(node: &LsblkMountNode, mounts: &mut Vec<String>) {
    if let Some(mountpoint) = node.mountpoint.as_deref() {
        let mountpoint = mountpoint.trim();
        if !mountpoint.is_empty() {
            mounts.push(mountpoint.to_string());
        }
    }

    for child in &node.children {
        collect_mounts(child, mounts);
    }
}

pub fn disk_mount_conflicts(path: &str) -> Result<Vec<String>, String> {
    inspect_disk(path)?;

    let output = Command::new("lsblk")
        .args(["-J", "-o", "NAME,MOUNTPOINT", path])
        .output()
        .map_err(|e| format!("lsblk mount scan failed for {path}: {e}"))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let parsed: LsblkMountOutput = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse mount scan for {path}: {e}"))?;

    let mut mounts = Vec::new();
    for node in &parsed.blockdevices {
        collect_mounts(node, &mut mounts);
    }

    Ok(mounts
        .into_iter()
        .filter(|mountpoint| mountpoint != "/iso" && !mountpoint.starts_with("/iso/"))
        .collect())
}

/// Retorna o layout de partições de um disco via lsblk.
/// O `device` é sanitizado: apenas alfanuméricos, `-` e `_` são permitidos.
pub fn get_partitions(device: &str) -> Result<serde_json::Value, String> {
    // Sanitização: rejeita qualquer char que não seja alphanum, hífen ou underscore
    let safe: String = device
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
        .collect();

    if safe.is_empty() || safe != device {
        return Err(format!("Device name inválido ou rejeitado: '{}'", device));
    }

    let target = format!("/dev/{}", safe);

    let output = Command::new("lsblk")
        .args([
            "-J",
            "-b",
            "-o",
            "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,PARTFLAGS",
            &target,
        ])
        .output()
        .map_err(|e| format!("lsblk falhou: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    serde_json::from_slice(&output.stdout).map_err(|e| format!("Parse JSON lsblk: {}", e))
}

#[cfg(test)]
mod tests {
    use super::*;

    const BIG: u64 = 30 * 1024 * 1024 * 1024;

    #[test]
    fn eligible_disk_has_no_issues() {
        let r = compute_eligibility("vda", "disk", BIG, false, false);
        assert!(r.is_empty(), "disco normal deveria ser elegível: {r:?}");
    }

    #[test]
    fn removable_is_blocked_in_phase0() {
        let r = compute_eligibility("sdb", "disk", BIG, true, false);
        assert!(r.iter().any(|m| m.contains("removível")));
    }

    #[test]
    fn readonly_is_blocked() {
        let r = compute_eligibility("vda", "disk", BIG, false, true);
        assert!(r.iter().any(|m| m.contains("read-only")));
    }

    #[test]
    fn loop_cdrom_zram_blocked() {
        assert!(!compute_eligibility("loop0", "loop", BIG, false, false).is_empty());
        assert!(!compute_eligibility("sr0", "rom", BIG, true, false).is_empty());
        assert!(!compute_eligibility("zram0", "disk", BIG, false, false).is_empty());
    }

    #[test]
    fn too_small_and_unknown_size_blocked() {
        assert!(!compute_eligibility("vda", "disk", 0, false, false).is_empty());
        assert!(!compute_eligibility("vda", "disk", 1024, false, false).is_empty());
    }

    #[test]
    fn lsblk_bool_accepts_bool_int_string() {
        // exercita o deserializer via JSON real do lsblk (bool e "0"/"1")
        let j = r#"{"blockdevices":[{"name":"vda","size":32212254720,"type":"disk","mountpoint":null,"model":"X","rm":false,"ro":"0"}]}"#;
        let out: LsblkOutput = serde_json::from_str(j).expect("parse lsblk json");
        assert!(!out.blockdevices[0].rm);
        assert!(!out.blockdevices[0].ro);
    }
}
