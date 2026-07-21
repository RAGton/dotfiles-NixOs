use colored::Colorize;
use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Debug, Serialize, Deserialize)]
pub struct FeaturesDoc {
    pub features: std::collections::BTreeMap<String, std::collections::BTreeMap<String, bool>>,
}

pub fn list_features(json: bool) -> Result<(), String> {
    let path = "/etc/kryonix/features.json";

    // For testing/mocking
    let final_path = if std::env::var("KRYONIX_FEATURES_PATH").is_ok() {
        std::env::var("KRYONIX_FEATURES_PATH").unwrap()
    } else {
        path.to_string()
    };

    let content = fs::read_to_string(&final_path)
        .map_err(|e| format!("Não foi possível ler as features ({}): {}", final_path, e))?;

    let doc: FeaturesDoc =
        serde_json::from_str(&content).map_err(|e| format!("JSON de features inválido: {}", e))?;

    if json {
        println!("{}", serde_json::to_string(&doc).unwrap_or_else(|_| "{}".to_string()));
        return Ok(());
    }

    println!("{}", "=== Status das Features Ativas ===".bold().cyan());

    for (category, feats) in doc.features {
        println!("\n[{}]", category.bold().blue());
        for (feat, enabled) in feats {
            let status = if enabled {
                "ENABLED".green().bold()
            } else {
                "DISABLED".red()
            };
            println!("  - {}: {}", feat, status);
        }
    }

    Ok(())
}
