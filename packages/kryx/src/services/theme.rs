use colored::Colorize;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub fn run_apply_theme() -> Result<(), String> {
    println!(
        "{} Aplicando Semantic Theme nativamente...",
        "[INFO]".cyan()
    );

    let mut replacements = HashMap::new();
    replacements.insert("bg-[#1C1C1E]", "bg-apple-panel");
    replacements.insert("bg-[#2C2C2E]", "bg-apple-panelHover");
    replacements.insert("bg-[#3A3A3C]", "bg-apple-inputDisabled");
    replacements.insert("border-[#38383A]", "border-apple-border");
    replacements.insert("border-[#E5E5EA]", "border-apple-border");
    replacements.insert("text-[#F5F5F7]", "text-apple-textPrimary");
    replacements.insert("text-[#86868B]", "text-apple-textSecondary");
    replacements.insert("text-[#A1A1A6]", "text-apple-textSecondary");
    replacements.insert("text-[#1D1D1F]", "text-apple-textPrimary");
    replacements.insert("text-[#515154]", "text-apple-textSecondary");
    replacements.insert("bg-[#0071E3]", "bg-apple-blue");
    replacements.insert("bg-[#0A84FF]", "bg-apple-blue");
    replacements.insert("bg-[#0A84FF]/10", "bg-apple-blueTransparent");
    replacements.insert("bg-[#0A84FF]/15", "bg-apple-blueTransparent");
    replacements.insert("bg-[#5E5CE6]/15", "bg-apple-blueTransparent");
    replacements.insert("text-[#0A84FF]", "text-apple-blue");
    replacements.insert("text-[#0A84FF]/80", "text-apple-blue");
    replacements.insert("border-[#0A84FF]/30", "border-apple-blue");
    replacements.insert("border-[#5E5CE6]/60", "border-apple-blue");
    replacements.insert("bg-[#32D74B]/10", "bg-apple-success/10");
    replacements.insert("text-[#32D74B]", "text-apple-success");
    replacements.insert("border-[#32D74B]/30", "border-apple-success");
    replacements.insert("bg-[#FF9F0A]/10", "bg-apple-warning/10");
    replacements.insert("text-[#FF9F0A]", "text-apple-warning");
    replacements.insert("text-[#FF9F0A]/80", "text-apple-warning");
    replacements.insert("border-[#FF9F0A]/30", "border-apple-warning");
    replacements.insert("ring-[#FF9F0A]/50", "ring-apple-warning/50");
    replacements.insert("bg-[#FF453A]/10", "bg-apple-danger/10");
    replacements.insert("text-[#FF453A]", "text-apple-danger");
    replacements.insert("text-[#FF453A]/70", "text-apple-danger");
    replacements.insert("border-[#FF453A]/30", "border-apple-danger");

    let directories = [
        "repos/kryxd/ui/src/pages",
        "repos/kryxd/ui/src/components",
        "repos/kryxd/ui/src",
    ];

    let mut updated_files = 0;

    for dir in directories {
        let dir_path = Path::new(dir);
        if !dir_path.exists() {
            continue;
        }

        if let Ok(entries) = fs::read_dir(dir_path) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("jsx") {
                    if let Ok(content) = fs::read_to_string(&path) {
                        let mut new_content = content.clone();
                        let mut changed = false;

                        for (old, new) in &replacements {
                            if new_content.contains(old) {
                                new_content = new_content.replace(old, new);
                                changed = true;
                            }
                        }

                        if changed {
                            if fs::write(&path, new_content).is_ok() {
                                println!("{} Atualizado {:?}", "[OK]".green(), path);
                                updated_files += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    println!(
        "{} {} arquivos atualizados com o Semantic Theme.",
        "[INFO]".cyan(),
        updated_files
    );
    Ok(())
}
