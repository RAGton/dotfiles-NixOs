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

    // Copiamos a árvore do engine para /mnt/etc/kryonix.
    // Usar um diretório alvo explícito evita a falha de `cp -aT` quando o pai
    // ainda não foi criado pelo fluxo de montagem da instalação.
    let engine_target = "/mnt/etc/kryonix";
    tokio::fs::create_dir_all(engine_target)
        .await
        .map_err(|e| format!("Falha ao criar {engine_target}: {}", e))?;

    let engine_source_with_contents = format!("{}/.", engine_source);
    let cp_status = Command::new("cp")
        .args(["-a", &engine_source_with_contents, engine_target])
        .status()
        .await
        .map_err(|e| format!("Falha ao executar cp para o engine: {}", e))?;

    if !cp_status.success() {
        return Err(format!(
            "Falha ao copiar engine source para {engine_target}"
        ));
    }

    let chmod_status = Command::new("chmod")
        .args(["-R", "u+rwX", "/mnt/etc/kryonix"])
        .status()
        .await
        .map_err(|e| format!("Falha ao executar chmod: {}", e))?;

    if !chmod_status.success() {
        return Err("Falha ao aplicar permissões no engine copiado".into());
    }

    let hostname = plan
        .network
        .get("hostname")
        .and_then(|v| v.as_str())
        .unwrap_or("kryonix");
    let user_name = plan
        .admin
        .get("user")
        .and_then(|v| v.as_str())
        .unwrap_or("kryonix");

    tokio::fs::create_dir_all(format!("/mnt/etc/kryonixos/hosts/{}", hostname))
        .await
        .map_err(|e| format!("Falha ao criar diretórios hosts: {}", e))?;

    tokio::fs::create_dir_all(format!(
        "/mnt/etc/kryonixos/users/{}/{}",
        user_name, hostname
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
        hostname, hostname, hostname
    );

    tokio::fs::write("/mnt/etc/kryonixos/flake.nix", flake_content)
        .await
        .map_err(|e| format!("Falha ao criar flake.nix: {}", e))?;

    let timezone = plan
        .locale
        .get("timezone")
        .and_then(|v| v.as_str())
        .unwrap_or("America/Cuiaba");
    let locale = plan
        .locale
        .get("locale")
        .and_then(|v| v.as_str())
        .unwrap_or("pt_BR.UTF-8");
    let keyboard = plan
        .locale
        .get("keymap")
        .and_then(|v| v.as_str())
        .unwrap_or("br-abnt2");

    let host_config_content = format!(
        r#"{{ config, pkgs, inputs, ... }}:
{{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
    ./features.nix
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
        user = user_name,
        hostname = hostname,
        timezone = timezone,
        locale = locale,
        keyboard = keyboard,
    );

    tokio::fs::write(
        format!("/mnt/etc/kryonixos/hosts/{}/default.nix", hostname),
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
        user = user_name
    );

    tokio::fs::write(
        format!(
            "/mnt/etc/kryonixos/users/{}/{}/default.nix",
            user_name, hostname
        ),
        user_config_content,
    )
    .await
    .map_err(|e| format!("Falha ao criar user default.nix: {}", e))?;

    let features_nix = build_features_nix(plan);
    tokio::fs::write(
        format!("/mnt/etc/kryonixos/hosts/{}/features.nix", hostname),
        features_nix,
    )
    .await
    .map_err(|e| format!("Falha ao criar features.nix: {}", e))?;

    let home_features_nix = build_home_features_nix(plan);
    tokio::fs::write(
        format!("/mnt/etc/kryonixos/hosts/{}/home-features.nix", hostname),
        home_features_nix,
    )
    .await
    .map_err(|e| format!("Falha ao criar home-features.nix: {}", e))?;

    let plan_json = serde_json::to_string_pretty(plan)
        .map_err(|e| format!("Falha ao serializar install plan: {}", e))?;
    tokio::fs::write("/mnt/etc/kryonixos/.kryonix-install-plan.json", plan_json)
        .await
        .map_err(|e| format!("Falha ao salvar .kryonix-install-plan.json: {}", e))?;

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
            hostname
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
        format!("/mnt/etc/kryonixos/hosts/{}/disks.nix", hostname),
        disko_config,
    )
    .await
    .map_err(|e| format!("Falha ao salvar disks.nix: {}", e))?;

    Ok(())
}

fn build_features_nix(plan: &InstallPlan) -> String {
    let mut lines: Vec<String> = vec![
        "{ config, lib, pkgs, ... }:".into(),
        "".into(),
        "{
  # Features do sistema geradas pelo Kryonix Installer"
            .into(),
        "  kryonix.features = {".into(),
    ];

    let domains = vec![
        "system",
        "ai",
        "storage",
        "security",
        "remote",
        "observability",
        "mcp",
    ];
    for domain in &domains {
        if let Some(val) = plan.features.get(*domain) {
            if let Some(obj) = val.as_object() {
                for (key, v) in obj {
                    if v.as_bool() == Some(true) {
                        let parts: Vec<&str> = key.split('.').collect();
                        if parts.len() == 2 {
                            lines.push(format!("    {}.{}.enable = true;", parts[0], parts[1]));
                        }
                    }
                }
            }
        }
    }

    lines.push("  };".into());
    lines.push("}".into());
    lines.join("\n")
}

fn build_home_features_nix(plan: &InstallPlan) -> String {
    let mut lines: Vec<String> = vec![
        "{ config, lib, pkgs, ... }:".into(),
        "".into(),
        "{
  # Features de usuário (Home Manager) geradas pelo Kryonix Installer"
            .into(),
        "  kryonix.home.features = {".into(),
    ];

    let domains = vec![
        "user", "shell", "terminal", "editor", "browser", "dev", "desktop", "obsidian",
    ];
    for domain in &domains {
        if let Some(val) = plan.features.get(*domain) {
            if let Some(obj) = val.as_object() {
                for (key, v) in obj {
                    if v.as_bool() == Some(true) {
                        let parts: Vec<&str> = key.split('.').collect();
                        if parts.len() == 2 {
                            lines.push(format!("    {}.{}.enable = true;", parts[0], parts[1]));
                        }
                    }
                }
            }
        }
    }

    lines.push("  };".into());
    lines.push("}".into());
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{InstallPlan, PlanDisk};

    fn make_test_plan() -> InstallPlan {
        InstallPlan {
            version: 1,
            source: None,
            profile: None,
            features: serde_json::json!({}),
            storage: None,
            security: None,
            remote_access: None,
            disk: PlanDisk {
                mode: "install".into(),
                profile: "single".into(),
                selected_disks: vec![],
                sys_disk: Some("/dev/null".into()),
                data_disk: None,
                raid_level: None,
                manual_partitions: None,
            },
            network: serde_json::json!({ "hostname": "test-host" }),
            locale: serde_json::json!({
                "timezone": "America/Sao_Paulo",
                "locale": "pt_BR.UTF-8",
                "keymap": "br-abnt2"
            }),
            admin: serde_json::json!({
                "user": "test-user",
                "admin": true
            }),
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

// Helpers for generating feature configs
fn generate_features_nix(plan: &InstallPlan) -> String {
    let mut lines: Vec<String> = vec![
        "{ config, lib, pkgs, ... }:".into(),
        "".into(),
        "{
  # Features de sistema geradas pelo Kryonix Installer"
            .into(),
        "  kryonix.features = {".into(),
    ];

    // Extract system features from plan.features["system"]
    if let Some(system) = plan.features.get("system") {
        if let Some(obj) = system.as_object() {
            for (key, val) in obj {
                if val.as_bool() == Some(true) {
                    let parts: Vec<&str> = key.split('.').collect();
                    if parts.len() == 2 {
                        lines.push(format!("    {}.{}.enable = true;", parts[0], parts[1]));
                    }
                }
            }
        }
    }

    // Extract other nixos feature domains (ai, storage, security, remote, observability, mcp)
    for domain in [
        "ai",
        "storage",
        "security",
        "remote",
        "observability",
        "mcp",
    ] {
        if let Some(domain_val) = plan.features.get(domain) {
            if let Some(obj) = domain_val.as_object() {
                for (key, val) in obj {
                    if val.as_bool() == Some(true) {
                        let parts: Vec<&str> = key.split('.').collect();
                        if parts.len() == 2 {
                            lines.push(format!("    {}.{}.enable = true;", parts[0], parts[1]));
                        }
                    }
                }
            }
        }
    }

    lines.push("  };".into());
    lines.push("}".into());
    lines.join(
        "
",
    )
}

fn generate_home_features_nix(plan: &InstallPlan) -> String {
    let mut lines: Vec<String> = vec![
        "{ config, lib, pkgs, ... }:".into(),
        "".into(),
        "{
  # Features de usuário (Home Manager) geradas pelo Kryonix Installer"
            .into(),
        "  kryonix.home.features = {".into(),
    ];

    // Extract user-level features from plan.features["user"] and other user domains
    for domain in [
        "user", "shell", "terminal", "editor", "browser", "dev", "desktop", "obsidian",
    ] {
        if let Some(domain_val) = plan.features.get(domain) {
            if let Some(obj) = domain_val.as_object() {
                for (key, val) in obj {
                    if val.as_bool() == Some(true) {
                        let parts: Vec<&str> = key.split('.').collect();
                        if parts.len() == 2 {
                            lines.push(format!("    {}.{}.enable = true;", parts[0], parts[1]));
                        }
                    }
                }
            }
        }
    }

    lines.push("  };".into());
    lines.push("}".into());
    lines.join(
        "
",
    )
}
