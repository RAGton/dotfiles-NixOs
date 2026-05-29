# Prompt: Hardware Probe — Detecção Completa

> Melhorar o kryonix-hardware-probe para detectar com precisão
> CPU, RAM, discos, GPU (incluindo NVIDIA), rede e modo de boot.
> Output: JSON padronizado para o frontend e o planner.

---

## FASE 1 — Estado atual

```bash
cd /etc/kryonix/packages/kryonix-installer
# ou packages/kryonix-hardware-probe se for separado

grep -rn 'probe\|hardware\|lsblk\|cpu\|gpu' src/ --include='*.rs' | head -20
cargo run -- probe 2>/dev/null | head -30
```

---

## FASE 2 — Campos obrigatórios

```rust
#[derive(Debug, Serialize, Deserialize)]
pub struct HardwareReport {
    pub generated_at: String,     // ISO 8601
    pub cpu:          CpuInfo,
    pub memory_gb:    f32,
    pub disks:        Vec<DiskInfo>,
    pub gpu:          Vec<GpuInfo>,
    pub boot_mode:    BootMode,   // Uefi | Bios
    pub network:      Vec<NetInfo>,
    pub virtualized:  Option<String>, // "kvm" | "vmware" | "virtualbox" | null
    pub warnings:     Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CpuInfo {
    pub model:     String,
    pub cores:     u32,
    pub threads:   u32,
    pub arch:      String,   // "x86_64" | "aarch64"
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DiskInfo {
    pub path:      String,   // "/dev/nvme0n1"
    pub model:     String,
    pub size_gb:   f32,
    pub kind:      String,   // "nvme" | "sata" | "usb" | "mmc"
    pub removable: bool,
    pub partitions: Vec<PartInfo>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GpuInfo {
    pub vendor:    String,   // "nvidia" | "amd" | "intel" | "unknown"
    pub model:     String,
    pub vram_gb:   Option<f32>,
    pub driver:    Option<String>,
}
```

---

## FASE 3 — Implementações

### CPU (via `/proc/cpuinfo`)

```rust
fn probe_cpu() -> CpuInfo {
    let cpuinfo = std::fs::read_to_string("/proc/cpuinfo")
        .unwrap_or_default();

    let model = cpuinfo.lines()
        .find(|l| l.starts_with("model name"))
        .and_then(|l| l.split(':').nth(1))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "Unknown".into());

    let threads = cpuinfo.lines()
        .filter(|l| l.starts_with("processor"))
        .count() as u32;

    let cores = cpuinfo.lines()
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
```

### RAM (via `/proc/meminfo`)

```rust
fn probe_memory() -> f32 {
    let meminfo = std::fs::read_to_string("/proc/meminfo")
        .unwrap_or_default();

    meminfo.lines()
        .find(|l| l.starts_with("MemTotal:"))
        .and_then(|l| l.split_whitespace().nth(1))
        .and_then(|s| s.parse::<u64>().ok())
        .map(|kb| kb as f32 / 1_048_576.0)  // KB → GB
        .unwrap_or(0.0)
}
```

### Discos (via `lsblk --json`)

```rust
fn probe_disks() -> Vec<DiskInfo> {
    let out = std::process::Command::new("lsblk")
        .args(["-J", "-b", "-o",
               "NAME,SIZE,TYPE,MODEL,TRAN,RM,MOUNTPOINT"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();

    let json: serde_json::Value = serde_json::from_str(&out)
        .unwrap_or_default();

    json["blockdevices"].as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter(|d| d["type"].as_str() == Some("disk"))
        .filter(|d| d["tran"].as_str() != Some("usb"))  // skip USB drives
        .map(|d| DiskInfo {
            path:     format!("/dev/{}", d["name"].as_str().unwrap_or("?")),
            model:    d["model"].as_str().unwrap_or("?").trim().into(),
            size_gb:  d["size"].as_u64().unwrap_or(0) as f32 / 1e9,
            kind: match d["tran"].as_str() {
                Some("nvme") => "nvme",
                Some("usb")  => "usb",
                Some("mmc")  => "mmc",
                _            => "sata",
            }.into(),
            removable: d["rm"].as_bool().unwrap_or(false),
            partitions: parse_partitions(d),
        })
        .collect()
}
```

