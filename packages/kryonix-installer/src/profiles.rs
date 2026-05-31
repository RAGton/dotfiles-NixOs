use std::fs;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, Copy)]
pub enum ProfileType {
    Gamer,
    DevRust,
}

impl ProfileType {
    pub fn as_import_line(&self) -> &str {
        match self {
            ProfileType::Gamer => "    inputs.kryonix.nixosModules.profile-gamer",
            ProfileType::DevRust => "    inputs.kryonix.nixosModules.profile-dev-rust",
        }
    }
}

pub fn apply_profile(host: &str, profile: ProfileType) -> Result<(), String> {
    let repo_path = "/etc/kryonixos";
    let host_nix = format!("{}/hosts/{}/default.nix", repo_path, host);
    let host_path = Path::new(&host_nix);

    if !host_path.exists() {
        return Err(format!("Host configuration not found: {}", host_nix));
    }

    // 1. Create backup
    let content = fs::read_to_string(host_path)
        .map_err(|e| format!("Failed to read {}: {}", host_nix, e))?;
    let backup_content = content.clone();

    // 2. Patch the content
    let new_content = patch_imports(&content, profile)?;

    // 3. Write new content
    fs::write(host_path, &new_content)
        .map_err(|e| format!("Failed to write {}: {}", host_nix, e))?;

    // 4. Validate with nix flake check
    println!("Validating flake change for host {}...", host);
    let check_status = Command::new("nix")
        .arg("flake")
        .arg("check")
        .arg(repo_path)
        .status();

    match check_status {
        Ok(status) if status.success() => {
            println!("Validation successful.");
            Ok(())
        }
        _ => {
            // 5. Revert on failure
            println!("Validation failed! Reverting...");
            fs::write(host_path, backup_content)
                .map_err(|e| format!("Failed to revert {}: {}", host_nix, e))?;
            
            // Capture stderr for better error reporting if possible
            let output = Command::new("nix")
                .arg("flake")
                .arg("check")
                .arg(repo_path)
                .output()
                .map_err(|e| e.to_string())?;
            
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!("Nix validation failed. File reverted.\nError: {}", stderr))
        }
    }
}

fn patch_imports(content: &str, profile: ProfileType) -> Result<String, String> {
    let import_line = profile.as_import_line();
    
    // Simple block detection for 'imports = ['
    let mut lines: Vec<String> = content.lines().map(|s| s.to_string()).collect();
    let mut imports_start = None;
    let mut imports_end = None;

    for (i, line) in lines.iter().enumerate() {
        if line.contains("imports = [") {
            imports_start = Some(i);
        }
        if imports_start.is_some() && line.contains("];") {
            imports_end = Some(i);
            break;
        }
    }

    let (start, end) = match (imports_start, imports_end) {
        (Some(s), Some(e)) => (s, e),
        _ => return Err("Could not find 'imports = [ ... ];' block in default.nix".to_string()),
    };

    // Check if already exists
    let exists = lines[start..=end].iter().any(|l| l.contains(import_line.trim()));
    if exists {
        return Ok(content.to_string());
    }

    // Insert before the closing '];'
    lines.insert(end, import_line.to_string());

    Ok(lines.join("\n"))
}
