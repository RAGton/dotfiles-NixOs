# Task: Installer UX Refinement & ISO Polishing

This document mandates the foundational engineering and architectural standards for the refined installer UX and live environment.

## Goal
Transform the core installer backend into a polished, production-ready product with intelligent flow detection, robust partitioning options, and a premium live system appearance.

## Architectural Mandates

### 1. Intelligent Flow Detection (Restore vs. New)
- **Automatic Detection:** The backend MUST check for existing Kryonix configurations (e.g., `/etc/kryonixos/flake.lock` or `/mnt/etc/kryonix-installed`) on available storage.
- **Restore Mode:** If detected, the UI MUST prioritize a "Restore Mode" that skips user/profile creation and utilizes existing declarative state.

### 2. Dual-Mode Partitioning
- **'Automatic' Mode:** Backend infers the best BTRFS layout based on `hardware-probe` and upstream `disks.nix` templates.
- **'Manual' Mode:** Expose `/disk/manual-setup` endpoint. Integrate a web-terminal (Xterm.js) or provide a guided "Main Mountpoint (/)" selection while automating subvolume creation.

### 3. Live ISO Polishing
- **Plymouth:** Must be active and themed via `nixosModules.branding` with `quiet splash` in kernel parameters.
- **Bootloader:** Ensure `grub-install` targets are correctly detected (UEFI vs. Legacy).
- **Kiosk Mode:** The installer UI MUST be the primary Wayland surface, managed by systemd and starting immediately on auto-login.

### 4. Automated VM Validation
- **Scripted Tests:** `tests/test_iso_boot.sh` must exist to validate ISO bootability, network connectivity, and installer availability via QEMU/KVM without physical hardware.

## Engineering Standards
- **Nix Reliability:** ALL configuration changes to `hosts/iso` MUST pass `nix flake check`.
- **Rust Safety:** Backend errors MUST be surfaced to the UI with actionable feedback and log snippets.
- **UX Consistency:** Maintain the immersive, fullscreen, non-scrolling design established in the installer UI.
