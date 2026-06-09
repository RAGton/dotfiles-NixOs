use std::sync::Arc;
use tokio::process::Command;
use tokio::sync::broadcast;

use super::progress::ProgressEvent;
use crate::InstallPlan;

pub async fn generate_kryonixos_tree(
    plan: &InstallPlan,
    tx: Arc<broadcast::Sender<ProgressEvent>>,
) -> Result<(), String> {
    let _ = tx.send(ProgressEvent {
        step: "kryonixos".into(),
        message: "Gerando árvore do Kryonixos...".into(),
        percent: 30,
    });

    let engine_source = std::env::var("KRYONIX_ENGINE_SOURCE")
        .unwrap_or_else(|_| "/run/current-system/sw/share/kryonix-engine".to_string());

    if !std::path::Path::new(&engine_source).exists() {
        return Err(format!(
            "KRYONIX_ENGINE_SOURCE not found at {}",
            engine_source
        ));
    }

    let _ = tx.send(ProgressEvent {
        step: "kryonixos".into(),
        message: format!("Copiando engine de {}...", engine_source),
        percent: 31,
    });

    // `cp -aT <src> /mnt/etc/kryonix` falha se /mnt/etc não existir (cp exige
    // que o pai do destino exista). Em ISO recém-particionada, /mnt só tem o
    // root do FS recém-montado. Garantir o pai antes evita aborto silencioso.
    tokio::fs::create_dir_all("/mnt/etc")
        .await
        .map_err(|e| format!("Falha ao criar /mnt/etc: {}", e))?;

    let cp_status = Command::new("cp")
        .args(["-aT", &engine_source, "/mnt/etc/kryonix"])
        .status()
        .await
        .map_err(|e| format!("Falha ao executar cp para o engine: {}", e))?;

    if !cp_status.success() {
        return Err("Falha ao copiar engine source para /mnt/etc/kryonix".into());
    }

    let chmod_status = Command::new("chmod")
        .args(["-R", "u+rwX", "/mnt/etc/kryonix"])
        .status()
        .await
        .map_err(|e| format!("Falha ao executar chmod: {}", e))?;

    if !chmod_status.success() {
        return Err("Falha ao aplicar permissões no engine copiado".into());
    }

    tokio::fs::create_dir_all(format!("/mnt/etc/kryonixos/hosts/{}", plan.hostname))
        .await
        .map_err(|e| format!("Falha ao criar diretórios hosts: {}", e))?;

    tokio::fs::create_dir_all(format!(
        "/mnt/etc/kryonixos/users/{}/{}",
        plan.user.name, plan.hostname
    ))
    .await
    .map_err(|e| format!("Falha ao criar diretórios users: {}", e))?;

    let flake_content = format!(
        r#"{{
  description = "Configuração do host {} downstream Kryonix";

  inputs = {{
    kryonix.url = "path:../kryonix";
  }};

  outputs = {{ self, kryonix, ... }}@inputs: {{
    nixosConfigurations."{}" = kryonix.inputs.nixpkgs.lib.nixosSystem {{
      system = "x86_64-linux";
      specialArgs = {{ inherit inputs; }};
      modules = [
        ./hosts/{}/default.nix
        kryonix.nixosModules.default
      ];
    }};
  }};
}}
"#,
        plan.hostname, plan.hostname, plan.hostname
    );

    tokio::fs::write("/mnt/etc/kryonixos/flake.nix", flake_content)
        .await
        .map_err(|e| format!("Falha ao criar flake.nix: {}", e))?;

    let host_config_content = format!(
        r#"{{ config, pkgs, inputs, ... }}:
{{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
    ../../users/{user}/{hostname}/default.nix
  ];

  networking.hostName = "{hostname}";
  time.timeZone = "{timezone}";
  i18n.defaultLocale = "{locale}";
  console.keyMap = "{keyboard}";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  services.qemuGuest.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}}
"#,
        user = plan.user.name,
        hostname = plan.hostname,
        timezone = plan.timezone,
        locale = plan.locale,
        keyboard = plan.keyboard,
    );

    tokio::fs::write(
        format!("/mnt/etc/kryonixos/hosts/{}/default.nix", plan.hostname),
        host_config_content,
    )
    .await
    .map_err(|e| format!("Falha ao criar host default.nix: {}", e))?;

    let user_config_content = format!(
        r#"{{ config, pkgs, ... }}:
{{
  users.users.{user} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  }};
}}
"#,
        user = plan.user.name
    );

    tokio::fs::write(
        format!(
            "/mnt/etc/kryonixos/users/{}/{}/default.nix",
            plan.user.name, plan.hostname
        ),
        user_config_content,
    )
    .await
    .map_err(|e| format!("Falha ao criar user default.nix: {}", e))?;

    let _ = tx.send(ProgressEvent {
        step: "kryonixos".into(),
        message: "Gerando hardware-configuration.nix...".into(),
        percent: 32,
    });

    let hw_output = Command::new("nixos-generate-config")
        .args(["--root", "/mnt", "--show-hardware-config"])
        .output()
        .await
        .map_err(|e| format!("Falha ao executar nixos-generate-config: {}", e))?;

    if !hw_output.status.success() {
        return Err(format!(
            "nixos-generate-config falhou: {}",
            String::from_utf8_lossy(&hw_output.stderr)
        ));
    }

    tokio::fs::write(
        format!(
            "/mnt/etc/kryonixos/hosts/{}/hardware-configuration.nix",
            plan.hostname
        ),
        hw_output.stdout,
    )
    .await
    .map_err(|e| format!("Falha ao salvar hardware-configuration.nix: {}", e))?;

    // Copia config do disko
    let disko_config = tokio::fs::read_to_string("/tmp/kryonix-disko-config.nix")
        .await
        .unwrap_or_else(|_| "{}".to_string());

    tokio::fs::write(
        format!("/mnt/etc/kryonixos/hosts/{}/disks.nix", plan.hostname),
        disko_config,
    )
    .await
    .map_err(|e| format!("Falha ao salvar disks.nix: {}", e))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{InstallPlan, PlanDisk, PlanUser};

    fn make_test_plan() -> InstallPlan {
        InstallPlan {
            version: 1,
            hostname: "test-host".into(),
            timezone: "America/Sao_Paulo".into(),
            locale: "pt_BR.UTF-8".into(),
            keyboard: "br-abnt2".into(),
            disk: PlanDisk {
                mode: "install".into(),
                target: "/dev/null".into(),
                layout: "btrfs-simple".into(),
                boot_mode: "uefi".into(),
                profile: "single".into(),
                selected_disks: vec![],
                raid_level: None,
                manual_partitions: None,
            },
            user: PlanUser {
                name: "test-user".into(),
                admin: true,
            },
            features: serde_json::json!({}),
        }
    }

    #[tokio::test]
    async fn missing_engine_source_fails_before_nixos_install() {
        unsafe {
            std::env::set_var("KRYONIX_ENGINE_SOURCE", "/path/that/does/not/exist/surely");
        }
        let (tx, _) = broadcast::channel(10);
        let plan = make_test_plan();
        let res = generate_kryonixos_tree(&plan, Arc::new(tx)).await;
        assert!(res.is_err());
        assert!(res.unwrap_err().contains("KRYONIX_ENGINE_SOURCE not found"));
    }
}