### GPU (via `lspci`)

```rust
fn probe_gpu() -> Vec<GpuInfo> {
    let out = std::process::Command::new("lspci")
        .args(["-vmm"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();

    let mut gpus = vec![];

    for block in out.split("\n\n") {
        let is_gpu = block.lines().any(|l| {
            l.starts_with("Class:") && (
                l.contains("VGA") || l.contains("3D") || l.contains("Display")
            )
        });

        if !is_gpu { continue; }

        let vendor_line = block.lines()
            .find(|l| l.starts_with("Vendor:"))
            .unwrap_or("Vendor: Unknown");

        let device_line = block.lines()
            .find(|l| l.starts_with("Device:"))
            .unwrap_or("Device: Unknown");

        let vendor_name = vendor_line.split(':').nth(1)
            .unwrap_or("").trim();

        let vendor = if vendor_name.contains("NVIDIA") { "nvidia" }
                     else if vendor_name.contains("AMD") { "amd" }
                     else if vendor_name.contains("Intel") { "intel" }
                     else { "unknown" };

        gpus.push(GpuInfo {
            vendor: vendor.into(),
            model: device_line.split(':').nth(1)
                .unwrap_or("?").trim().into(),
            vram_gb: None,  // detectar via nvidia-smi se disponível
            driver: None,
        });
    }

    // Tentar VRAM via nvidia-smi
    if let Ok(out) = std::process::Command::new("nvidia-smi")
        .args(["--query-gpu=memory.total", "--format=csv,noheader,nounits"])
        .output()
    {
        let vram_str = String::from_utf8_lossy(&out.stdout);
        if let Ok(mb) = vram_str.trim().parse::<f32>() {
            for gpu in &mut gpus {
                if gpu.vendor == "nvidia" {
                    gpu.vram_gb = Some(mb / 1024.0);
                    gpu.driver = Some("nvidia".into());
                    break;
                }
            }
        }
    }

    gpus
}
```

### Virtualização

```rust
fn probe_virtualization() -> Option<String> {
    // Verificar via systemd-detect-virt
    let out = std::process::Command::new("systemd-detect-virt")
        .output()
        .ok()?;

    let virt = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if virt == "none" || virt.is_empty() { None } else { Some(virt) }
}
```

---

## FASE 4 — Testes

```rust
#[test]
fn test_probe_boot_mode_valid() {
    let mode = probe_boot_mode();
    assert!(matches!(mode, BootMode::Uefi | BootMode::Bios));
}

#[test]
fn test_probe_cpu_has_model() {
    let cpu = probe_cpu();
    assert!(!cpu.model.is_empty());
    assert!(cpu.threads > 0);
}

#[test]
fn test_probe_memory_positive() {
    let mem = probe_memory();
    assert!(mem > 0.0);
}

#[test]
fn test_hardware_report_serializes() {
    let report = probe_hardware();
    let json = serde_json::to_string(&report);
    assert!(json.is_ok());
}
```

```bash
cargo fmt --check && cargo clippy -- -D warnings && cargo test && cargo build
```

---

## Commit

```bash
git commit -am "feat(probe): hardware probe completo

- CPU: model, cores, threads via /proc/cpuinfo
- RAM: GB via /proc/meminfo
- Discos: lsblk JSON (nvme/sata/mmc, skip USB)
- GPU: lspci + nvidia-smi para VRAM
- Boot mode: /sys/firmware/efi
- Virtualização: systemd-detect-virt
- Testes: serialização, boot mode, cpu, memória"
```
