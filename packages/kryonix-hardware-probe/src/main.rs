use serde::{Deserialize, Serialize};
use std::fs;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BootMode {
    Uefi,
    Bios,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct HardwareReport {
    pub generated_at: String,
    pub cpu: CpuInfo,
    pub memory_gb: f32,
    pub disks: Vec<DiskInfo>,
    pub gpu: Vec<GpuInfo>,
    pub boot_mode: BootMode,
    pub network: Vec<NetInfo>,
    pub virtualized: Option<String>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CpuInfo {
    pub model: String,
    pub cores: u32,
    pub threads: u32,
    pub arch: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DiskInfo {
    pub path: String,
    pub model: String,
    pub size_gb: f32,
    pub kind: String,
    pub removable: bool,
    pub partitions: Vec<PartInfo>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PartInfo {
    pub name: String,
    pub size_gb: f32,
    pub fs: Option<String>,
    pub mountpoint: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GpuInfo {
    pub vendor: String,
    pub model: String,
    pub vram_gb: Option<f32>,
    pub driver: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NetInfo {
    pub name: String,
    pub mac: Option<String>,
}

fn main() {
    let report = probe_hardware();
    println!("{}", serde_json::to_string_pretty(&report).unwrap());
}

pub fn probe_hardware() -> HardwareReport {
    let mut warnings = Vec::new();
    HardwareReport {
        generated_at: chrono::Utc::now().to_rfc3339(),
        cpu: probe_cpu(),
        memory_gb: probe_memory(),
        disks: probe_disks(&mut warnings),
        gpu: probe_gpu(&mut warnings),
        boot_mode: probe_boot_mode(),
        network: probe_network(),
        virtualized: probe_virtualization(),
        warnings,
    }
}

pub fn probe_cpu() -> CpuInfo {
    let content = fs::read_to_string("/proc/cpuinfo").unwrap_or_default();

    let model = content
        .lines()
        .find(|l| l.starts_with("model name"))
        .and_then(|l| l.split(':').nth(1))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "Unknown".into());

    let threads = content
        .lines()
        .filter(|l| l.starts_with("processor"))
        .count() as u32;

    let cores = content
        .lines()
        .find(|l| l.starts_with("cpu cores"))
        .and_then(|l| l.split(':').nth(1))
        .and_then(|s| s.trim().parse().ok())
        .unwrap_or(threads);

    CpuInfo {
        model,
        cores,
        threads,
        arch: std::env::consts::ARCH.into(),
    }
}

pub fn probe_memory() -> f32 {
    let content = fs::read_to_string("/proc/meminfo").unwrap_or_default();
    content
        .lines()
        .find(|l| l.starts_with("MemTotal:"))
        .and_then(|l| l.split_whitespace().nth(1))
        .and_then(|s| s.parse::<u64>().ok())
        .map(|kb| kb as f32 / 1_048_576.0)
        .unwrap_or(0.0)
}

pub fn probe_boot_mode() -> BootMode {
    if fs::metadata("/sys/firmware/efi").is_ok() {
        BootMode::Uefi
    } else {
        BootMode::Bios
    }
}

pub fn probe_disks(warnings: &mut Vec<String>) -> Vec<DiskInfo> {
    let output = Command::new("lsblk")
        .args([
            "-J",
            "-b",
            "-o",
            "NAME,SIZE,TYPE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINT",
        ])
        .output();

    let json: serde_json::Value = match output {
        Ok(o) if o.status.success() => serde_json::from_slice(&o.stdout).unwrap_or_default(),
        _ => {
            warnings.push("lsblk failed or not found".into());
            return vec![];
        }
    };

    json["blockdevices"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter(|d| d["type"].as_str() == Some("disk"))
        .map(|d| {
            let tran = d["tran"].as_str().unwrap_or("");
            let kind = match tran {
                "nvme" => "nvme",
                "usb" => "usb",
                "mmc" => "mmc",
                _ => "sata",
            };
            let size_bytes = d["size"]
                .as_u64()
                .or_else(|| d["size"].as_str().and_then(|s| s.parse().ok()))
                .unwrap_or(0);

            DiskInfo {
                path: format!("/dev/{}", d["name"].as_str().unwrap_or("?")),
                model: d["model"].as_str().unwrap_or("?").trim().into(),
                size_gb: size_bytes as f32 / 1e9,
                kind: kind.into(),
                removable: d["rm"].as_bool().unwrap_or(false),
                partitions: parse_partitions(d),
            }
        })
        .collect()
}

fn parse_partitions(disk: &serde_json::Value) -> Vec<PartInfo> {
    disk["children"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter(|p| p["type"].as_str() == Some("part"))
        .map(|p| {
            let size_bytes = p["size"]
                .as_u64()
                .or_else(|| p["size"].as_str().and_then(|s| s.parse().ok()))
                .unwrap_or(0);
            PartInfo {
                name: format!("/dev/{}", p["name"].as_str().unwrap_or("?")),
                size_gb: size_bytes as f32 / 1e9,
                fs: p["fstype"]
                    .as_str()
                    .filter(|s| !s.is_empty())
                    .map(Into::into),
                mountpoint: p["mountpoint"]
                    .as_str()
                    .filter(|s| !s.is_empty())
                    .map(Into::into),
            }
        })
        .collect()
}

pub fn probe_gpu(warnings: &mut Vec<String>) -> Vec<GpuInfo> {
    let output = Command::new("lspci").args(["-vmm"]).output();

    let stdout = match output {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).into_owned(),
        _ => {
            warnings.push("lspci failed or not found — GPU detection skipped".into());
            return vec![];
        }
    };

    let mut gpus: Vec<GpuInfo> = stdout
        .split("\n\n")
        .filter(|block| {
            block.lines().any(|l| {
                l.starts_with("Class:")
                    && (l.contains("VGA") || l.contains("3D") || l.contains("Display"))
            })
        })
        .map(|block| {
            let field = |prefix: &str| -> String {
                block
                    .lines()
                    .find(|l| l.starts_with(prefix))
                    .and_then(|l| l.split(':').nth(1))
                    .unwrap_or("")
                    .trim()
                    .to_string()
            };

            let vendor_name = field("Vendor:");
            let vendor = if vendor_name.contains("NVIDIA") {
                "nvidia"
            } else if vendor_name.contains("AMD") || vendor_name.contains("Advanced Micro") {
                "amd"
            } else if vendor_name.contains("Intel") {
                "intel"
            } else {
                "unknown"
            };

            GpuInfo {
                vendor: vendor.into(),
                model: field("Device:"),
                vram_gb: None,
                driver: None,
            }
        })
        .collect();

    // Enrich NVIDIA entries with VRAM via nvidia-smi
    if let Ok(out) = Command::new("nvidia-smi")
        .args(["--query-gpu=memory.total", "--format=csv,noheader,nounits"])
        .output()
        && let Ok(mb) = String::from_utf8_lossy(&out.stdout).trim().parse::<f32>()
    {
        for gpu in &mut gpus {
            if gpu.vendor == "nvidia" {
                gpu.vram_gb = Some(mb / 1024.0);
                gpu.driver = Some("nvidia".into());
                break;
            }
        }
    }

    gpus
}

pub fn probe_network() -> Vec<NetInfo> {
    let Ok(entries) = fs::read_dir("/sys/class/net") else {
        return vec![];
    };
    entries
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| n != "lo")
        .map(|name| {
            let mac = fs::read_to_string(format!("/sys/class/net/{}/address", name))
                .ok()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty() && s != "00:00:00:00:00:00");
            NetInfo { name, mac }
        })
        .collect()
}

pub fn probe_virtualization() -> Option<String> {
    let out = Command::new("systemd-detect-virt").output().ok()?;
    let virt = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if virt.is_empty() || virt == "none" {
        None
    } else {
        Some(virt)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_probe_cpu_has_model() {
        let cpu = probe_cpu();
        assert!(!cpu.model.is_empty());
        assert!(cpu.threads > 0);
        assert!(cpu.cores > 0);
        assert!(!cpu.arch.is_empty());
    }

    #[test]
    fn test_probe_memory_positive() {
        let mem = probe_memory();
        assert!(mem > 0.0, "memory_gb deve ser positivo, got {}", mem);
    }

    #[test]
    fn test_probe_boot_mode_valid() {
        let mode = probe_boot_mode();
        let s = serde_json::to_string(&mode).unwrap();
        assert!(s == "\"uefi\"" || s == "\"bios\"");
    }

    #[test]
    fn test_hardware_report_serializes() {
        let report = probe_hardware();
        let json = serde_json::to_string(&report);
        assert!(json.is_ok());
        assert!(!json.unwrap().is_empty());
    }

    #[test]
    fn test_probe_network_no_loopback() {
        let nets = probe_network();
        assert!(nets.iter().all(|n| n.name != "lo"));
    }
}
