// MIGRATION STATUS:
// - check_identity: NATIVO (Rust)
// - check_systemd: NATIVO (Rust)
// - check_brain_health: NATIVO (Rust com fallback parcial via ureq)
// - check_neo4j: LEGADO (Fallback via glacier-neo4j-doctor.sh)
// - check_hardware: LEGADO (Fallback)
// - check_network: LEGADO (Fallback)

use crate::services::fallback;
use colored::Colorize;
use std::fs;
use std::process::Command;

pub struct DoctorContext {
    pub pass: u32,
    pub warn: u32,
    pub fail: u32,
}

impl DoctorContext {
    pub fn new() -> Self {
        Self {
            pass: 0,
            warn: 0,
            fail: 0,
        }
    }
    pub fn ok(&mut self, msg: &str) {
        println!("{} {}", "[PASS]".green(), msg);
        self.pass += 1;
    }
    pub fn warn(&mut self, msg: &str) {
        println!("{} {}", "[WARN]".yellow(), msg);
        self.warn += 1;
    }
    pub fn fail(&mut self, msg: &str) {
        println!("{} {}", "[FAIL]".red(), msg);
        self.fail += 1;
    }
    pub fn info(&self, msg: &str) {
        println!("{} {}", "[INFO]".cyan(), msg);
    }
}

pub fn run_doctor() -> Result<(), String> {
    let mut ctx = DoctorContext::new();
    println!("================================================================");
    println!("GLACIER DOCTOR (Kryx Native)");
    println!("================================================================");

    check_identity(&mut ctx);
    check_systemd(&mut ctx);
    check_brain_health(&mut ctx);

    // Call remaining legacy parts as part of the pipeline
    println!("\n================================================================");
    println!("LEGACY CHECKS (Não migrados ainda)");
    println!("================================================================");
    let _ = fallback::run_legacy_fallback("glacier-doctor.sh", &[]);

    println!("\n================================================================");
    println!("RESUMO NATIVO");
    println!("================================================================");
    println!("PASS: {}", ctx.pass);
    println!("WARN: {}", ctx.warn);
    println!("FAIL: {}", ctx.fail);

    if ctx.fail > 0 {
        return Err("O sistema tem falhas críticas (Nativo) para corrigir.".to_string());
    }
    Ok(())
}

fn check_identity(ctx: &mut DoctorContext) {
    if let Ok(host) = fs::read_to_string("/etc/hostname") {
        let host = host.trim();
        if host == "RVE-GLACIER" || host == "glacier" {
            ctx.ok(&format!("hostname está correto: {}", host));
        } else {
            ctx.warn(&format!("hostname não é o esperado: {}", host));
        }
    } else {
        ctx.fail("Não foi possível ler /etc/hostname");
    }
}

fn check_systemd(ctx: &mut DoctorContext) {
    let output = Command::new("systemctl")
        .arg("--failed")
        .arg("--no-pager")
        .output();

    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        if stdout.contains("0 loaded units listed") {
            ctx.ok("Sem units failed no systemd");
        } else {
            ctx.fail("Existem units falhadas no systemd");
        }
    } else {
        ctx.fail("Não foi possível executar o systemctl");
    }
}

fn check_brain_health(ctx: &mut DoctorContext) {
    let brain_url = "http://127.0.0.1:8000/health";
    match ureq::get(brain_url)
        .timeout(std::time::Duration::from_secs(5))
        .call()
    {
        Ok(response) if response.status() == 200 => {
            ctx.ok("Brain API /health respondeu via HTTP ureq");
        }
        _ => {
            ctx.warn("Brain API /health não respondeu. Acionando fallback legacy...");
            if let Err(e) = fallback::run_legacy_fallback("check-brain.sh", &[]) {
                ctx.fail(&format!("Fallback check-brain.sh falhou ou ausente: {}", e));
            }
        }
    }
}
