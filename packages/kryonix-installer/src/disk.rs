#![allow(clippy::needless_borrows_for_generic_args)]

use regex::Regex;
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DiskInfo {
    pub name: String,
    pub size: String,
    pub r#type: String, // 'type' is a reserved keyword in Rust
    pub mountpoint: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
struct LsblkOutput {
    blockdevices: Vec<DiskInfo>,
}

pub fn list_disks() -> Result<Vec<DiskInfo>, String> {
    let output = Command::new("lsblk")
        .args(&["-J", "-b", "-o", "NAME,SIZE,TYPE,MOUNTPOINT"])
        .output()
        .map_err(|e| format!("Failed to execute lsblk: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let parsed: LsblkOutput = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse lsblk JSON: {}", e))?;

    // Filter only disks (ignore partitions, loop devices, cdrom, etc) and exclude the live media if mounted at /iso
    let disks = parsed
        .blockdevices
        .into_iter()
        .filter(|d| d.r#type == "disk" && !d.name.starts_with("loop"))
        .collect();

    Ok(disks)
}

pub fn is_valid_disk_path(path: &str) -> bool {
    // Allows /dev/sda, /dev/nvme0n1, /dev/vda
    let re = Regex::new(r"^/dev/(sd[a-z]|nvme\d+n\d+|vd[a-z])$").unwrap();
    re.is_match(path)
}

pub fn partition_disk(disk_path: &str) -> Result<(), String> {
    if !is_valid_disk_path(disk_path) {
        return Err(format!("Invalid disk path: {}", disk_path));
    }

    // sgdisk -Z (zap)
    // sgdisk -n 1:0:+512M -t 1:ef00 -c 1:boot
    // sgdisk -n 2:0:0 -t 2:8300 -c 2:root
    let cmds = vec![
        vec!["sgdisk", "-Z", disk_path],
        vec![
            "sgdisk",
            "-n",
            "1:0:+512M",
            "-t",
            "1:ef00",
            "-c",
            "1:boot",
            disk_path,
        ],
        vec![
            "sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:root", disk_path,
        ],
        vec!["partprobe", disk_path],
    ];

    for cmd in cmds {
        let output = Command::new(cmd[0])
            .args(&cmd[1..])
            .output()
            .map_err(|e| format!("Failed to execute {}: {}", cmd[0], e))?;

        if !output.status.success() {
            return Err(format!(
                "Command {:?} failed: {}",
                cmd,
                String::from_utf8_lossy(&output.stderr)
            ));
        }
    }

    // Wait a bit for device nodes
    std::thread::sleep(std::time::Duration::from_secs(2));

    let boot_part = format!("{}1", disk_path); // WARNING: nvme is nvme0n1p1 (requires fix)
    let root_part = format!("{}2", disk_path);

    let boot_part = if disk_path.contains("nvme") {
        format!("{}p1", disk_path)
    } else {
        boot_part
    };
    let root_part = if disk_path.contains("nvme") {
        format!("{}p2", disk_path)
    } else {
        root_part
    };

    // Format
    let mkfs_boot = Command::new("mkfs.fat")
        .args(&["-F", "32", &boot_part])
        .output()
        .map_err(|e| format!("Failed mkfs.fat: {}", e))?;
    if !mkfs_boot.status.success() {
        return Err(String::from_utf8_lossy(&mkfs_boot.stderr).to_string());
    }

    let mkfs_root = Command::new("mkfs.btrfs")
        .args(&["-f", &root_part])
        .output()
        .map_err(|e| format!("Failed mkfs.btrfs: {}", e))?;
    if !mkfs_root.status.success() {
        return Err(String::from_utf8_lossy(&mkfs_root.stderr).to_string());
    }

    // Mount and create subvolumes
    let _ = Command::new("umount").args(&["-R", "/mnt"]).output();
    Command::new("mount")
        .args(&[&root_part, "/mnt"])
        .output()
        .map_err(|e| format!("Mount root fail: {}", e))?;

    for subvol in &["@", "@home", "@nix", "@log"] {
        Command::new("btrfs")
            .args(&["subvolume", "create", &format!("/mnt/{}", subvol)])
            .output()
            .map_err(|e| e.to_string())?;
    }
    Command::new("umount")
        .args(&["-R", "/mnt"])
        .output()
        .map_err(|e| e.to_string())?;

    // Mount them properly
    Command::new("mount")
        .args(&["-o", "subvol=@,compress=zstd,noatime", &root_part, "/mnt"])
        .output()
        .map_err(|e| e.to_string())?;
    std::fs::create_dir_all("/mnt/home").unwrap_or(());
    std::fs::create_dir_all("/mnt/nix").unwrap_or(());
    std::fs::create_dir_all("/mnt/var/log").unwrap_or(());
    std::fs::create_dir_all("/mnt/boot").unwrap_or(());

    Command::new("mount")
        .args(&[
            "-o",
            "subvol=@home,compress=zstd,noatime",
            &root_part,
            "/mnt/home",
        ])
        .output()
        .map_err(|e| e.to_string())?;
    Command::new("mount")
        .args(&[
            "-o",
            "subvol=@nix,compress=zstd,noatime",
            &root_part,
            "/mnt/nix",
        ])
        .output()
        .map_err(|e| e.to_string())?;
    Command::new("mount")
        .args(&[
            "-o",
            "subvol=@log,compress=zstd,noatime",
            &root_part,
            "/mnt/var/log",
        ])
        .output()
        .map_err(|e| e.to_string())?;
    Command::new("mount")
        .args(&[&boot_part, "/mnt/boot"])
        .output()
        .map_err(|e| e.to_string())?;

    Ok(())
}
